import Foundation

/// All user-configurable putting parameters.
struct PuttingParameters: Codable, Equatable {
    /// Time for the backstroke in seconds.
    var backstrokeTime: Double = Defaults.backstrokeTime

    /// Time for the downstroke in seconds.
    var downstrokeTime: Double = Defaults.downstrokeTime

    /// Desired ball speed at launch in m/s.
    var ballSpeed: Double = Defaults.ballSpeed

    /// Ratio of ball speed to club head speed at impact.
    var smashFactor: Double = Defaults.smashFactor

    /// Green speed (stimpmeter reading in feet). Reserved for future use.
    var stimp: Double = Defaults.stimp

    /// Putt distance in meters. Reserved for future use.
    var puttDistance: Double = Defaults.puttDistance

    // MARK: - Derived values

    /// Club head speed required at impact (m/s).
    var clubHeadSpeed: Double {
        ballSpeed / smashFactor
    }

    /// Pendulum amplitude in meters, derived from the required club head speed
    /// using simple harmonic motion: v = A * pi / (2 * T_down).
    var amplitudeMeters: Double {
        clubHeadSpeed * 2.0 * downstrokeTime / .pi
    }

    /// Amplitude expressed in LED pixel units.
    var amplitudePixels: Double {
        amplitudeMeters * LEDStrip.ledsPerMeter
    }

    /// Total stroke time (backstroke + downstroke).
    var totalStrokeTime: Double {
        backstrokeTime + downstrokeTime
    }
}
