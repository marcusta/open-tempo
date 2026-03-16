import Foundation

/// A calibration point mapping ball speed (mph) to smash factor.
struct SmashCalibrationPoint: Codable, Equatable, Identifiable {
    var id = UUID()
    var ballSpeedMph: Double
    var smashFactor: Double
}

/// All user-configurable putting parameters.
struct PuttingParameters: Codable, Equatable {
    /// Time for the backstroke in seconds.
    var backstrokeTime: Double = Defaults.backstrokeTime

    /// Time for the downstroke in seconds.
    var downstrokeTime: Double = Defaults.downstrokeTime

    /// Desired ball speed at launch in m/s.
    var ballSpeed: Double = Defaults.ballSpeed

    /// Smash factor calibration curve: ball speed (mph) → smash factor.
    /// Sorted by ballSpeedMph. Interpolated for intermediate values.
    var smashCalibration: [SmashCalibrationPoint] = Defaults.smashCalibration

    /// Green speed (stimpmeter reading in feet) stored as integer for lookup table compatibility.
    var stimpInt: Int = Int(Defaults.stimp)

    /// Putt distance in meters. Reserved for future use.
    var puttDistance: Double = Defaults.puttDistance

    // MARK: - Derived values

    /// Smash factor interpolated from calibration curve for the current ball speed.
    var smashFactor: Double {
        let speedMph = ballSpeed * 2.23694
        let sorted = smashCalibration.sorted { $0.ballSpeedMph < $1.ballSpeedMph }
        guard let first = sorted.first, let last = sorted.last else { return 1.0 }
        if sorted.count == 1 || speedMph <= first.ballSpeedMph { return first.smashFactor }
        if speedMph >= last.ballSpeedMph { return last.smashFactor }
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i], b = sorted[i + 1]
            if speedMph >= a.ballSpeedMph && speedMph <= b.ballSpeedMph {
                let t = (speedMph - a.ballSpeedMph) / (b.ballSpeedMph - a.ballSpeedMph)
                return a.smashFactor + t * (b.smashFactor - a.smashFactor)
            }
        }
        return last.smashFactor
    }

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
