import Foundation

/// Empirical speed ↔ distance lookup tables for putting, indexed by stimp.
/// Speed is in mph (ball speed), distance is in meters.
/// Ported from sig-gsp/frontend/src/lib/putting.ts.
enum SpeedDistanceLookup {

    private struct DataPoint {
        let speed: Double   // ball speed in mph
        let distance: Double // total putt length in meters
    }

    // MARK: - Lookup tables (sorted by speed)

    private static let tables: [Int: [DataPoint]] = [
        10: [
            .init(speed: 1.8, distance: 0.7),
            .init(speed: 2.6, distance: 1.4),
            .init(speed: 3.5, distance: 2.3),
            .init(speed: 4.1, distance: 3.05), // stimpmeter calibration: 10 ft
            .init(speed: 4.3, distance: 3.3),
            .init(speed: 5.4, distance: 4.8),
            .init(speed: 6.6, distance: 6.6),
            .init(speed: 7.4, distance: 7.9),
            .init(speed: 8.5, distance: 9.8),
            .init(speed: 10.2, distance: 12.8),
            .init(speed: 11.5, distance: 15.2),
            .init(speed: 12.2, distance: 16.5),
        ],
        11: [
            .init(speed: 2.4, distance: 1.3),
            .init(speed: 3.2, distance: 2.1),
            .init(speed: 3.6, distance: 2.7),
            .init(speed: 3.9, distance: 3.1),
            .init(speed: 4.1, distance: 3.35), // stimpmeter calibration: 11 ft
            .init(speed: 5.3, distance: 5.1),
            .init(speed: 5.5, distance: 5.3),
            .init(speed: 6.0, distance: 6.2),
            .init(speed: 6.1, distance: 6.3),
            .init(speed: 6.7, distance: 7.2),
            .init(speed: 7.1, distance: 7.9),
            .init(speed: 7.3, distance: 8.4),
            .init(speed: 7.5, distance: 8.7),
            .init(speed: 7.9, distance: 9.4),
            .init(speed: 8.0, distance: 9.6),
            .init(speed: 8.5, distance: 10.4),
            .init(speed: 8.8, distance: 10.9),
            .init(speed: 9.5, distance: 12.3),
            .init(speed: 9.8, distance: 12.9),
            .init(speed: 10.0, distance: 13.2),
            .init(speed: 10.7, distance: 14.6),
            .init(speed: 11.1, distance: 15.4),
            .init(speed: 11.6, distance: 16.3),
        ],
        12: [
            .init(speed: 1.5, distance: 0.6),
            .init(speed: 2.2, distance: 1.3),
            .init(speed: 3.1, distance: 2.4),
            .init(speed: 4.1, distance: 3.66), // stimpmeter calibration: 12 ft
            .init(speed: 4.3, distance: 4.0),
            .init(speed: 4.9, distance: 4.8),
            .init(speed: 5.3, distance: 5.5),
            .init(speed: 5.7, distance: 6.1),
            .init(speed: 5.8, distance: 6.3),
            .init(speed: 6.3, distance: 7.2),
            .init(speed: 6.9, distance: 8.2),
            .init(speed: 7.7, distance: 9.7),
            .init(speed: 8.3, distance: 10.9),
            .init(speed: 8.7, distance: 11.5),
            .init(speed: 9.2, distance: 12.5),
            .init(speed: 9.8, distance: 13.8),
            .init(speed: 10.4, distance: 14.9),
            .init(speed: 11.4, distance: 16.9),
            .init(speed: 12.5, distance: 19.1),
        ],
        13: [
            .init(speed: 1.8, distance: 1.0),
            .init(speed: 2.1, distance: 1.2),
            .init(speed: 2.6, distance: 1.9),
            .init(speed: 4.1, distance: 3.96), // stimpmeter calibration: 13 ft
            .init(speed: 5.4, distance: 6.1),
            .init(speed: 5.8, distance: 6.7),
            .init(speed: 7.5, distance: 9.9),
            .init(speed: 8.8, distance: 12.4),
            .init(speed: 8.9, distance: 12.6),
            .init(speed: 9.5, distance: 13.8),
            .init(speed: 9.7, distance: 14.2),
            .init(speed: 11.0, distance: 17.1),
            .init(speed: 11.7, distance: 18.6),
        ],
    ]

    /// Available stimp values.
    static var availableStimps: [Int] {
        tables.keys.sorted()
    }

    /// Look up required ball speed (mph) for a given distance (meters) and stimp.
    /// Returns nil if no table exists for the given stimp.
    static func speedForDistance(_ distance: Double, stimp: Int) -> Double? {
        guard let table = tables[stimp] else { return nil }

        if distance <= table.first!.distance {
            return table.first!.speed
        }
        if distance >= table.last!.distance {
            let a = table[table.count - 2]
            let b = table.last!
            return lerp(x: distance, x0: a.distance, y0: a.speed, x1: b.distance, y1: b.speed)
        }
        for i in 0..<(table.count - 1) {
            let curr = table[i], next = table[i + 1]
            if distance >= curr.distance && distance <= next.distance {
                return lerp(x: distance, x0: curr.distance, y0: curr.speed, x1: next.distance, y1: next.speed)
            }
        }
        return nil
    }

    /// Look up expected distance (meters) for a given ball speed (mph) and stimp.
    /// Returns nil if no table exists for the given stimp.
    static func distanceForSpeed(_ speed: Double, stimp: Int) -> Double? {
        guard let table = tables[stimp] else { return nil }

        if speed <= table.first!.speed {
            return table.first!.distance
        }
        if speed >= table.last!.speed {
            let a = table[table.count - 2]
            let b = table.last!
            return lerp(x: speed, x0: a.speed, y0: a.distance, x1: b.speed, y1: b.distance)
        }
        for i in 0..<(table.count - 1) {
            let curr = table[i], next = table[i + 1]
            if speed >= curr.speed && speed <= next.speed {
                return lerp(x: speed, x0: curr.speed, y0: curr.distance, x1: next.speed, y1: next.distance)
            }
        }
        return nil
    }

    private static func lerp(x: Double, x0: Double, y0: Double, x1: Double, y1: Double) -> Double {
        guard abs(x1 - x0) > 1e-9 else { return y0 }
        return y0 + (x - x0) * (y1 - y0) / (x1 - x0)
    }
}
