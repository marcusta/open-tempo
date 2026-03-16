import Foundation

/// Renders a `PuttingParameters` configuration into a sequence of LED frames.
///
/// The animation models the putter head as a pendulum using sinusoidal motion:
/// - Backstroke: center -> peak over `backstrokeTime` (decelerating)
/// - Downstroke: peak -> center over `downstrokeTime` (accelerating)
/// - Follow-through: the ball continues past center after impact
///
/// Each frame is 60 bytes (one byte per LED, white intensity 0-255).
/// Sub-pixel antialiasing distributes intensity between adjacent LEDs
/// when the computed position falls between two pixel indices.
enum AnimationRenderer {

    /// Center pixel index (0-based). The ball starts here at address.
    static let centerPixel: Double = Double(LEDStrip.pixelCount / 2) // 30.0

    /// Render a full animation sequence.
    /// - Parameter params: The putting parameters.
    /// - Returns: A flat `Data` blob of `totalFrames * pixelCount` bytes.
    static func render(params: PuttingParameters) -> (frameCount: Int, data: Data) {
        let fps = AnimationConfig.fps
        let totalDuration = AnimationConfig.sequenceDuration
        let totalFrames = AnimationConfig.totalFrames
        let pixelCount = LEDStrip.pixelCount
        let amplitude = params.amplitudePixels

        var allFrames = Data(capacity: totalFrames * pixelCount)

        let track = swingTrackRange(amplitude: amplitude)

        for frameIndex in 0..<totalFrames {
            let t = Double(frameIndex) / fps
            let position = ballPosition(at: t, params: params, amplitude: amplitude)
            let frame = renderFrame(position: position, pixelCount: pixelCount, trackRange: track)
            allFrames.append(contentsOf: frame)
        }

        return (totalFrames, allFrames)
    }

    // MARK: - Motion model

    /// Compute the ball (putter head) position in pixel-space at time `t`.
    ///
    /// Timeline:
    /// - Phase 1 (0 ..< backstrokeTime): backstroke, center -> peak
    ///   Uses cosine curve for smooth deceleration: pos = center - A * sin(pi/2 * t/T_back)
    /// - Phase 2 (backstrokeTime ..< backstrokeTime + downstrokeTime): downstroke, peak -> center
    ///   Uses sine curve for smooth acceleration: pos = center - A * cos(pi/2 * (t-T_back)/T_down)
    /// - Phase 3 (after impact): ball travels forward at ball speed
    static func ballPosition(at t: Double, params: PuttingParameters, amplitude: Double) -> Double {
        let tBack = params.backstrokeTime
        let tDown = params.downstrokeTime
        let impactTime = tBack + tDown

        if t < 0 {
            return centerPixel
        } else if t < tBack {
            // Backstroke: smoothly move from center to peak (center - amplitude)
            // sin(0) = 0, sin(pi/2) = 1 -> position goes from center to center-amplitude
            let phase = (.pi / 2.0) * (t / tBack)
            return centerPixel - amplitude * sin(phase)
        } else if t < impactTime {
            // Downstroke: smoothly move from peak back through center
            // cos(0) = 1, cos(pi/2) = 0 -> position goes from center-amplitude to center
            let elapsed = t - tBack
            let phase = (.pi / 2.0) * (elapsed / tDown)
            return centerPixel - amplitude * cos(phase)
        } else {
            // Follow-through: mirror the downswing deceleration, capped at amplitude
            let elapsed = t - impactTime
            let followPhase = min((.pi / 2.0) * (elapsed / tDown), .pi / 2.0)
            return centerPixel + amplitude * sin(followPhase)
        }
    }

    /// Compute the pixel range for the dim swing track.
    /// Covers from backswing peak to a symmetric follow-through past center.
    static func swingTrackRange(amplitude: Double) -> ClosedRange<Double> {
        let lo = centerPixel - amplitude
        let hi = centerPixel + amplitude
        return lo...hi
    }

    // MARK: - Count-in

    /// Number of preparatory pulses before the stroke begins.
    static let countInPulses = 6

