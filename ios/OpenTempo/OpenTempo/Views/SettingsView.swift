import SwiftUI

/// Parameter configuration view with sliders for all putting settings.
struct SettingsView: View {
    @Binding var parameters: PuttingParameters

    var body: some View {
        Form {
            Section("Tempo") {
                parameterSlider(
                    title: "Backswing",
                    value: $parameters.backstrokeTime,
                    range: 0.2...1.5,
                    unit: "s",
                    format: "%.2f"
                )
                parameterSlider(
                    title: "Downswing",
                    value: $parameters.downstrokeTime,
                    range: 0.1...1.0,
                    unit: "s",
                    format: "%.2f"
                )

                HStack {
                    Text("Ratio")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f : 1", parameters.backstrokeTime / parameters.downstrokeTime))
                        .monospacedDigit()
                }
            }

            Section("Course") {
                Picker("Stimp", selection: $parameters.stimpInt) {
                    ForEach(SpeedDistanceLookup.availableStimps, id: \.self) { stimp in
                        Text("\(stimp) ft").tag(stimp)
                    }
                }

                parameterSlider(
                    title: "Putt Distance",
                    value: $parameters.puttDistance,
                    range: 0.5...20.0,
                    unit: "m",
                    format: "%.1f"
                )
            }
            .onChange(of: parameters.stimpInt) { updateBallSpeedFromLookup() }
            .onChange(of: parameters.puttDistance) { updateBallSpeedFromLookup() }

            Section("Computed Values") {
                infoRow("Ball Speed", value: String(format: "%.1f mph", parameters.ballSpeed * metersPerSecToMph))
                NavigationLink {
                    SmashCalibrationView(calibration: $parameters.smashCalibration)
                } label: {
                    HStack {
                        Text("Smash Factor")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f", parameters.smashFactor))
                            .monospacedDigit()
                    }
                }
                infoRow("Club Head Speed", value: String(format: "%.2f mph", parameters.clubHeadSpeed * metersPerSecToMph))
                infoRow("Amplitude", value: String(format: "%.1f px (%.1f cm)", parameters.amplitudePixels, parameters.amplitudeMeters * 100))
                infoRow("Total Stroke", value: String(format: "%.2f s", parameters.totalStrokeTime))
            }
        }
        .onAppear { updateBallSpeedFromLookup() }
    }

    private let metersPerSecToMph: Double = 2.23694

    private func updateBallSpeedFromLookup() {
        if let speedMph = SpeedDistanceLookup.speedForDistance(
            parameters.puttDistance, stimp: parameters.stimpInt
        ) {
            parameters.ballSpeed = speedMph / metersPerSecToMph
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func parameterSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(String(format: format, value.wrappedValue)) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    /// Slider that displays in mph but binds to a m/s value.
    @ViewBuilder
    private func mphSlider(
        title: String,
        metricValue: Binding<Double>,
        mphRange: ClosedRange<Double>
    ) -> some View {
        let mphBinding = Binding<Double>(
            get: { metricValue.wrappedValue * metersPerSecToMph },
            set: { metricValue.wrappedValue = $0 / metersPerSecToMph }
        )
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.1f mph", mphBinding.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: mphBinding, in: mphRange)
        }
    }

    @ViewBuilder
    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }
}

#Preview {
    SettingsView(parameters: .constant(PuttingParameters()))
}
