import SwiftUI

/// Parameter configuration view with sliders for all putting settings.
struct SettingsView: View {
    @Binding var parameters: PuttingParameters

    var body: some View {
        Form {
            Section("Tempo") {
                parameterSlider(
                    title: "Backstroke Time",
                    value: $parameters.backstrokeTime,
                    range: 0.2...1.5,
                    unit: "s",
                    format: "%.2f"
                )
                parameterSlider(
                    title: "Downstroke Time",
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

            Section("Ball Speed") {
                parameterSlider(
                    title: "Desired Ball Speed",
                    value: $parameters.ballSpeed,
                    range: 0.1...5.0,
                    unit: "m/s",
                    format: "%.2f"
                )
                parameterSlider(
                    title: "Smash Factor",
                    value: $parameters.smashFactor,
                    range: 0.5...2.0,
                    unit: "",
                    format: "%.2f"
                )
            }

            Section("Course") {
                parameterSlider(
                    title: "Stimp",
                    value: $parameters.stimp,
                    range: 5.0...15.0,
                    unit: "ft",
                    format: "%.1f"
                )
                parameterSlider(
                    title: "Putt Distance",
                    value: $parameters.puttDistance,
                    range: 0.5...20.0,
                    unit: "m",
                    format: "%.1f"
                )
            }

            Section("Computed Values") {
                infoRow("Club Head Speed", value: String(format: "%.3f m/s", parameters.clubHeadSpeed))
                infoRow("Amplitude", value: String(format: "%.1f pixels (%.1f cm)", parameters.amplitudePixels, parameters.amplitudeMeters * 100))
                infoRow("Total Stroke", value: String(format: "%.2f s", parameters.totalStrokeTime))
            }
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
