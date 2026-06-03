import AppKit
import CoreHaptics

@_cdecl("trigger_trackpad_haptic_bridge")
public func triggerOneshotHaptic(intensity: Float, sharpness: Float) {
    if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            try engine.start()

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            engine.stoppedHandler = { reason in
                _ = engine
            }

            try player.start(atTime: 0)
            return
        } catch {
        }
    }

    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
}
