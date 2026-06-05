import AppKit
import Foundation

@MainActor
private final class TrayPopoverStorage {
    static var popover: NSPopover? = nil
    static var statusButton: NSStatusBarButton? = nil
    static var delegate: TrayPopoverDelegateHandler? = nil
}

private struct TraySendablePointers: @unchecked Sendable {
    let window: UnsafeMutableRawPointer
    let button: UnsafeMutableRawPointer
}

class TrayPopoverDelegateHandler: NSObject, NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        tray_popover_event(.Opened)
    }

    func popoverDidClose(_ notification: Notification) {
        tray_popover_event(.Closed)
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if let controller = popover.contentViewController {
            controller.view.isHidden = false
            controller.view.alphaValue = 1.0
        }
        return true
    }
}

public func initTrayPopoverManager(
    nsWindowPtr: UnsafeMutableRawPointer,
    nsStatusBarButtonPtr: UnsafeMutableRawPointer
) {
    let containers = TraySendablePointers(window: nsWindowPtr, button: nsStatusBarButtonPtr)

    DispatchQueue.main.async {
        let window = Unmanaged<NSWindow>.fromOpaque(containers.window).takeUnretainedValue()
        let button = Unmanaged<NSStatusBarButton>.fromOpaque(containers.button)
            .takeUnretainedValue()

        guard let stolenView = window.contentView else { return }

        stolenView.wantsLayer = true
        stolenView.layer?.backgroundColor = NSColor.clear.cgColor

        let placeholderView = NSView(frame: .zero)
        window.contentView = placeholderView
        window.orderOut(nil)

        let targetSize = window.frame.size

        let hostingContainerView = NSView(frame: NSRect(origin: .zero, size: targetSize))
        hostingContainerView.wantsLayer = true
        hostingContainerView.autoresizingMask = [.width, .height]

        let visualEffectView = NSVisualEffectView(frame: hostingContainerView.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true

        stolenView.frame = visualEffectView.bounds
        stolenView.autoresizingMask = [.width, .height]

        visualEffectView.addSubview(stolenView)
        hostingContainerView.addSubview(visualEffectView)

        let viewController = NSViewController()
        viewController.view = hostingContainerView

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = viewController
        popover.contentSize = targetSize

        let delegate = TrayPopoverDelegateHandler()
        popover.delegate = delegate

        TrayPopoverStorage.popover = popover
        TrayPopoverStorage.statusButton = button
        TrayPopoverStorage.delegate = delegate
    }
}

public func openTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = TrayPopoverStorage.popover,
            let button = TrayPopoverStorage.statusButton
        else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
}

public func closeTrayPopover() {
    DispatchQueue.main.async {
        guard let popover = TrayPopoverStorage.popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        }
    }
}

public func isTrayPopoverVisible() -> Bool {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { TrayPopoverStorage.popover?.isShown ?? false }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated { TrayPopoverStorage.popover?.isShown ?? false }
        }
    }
}
