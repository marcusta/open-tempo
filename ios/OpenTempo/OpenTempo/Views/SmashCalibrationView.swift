import SwiftUI

/// Editor for the smash factor calibration curve.
/// Each row maps a ball speed (mph) to a smash factor.
struct SmashCalibrationView: View {
    @Binding var calibration: [SmashCalibrationPoint]

    var body: some View {
        Form {
            Section {
                ForEach($calibration) { $point in
                    HStack {
                        Text(String(format: "%.1f mph", point.ballSpeedMph))
                            .frame(width: 75, alignment: .leading)
                            .monospacedDigit()
                        Slider(value: $point.smashFactor, in: 1.0...2.0, step: 0.01)
                        Text(String(format: "%.2f", point.smashFactor))
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indices in
                    calibration.remove(atOffsets: indices)
                }
            } header: {
                Text("Ball Speed → Smash Factor")
            } footer: {
                Text("Values between points are interpolated. Swipe to delete.")
            }

            Section {
                Button("Add Point") {
                    let newSpeed = (calibration.last?.ballSpeedMph ?? 6.0) + 2.0
                    calibration.append(
                        SmashCalibrationPoint(ballSpeedMph: newSpeed, smashFactor: 1.4)
                    )
                    calibration.sort { $0.ballSpeedMph < $1.ballSpeedMph }
                }

                Button("Reset to Defaults") {
                    calibration = Defaults.smashCalibration
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Smash Factor")
    }
}

#Preview {
    NavigationStack {
        SmashCalibrationView(calibration: .constant(Defaults.smashCalibration))
    }
}