    /// Duration of the count-in phase: pulses spaced at backstrokeTime.
    static func countInDuration(params: PuttingParameters) -> Double {
        Double(countInPulses) * params.backstrokeTime
    }

    /// Render a count-in frame: shrinking centered bar that pulsates.
    ///
    /// - Tick 1: full strip width, low intensity
    /// - Tick 6: narrow bar near center, high intensity
    ///
    /// Each tick pulses with a sine curve. Both the bar width and peak
    /// intensity converge toward the center as we approach the stroke.
    static func countInFrame(at t: Double, params: PuttingParameters, pixelCount: Int) -> [UInt8] {
        let pulseInterval = params.backstrokeTime
        let tickIndex = min(Int(t / pulseInterval), countInPulses - 1) // 0-based
        let tInPulse = t - Double(tickIndex) * pulseInterval

        // Progress 0.0 (first tick) to 1.0 (last tick)
        let progress = Double(tickIndex) / Double(countInPulses - 1)

        // Bar shrinks: full strip -> ~10% of strip (centered)
        let barFraction = 1.0 - progress * 0.85
        let halfBar = Double(pixelCount) * barFraction / 2.0
        let center = Double(pixelCount) / 2.0

        // Peak intensity grows: 30% -> 90% as countdown progresses
        let peakIntensity = 0.3 + progress * 0.6

        // Sine pulse within each tick: smooth 0 -> peak -> 0
        let pulse = sin(.pi * tInPulse / pulseInterval)
        let intensity = pulse * peakIntensity

        // Render the bar with soft edges
        var frame = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let distFromCenter = abs(Double(i) - center)
            if distFromCenter < halfBar {
                // Inside the bar: full intensity
                frame[i] = UInt8(clamping: Int(round(intensity * 255.0)))
            } else if distFromCenter < halfBar + 2.0 {
                // Soft edge: fade out over 2 pixels
                let edgeFade = 1.0 - (distFromCenter - halfBar) / 2.0
                frame[i] = UInt8(clamping: Int(round(intensity * edgeFade * 255.0)))
            }
        }
        return frame
    }

    // MARK: - Frame rendering

    /// Intensity of the dim track that shows the full swing path (0-255).
    static let trackIntensity: UInt8 = 35

    /// Render a single frame with sub-pixel antialiasing and optional swing track.
    /// - Parameters:
    ///   - position: The ball position in pixel-space (fractional).
    ///   - pixelCount: Number of LEDs.
    ///   - trackRange: Optional pixel range to light dimly as the swing path guide.
    /// - Returns: Array of `pixelCount` intensity values.
    static func renderFrame(position: Double, pixelCount: Int, trackRange: ClosedRange<Double>? = nil) -> [UInt8] {
        var frame = [UInt8](repeating: 0, count: pixelCount)

        // Draw the dim track if provided
        if let track = trackRange {
            let lo = max(0, Int(floor(track.lowerBound)))
            let hi = min(pixelCount - 1, Int(ceil(track.upperBound)))
            for i in lo...hi {
                // Soft edges at track boundaries
                let pixel = Double(i)
                var intensity = 1.0
                if pixel < track.lowerBound {
                    intensity = 1.0 - (track.lowerBound - pixel)
                } else if pixel > track.upperBound {
                    intensity = 1.0 - (pixel - track.upperBound)
                }
                frame[i] = UInt8(clamping: Int(round(Double(trackIntensity) * max(0, intensity))))
            }
        }

        // Draw the bright marker on top
        guard position >= -0.5 && position < Double(pixelCount) + 0.5 else {
            return frame
        }

        let lower = Int(floor(position))
        let fraction = position - Double(lower)

        let intensityLower = UInt8(clamping: Int(round(255.0 * (1.0 - fraction))))
        let intensityUpper = UInt8(clamping: Int(round(255.0 * fraction)))

        if lower >= 0 && lower < pixelCount {
            frame[lower] = max(frame[lower], intensityLower)
        }
        if (lower + 1) >= 0 && (lower + 1) < pixelCount {
            frame[lower + 1] = max(frame[lower + 1], intensityUpper)
        }

        return frame
    }
}
