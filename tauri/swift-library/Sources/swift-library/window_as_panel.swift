import Cocoa

struct WindowAsPanelSendableWindowPointer: Sendable {
    let address: Int

    var rawPointer: OpaquePointer {
        OpaquePointer(bitPattern: address)!
    }
}

@MainActor
private final class WindowAsPanelInstanceContainer {
    let panel: HoverResponsivePanel
    weak var sourceWindow: NSWindow?
    var trackingArea: NSTrackingArea?
    var originalWebviewSize: NSSize?
    var currentPanelOrigin: NSPoint?
    var moveObserver: NSObjectProtocol?

    init(
        panel: HoverResponsivePanel, sourceWindow: NSWindow? = nil,
        trackingArea: NSTrackingArea? = nil
    ) {
        self.panel = panel
        self.sourceWindow = sourceWindow
        self.trackingArea = trackingArea
    }
}

@MainActor
private final class WindowAsPanelPanelStorage {
    static var activePanels: [String: WindowAsPanelInstanceContainer] = [:]
    static var isCleaningUp = false
}

class HoverResponsivePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var acceptsMouseMovedEvents: Bool {
        get { return true }
        set {}
    }
}

class WindowAsPanelSwiftDragHandleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let pillWidth: CGFloat = 40.0
        let pillHeight: CGFloat = 4.0

        let pillRect = NSRect(
            x: (bounds.width - pillWidth) / 2.0,
            y: (bounds.height - pillHeight) / 2.0,
            width: pillWidth,
            height: pillHeight
        )

        let path = NSBezierPath(roundedRect: pillRect, xRadius: 2.0, yRadius: 2.0)
        NSColor.secondaryLabelColor.withAlphaComponent(0.4).set()
        path.fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }

        window.performDrag(with: event)

        if let panel = window as? HoverResponsivePanel {
            MainActor.assumeIsolated {
                if let activeContainer = WindowAsPanelPanelStorage.activePanels.values.first(
                    where: { $0.panel == panel })
                {
                    activeContainer.currentPanelOrigin = panel.frame.origin
                }
            }
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}

@MainActor
class WindowAsPanelManager {
    static let shared = WindowAsPanelManager()
    static let dragHandleHeight: CGFloat = 16.0

    private func getOrCreatePanel(for id: String) -> HoverResponsivePanel {
        if let container = WindowAsPanelPanelStorage.activePanels[id] {
            return container.panel
        }

        let panel = HoverResponsivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false

        panel.hidesOnDeactivate = false
        panel.level = .statusBar

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .stationary,
        ]

