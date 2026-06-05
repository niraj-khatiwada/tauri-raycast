import Cocoa
import SwiftUI

struct AIGlowFullScreenView: View {
    @State private var phase: CGFloat = 0.0

    let aiColors = [
        Color.blue,
        Color.purple,
        Color.pink,
        Color.orange,
        Color.cyan,
        Color.blue,
    ]

    let cornerRadius: CGFloat = 28.0

    let baseGlowThickness: CGFloat = 30.0
    let deepBleedBlur: CGFloat = 60.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                colors: aiColors,
                                center: .center,
                                startAngle: .degrees(phase),
                                endAngle: .degrees(phase + 360)
                            ),
                            lineWidth: baseGlowThickness
                        )
                        .blur(radius: deepBleedBlur)
                        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )

                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            AngularGradient(
                                colors: aiColors,
                                center: .center,
                                startAngle: .degrees(phase),
                                endAngle: .degrees(phase + 360)
                            ),
                            lineWidth: 6.0
                        )
                        .blur(radius: 5.0)
                        .blendMode(.plusLighter)
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                phase = 360.0
            }
        }
    }
}

@MainActor
public final class AIGlowManager {
    public static let shared = AIGlowManager()

    private var overlayWindow: NSWindow? = nil

    public func startGlow() {
        if overlayWindow != nil { return }

        guard let targetScreen = NSScreen.main else { return }
        let screenFrame = targetScreen.frame

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        window.collectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .stationary,
        ]

        let hostView = NSHostingView(rootView: AIGlowFullScreenView())
        hostView.frame = NSRect(origin: .zero, size: screenFrame.size)
        hostView.autoresizingMask = [.width, .height]

        window.contentView = hostView

        window.orderFrontRegardless()

        self.overlayWindow = window
    }

    public func stopGlow() {
        guard let window = overlayWindow else { return }
        window.orderOut(nil)
        window.contentView = nil
        self.overlayWindow = nil
    }
}

public func showAIGlowEffect() {
    DispatchQueue.main.async {
        AIGlowManager.shared.startGlow()
    }
}

public func hideAIGlowEffect() {
    DispatchQueue.main.async {
        AIGlowManager.shared.stopGlow()
    }
}
