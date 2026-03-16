import SwiftUI

/// Displays an animated LED strip simulator that visualizes the putting tempo.
///
/// Uses `TimelineView` to drive animation at display refresh rate.
/// The same `AnimationRenderer.ballPosition` function that generates frames
/// for the ESP32 is used here, ensuring what you see matches what the
/// hardware will display.
struct LEDSimulatorView: View {
    let parameters: PuttingParameters

    /// How long to pause (dark) between animation loops.
    private let pauseBetweenLoops: Double = 1.5

    /// Duration of the count-in pulses.
    private var countInDuration: Double {
        AnimationRenderer.countInDuration(params: parameters)
    }

    /// Total cycle time: pause + count-in + stroke.
    private var cycleDuration: Double {
        pauseBetweenLoops + countInDuration + AnimationConfig.sequenceDuration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / AnimationConfig.fps)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let t = elapsed.truncatingRemainder(dividingBy: cycleDuration)
            let frame = currentFrame(at: t)

            VStack(spacing: 4) {
                phaseLabel(at: t)

                ledStrip(frame: frame)

                cmScale

                timeDisplay(at: t)
            }
        }
        .padding()
    }

    // MARK: - LED strip rendering

    @ViewBuilder
    private func ledStrip(frame: [UInt8]) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 1
            let totalSpacing = spacing * CGFloat(LEDStrip.pixelCount - 1)
            let ledWidth = (geo.size.width - totalSpacing) / CGFloat(LEDStrip.pixelCount)
            let ledHeight: CGFloat = max(ledWidth * 1.2, 16)

            HStack(spacing: spacing) {
                ForEach(0..<LEDStrip.pixelCount, id: \.self) { i in
                    let intensity = Double(frame[i]) / 255.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ledColor(intensity: intensity))
                        .shadow(
                            color: intensity > 0.1 ? .white.opacity(intensity * 0.6) : .clear,
                            radius: intensity * 4
                        )
                        .frame(width: ledWidth, height: ledHeight)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.black)
                .padding(-4)
        )
        .padding(.horizontal, 4)
    }

    /// Maps LED intensity (0-1) to a visible color with warm-to-cool shift.
    /// Low intensity = dim warm amber, high intensity = bright white.
    private func ledColor(intensity: Double) -> Color {
        if intensity < 0.01 {
            return Color(white: 0.08)
        }
        // Warm amber at low intensity, shifting to pure white at full
        let warmth = 1.0 - intensity  // 1.0 = warm, 0.0 = white
        let r = 0.15 + intensity * 0.85
        let g = 0.12 + intensity * 0.88 - warmth * 0.15
        let b = 0.08 + intensity * 0.92 - warmth * 0.35
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Centimeter scale

    /// Tick marks every 10cm (6 LEDs). Labels show distance from center in cm.
    @ViewBuilder
    private var cmScale: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 1
            let totalSpacing = spacing * CGFloat(LEDStrip.pixelCount - 1)
            let ledWidth = (geo.size.width - totalSpacing) / CGFloat(LEDStrip.pixelCount)
            let pixelPitch = ledWidth + spacing
            let center = CGFloat(LEDStrip.pixelCount) / 2.0
            // 10cm = 6 LEDs
            let ledsPerTenCm = LEDStrip.ledsPerMeter / 10.0 // 6.0

            // Tick positions: every 6 LEDs from 0 to 60
            let tickCount = Int(Double(LEDStrip.pixelCount) / ledsPerTenCm) + 1

            ZStack(alignment: .top) {
                // Baseline
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .offset(y: 0)

                ForEach(0..<tickCount, id: \.self) { i in
                    let pixelIndex = Double(i) * ledsPerTenCm
                    let x = CGFloat(pixelIndex) * pixelPitch + ledWidth / 2
                    let cmFromCenter = Int((pixelIndex - center) * (100.0 / LEDStrip.ledsPerMeter))
                    let isMajor = cmFromCenter == 0 || abs(cmFromCenter) % 20 == 0

                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(isMajor ? Color.white.opacity(0.7) : Color.white.opacity(0.35))
                            .frame(width: 1, height: isMajor ? 8 : 5)

                        if isMajor {
                            Text(cmFromCenter == 0 ? "0" : "\(cmFromCenter)")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .fixedSize()
                        }
                    }
                    .position(x: x, y: 10)
                }
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    // MARK: - Phase indicator

    @ViewBuilder
    private func phaseLabel(at t: Double) -> some View {
        let phase = currentPhase(at: t)
        HStack {
            Circle()
                .fill(phase.color)
                .frame(width: 8, height: 8)
            Text(phase.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(phase.color)
        }
    }

    // MARK: - Time display

    @ViewBuilder
    private func timeDisplay(at t: Double) -> some View {
        let phase = currentPhase(at: t)
        switch phase {
        case .backswing(let elapsed, let duration), .downswing(let elapsed, let duration):
            HStack(spacing: 16) {
                Text(String(format: "%.2f / %.2f s", elapsed, duration))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "Club: %.2f mph", parameters.clubHeadSpeed * 2.23694))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .followThrough:
            Text(String(format: "Club: %.2f mph", parameters.clubHeadSpeed * 2.23694))
                .monospacedDigit()
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    // MARK: - Frame generation

    private func currentFrame(at t: Double) -> [UInt8] {
        let pixelCount = LEDStrip.pixelCount

        // Phase 1: pause (dark)
        if t < pauseBetweenLoops {
            return [UInt8](repeating: 0, count: pixelCount)
        }

        // Phase 2: count-in pulses
        let afterPause = t - pauseBetweenLoops
        if afterPause < countInDuration {
            return AnimationRenderer.countInFrame(
                at: afterPause,
                params: parameters,
                pixelCount: pixelCount
            )
        }

        // Phase 3: stroke animation
        let strokeT = afterPause - countInDuration
        let amplitude = parameters.amplitudePixels
        let track = AnimationRenderer.swingTrackRange(amplitude: amplitude)
        guard strokeT < AnimationConfig.sequenceDuration else {
            return [UInt8](repeating: 0, count: pixelCount)
        }
        let position = AnimationRenderer.ballPosition(
            at: strokeT,
            params: parameters,
            amplitude: amplitude
        )
        return AnimationRenderer.renderFrame(
            position: position,
            pixelCount: pixelCount,
            trackRange: track
        )
    }

    // MARK: - Phase tracking

    private enum StrokePhase {
        case paused
        case countIn(pulse: Int, totalPulses: Int)
        case backswing(elapsed: Double, duration: Double)
        case downswing(elapsed: Double, duration: Double)
        case followThrough(elapsed: Double)

        var label: String {
            switch self {
            case .paused: "Ready"
            case .countIn(let pulse, let total): "\(pulse) of \(total)"
            case .backswing: "Backswing"
            case .downswing: "Downswing"
            case .followThrough: "Follow-through"
            }
        }

        var color: Color {
            switch self {
            case .paused: .secondary
            case .countIn: .yellow
            case .backswing: .orange
            case .downswing: .green
            case .followThrough: .blue
            }
        }

        var elapsed: Double {
            switch self {
            case .backswing(let e, _): e
            case .downswing(let e, _): e
            case .followThrough(let e): e
            default: 0
            }
        }

        var duration: Double {
            switch self {
            case .backswing(_, let d): d
            case .downswing(_, let d): d
            default: 0
            }
        }
    }

    private func currentPhase(at t: Double) -> StrokePhase {
        if t < pauseBetweenLoops {
            return .paused
        }

        let afterPause = t - pauseBetweenLoops
        if afterPause < countInDuration {
            let pulseIndex = Int(afterPause / parameters.backstrokeTime) + 1
            return .countIn(pulse: pulseIndex, totalPulses: AnimationRenderer.countInPulses)
        }

        let strokeT = afterPause - countInDuration
        guard strokeT < AnimationConfig.sequenceDuration else {
            return .paused
        }
        let tBack = parameters.backstrokeTime
        let tDown = parameters.downstrokeTime
        let impactTime = tBack + tDown

        if strokeT < tBack {
            return .backswing(elapsed: strokeT, duration: tBack)
        } else if strokeT < impactTime {
            return .downswing(elapsed: strokeT - tBack, duration: tDown)
        } else {
            return .followThrough(elapsed: strokeT - impactTime)
        }
    }
}

#Preview {
    LEDSimulatorView(parameters: PuttingParameters())
        .preferredColorScheme(.dark)
}