        let newContainer = WindowAsPanelInstanceContainer(panel: panel)
        WindowAsPanelPanelStorage.activePanels[id] = newContainer
        return panel
    }

    func show(id: String, sendablePtr: WindowAsPanelSendableWindowPointer, x: Double, y: Double) {
        let containerExists = WindowAsPanelPanelStorage.activePanels[id] != nil
        var cachedSize: NSSize? = nil
        var trackedOrigin: NSPoint? = nil

        if containerExists {
            cachedSize = WindowAsPanelPanelStorage.activePanels[id]?.originalWebviewSize
            trackedOrigin = WindowAsPanelPanelStorage.activePanels[id]?.currentPanelOrigin
            clearPanelContents(for: id)
        }

        let panel = getOrCreatePanel(for: id)
        let rawUnsafe = UnsafeMutableRawPointer(sendablePtr.rawPointer)

        let sourceWindow = Unmanaged<NSWindow>.fromOpaque(rawUnsafe).takeUnretainedValue()

        guard let stolenView = sourceWindow.contentView else { return }

        if let parent = sourceWindow.parent {
            parent.removeChildWindow(sourceWindow)
        }

        let placeholder = NSView(frame: stolenView.frame)
        sourceWindow.contentView = placeholder
        sourceWindow.orderOut(nil)

        let targetSize: NSSize = cachedSize ?? sourceWindow.frame.size

        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        container.sourceWindow = sourceWindow
        container.originalWebviewSize = targetSize

        let handleHeight = Self.dragHandleHeight
        let frozenWidth = targetSize.width
        let frozenHeight = targetSize.height

        if container.moveObserver == nil {
            container.moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: panel,
                queue: .main
            ) { [weak container] _ in
                Task { @MainActor [weak container] in
                    guard let container = container else { return }

                    container.currentPanelOrigin = container.panel.frame.origin

                    if let sourceWindow = container.sourceWindow {
                        sourceWindow.setFrame(
                            NSRect(
                                x: container.panel.frame.origin.x,
                                y: container.panel.frame.origin.y,
                                width: frozenWidth,
                                height: frozenHeight - handleHeight
                            ),
                            display: true
                        )
                    }
                }
            }
        }

        let customCornerRadius: CGFloat = 20.0
        let containerView = NSView(frame: NSRect(origin: .zero, size: targetSize))
        containerView.autoresizingMask = [.width, .height]

        let visualEffectView = NSVisualEffectView()
        visualEffectView.frame = containerView.bounds
        visualEffectView.autoresizingMask = [.width, .height]

        visualEffectView.wantsLayer = true
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.cornerRadius = customCornerRadius

        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active

        stolenView.frame = visualEffectView.bounds
        stolenView.autoresizingMask = [.width, .height]
        stolenView.wantsLayer = true
        stolenView.layer?.backgroundColor = NSColor.clear.cgColor

        visualEffectView.addSubview(stolenView)

        let dragHandle = WindowAsPanelSwiftDragHandleView()
        dragHandle.frame = NSRect(
            x: 0, y: targetSize.height - Self.dragHandleHeight, width: targetSize.width,
            height: Self.dragHandleHeight)
        dragHandle.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(dragHandle)

        containerView.addSubview(visualEffectView)
        panel.contentView = containerView

        if let dynamicPos = trackedOrigin {
            panel.setFrame(
                NSRect(origin: dynamicPos, size: targetSize), display: true, animate: false)
            container.currentPanelOrigin = dynamicPos
        } else {
            guard let primaryScreen = sourceWindow.screen ?? NSScreen.main else { return }
            let screenFrame = primaryScreen.frame

            let panelX = screenFrame.origin.x + CGFloat(x)
            let panelY =
                screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height

            let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
            panel.setFrame(panelRect, display: true, animate: false)
            container.currentPanelOrigin = panelRect.origin
        }

        sourceWindow.styleMask = [.borderless]
        sourceWindow.isOpaque = false
        sourceWindow.backgroundColor = .clear
        sourceWindow.hasShadow = false
        sourceWindow.setFrame(
            NSRect(
                x: panel.frame.origin.x, y: panel.frame.origin.y, width: targetSize.width,
                height: targetSize.height - Self.dragHandleHeight), display: true)
        panel.addChildWindow(sourceWindow, ordered: .below)

        panel.orderFrontRegardless()
        panel.makeKey()
        panel.invalidateShadow()

        let trackingArea = NSTrackingArea(
            rect: containerView.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: containerView,
            userInfo: nil
        )
        containerView.addTrackingArea(trackingArea)
        container.trackingArea = trackingArea

        WindowAsPanelPanelStorage.isCleaningUp = false
        window_as_panel_event(.Opened(panel_id: RustString(id)))
    }

    func movePanel(id: String, x: Double, y: Double) {
        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        let panel = container.panel

        guard let primaryScreen = panel.screen ?? NSScreen.main else { return }
        let screenFrame = primaryScreen.frame
        let targetSize = panel.frame.size

        let panelX = screenFrame.origin.x + CGFloat(x)
        let panelY =
            screenFrame.origin.y + (screenFrame.size.height - CGFloat(y)) - targetSize.height

        let panelRect = NSRect(origin: NSPoint(x: panelX, y: panelY), size: targetSize)
        panel.setFrame(panelRect, display: true, animate: false)

        container.currentPanelOrigin = panelRect.origin

        if let sourceWindow = container.sourceWindow {
            sourceWindow.setFrame(
                NSRect(
                    x: panelX, y: panelY, width: targetSize.width,
                    height: targetSize.height - Self.dragHandleHeight), display: true)
        }
    }

    private func clearPanelContents(for id: String) {
        guard let container = WindowAsPanelPanelStorage.activePanels[id] else { return }
        let panel = container.panel

        if let observer = container.moveObserver {
            NotificationCenter.default.removeObserver(observer)
            container.moveObserver = nil
        }

        if let sourceWindow = container.sourceWindow {
            if let content = panel.contentView {
                if let visualEffect = content.subviews.first(where: {
                    $0.isKind(of: NSVisualEffectView.self)
                }) {
                    if let stolenView = visualEffect.subviews.first(where: {
                        !$0.isKind(of: WindowAsPanelSwiftDragHandleView.self)
                    }) {
                        stolenView.removeFromSuperview()
                        sourceWindow.contentView = stolenView
                    }
                }
            }
            panel.removeChildWindow(sourceWindow)
            sourceWindow.orderOut(nil)
        }

        if let content = panel.contentView {
            if let tracking = container.trackingArea {
                content.removeTrackingArea(tracking)
                container.trackingArea = nil
            }

            for subview in content.subviews {
                subview.removeFromSuperview()
            }
        }
        panel.contentView = nil
    }

    func closePanel(id: String) {
        guard !WindowAsPanelPanelStorage.isCleaningUp,
            let container = WindowAsPanelPanelStorage.activePanels[id],
            container.panel.isVisible
        else { return }

        WindowAsPanelPanelStorage.isCleaningUp = true

        let panel = container.panel
        panel.orderOut(nil)

        clearPanelContents(for: id)

        WindowAsPanelPanelStorage.activePanels.removeValue(forKey: id)
        WindowAsPanelPanelStorage.isCleaningUp = false

        window_as_panel_event(.Closed(panel_id: RustString(id)))
    }
}

public func showWindowAsPanel(
    id: RustString, windowRawPtr: UnsafeMutableRawPointer?, x: Double, y: Double
) {
    let idStr = id.toString()
    let ptrInt = Int(bitPattern: windowRawPtr)
    let sendableContainer = WindowAsPanelSendableWindowPointer(address: ptrInt)

    DispatchQueue.main.async {
        WindowAsPanelManager.shared.show(id: idStr, sendablePtr: sendableContainer, x: x, y: y)
    }
}

public func moveWindowAsPanel(id: RustString, x: Double, y: Double) {
    let idStr = id.toString()
    DispatchQueue.main.async {
        WindowAsPanelManager.shared.movePanel(id: idStr, x: x, y: y)
    }
}

public func closeWindowAsPanel(id: RustString) {
    let idStr = id.toString()

    DispatchQueue.main.async {
        WindowAsPanelManager.shared.closePanel(id: idStr)
    }
}

public func isWindowAsPanelVisible(id: RustString) -> Bool {
    let idStr = id.toString()

    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false
        }
    } else {
        return DispatchQueue.main.sync {
            return MainActor.assumeIsolated {
                WindowAsPanelPanelStorage.activePanels[idStr]?.panel.isVisible ?? false
            }
        }
    }
}
