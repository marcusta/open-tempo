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
        let fps = Animation.fps
        let totalDuration = Animation.sequenceDuration
        let totalFrames = Animation.totalFrames
        let pixelCount = LEDStrip.pixelCount
        let amplitude = params.amplitudePixels

        var allFrames = Data(capacity: totalFrames * pixelCount)

        for frameIndex in 0..<totalFrames {
            let t = Double(frameIndex) / fps
            let position = ballPosition(at: t, params: params, amplitude: amplitude)
            let frame = renderFrame(position: position, pixelCount: pixelCount)
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
            // Follow-through / ball rolling forward after impact
            // Ball speed in pixels/second
            let ballSpeedPixels = params.ballSpeed * LEDStrip.ledsPerMeter
            let elapsed = t - impactTime
            return centerPixel + ballSpeedPixels * elapsed
        }
    }

    // MARK: - Frame rendering

    /// Render a single frame with sub-pixel antialiasing.
    /// - Parameters:
    ///   - position: The ball position in pixel-space (fractional).
    ///   - pixelCount: Number of LEDs.
    /// - Returns: Array of `pixelCount` intensity values.
    static func renderFrame(position: Double, pixelCount: Int) -> [UInt8] {
        var frame = [UInt8](repeating: 0, count: pixelCount)

        // If the ball is completely off-strip, return blank frame.
        guard position >= -0.5 && position < Double(pixelCount) + 0.5 else {
            return frame
        }

        let lower = Int(floor(position))
        let fraction = position - Double(lower)

        // Distribute intensity between the two nearest pixels.
        let intensityLower = UInt8(clamping: Int(round(255.0 * (1.0 - fraction))))
        let intensityUpper = UInt8(clamping: Int(round(255.0 * fraction)))

        if lower >= 0 && lower < pixelCount {
            frame[lower] = intensityLower
        }
        if (lower + 1) >= 0 && (lower + 1) < pixelCount {
            frame[lower + 1] = intensityUpper
        }

        return frame
    }
}
