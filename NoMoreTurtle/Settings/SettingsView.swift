import SwiftUI

struct SettingsView: View {

    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            sliderSection(
                title: "감지 민감도",
                value: $settings.scoreThreshold,
                range: 0.40...1.00,
                step: 0.05,
                valueLabel: String(format: "%.2f", settings.scoreThreshold),
                caption: "낮을수록 자세 살짝만 안 좋아도 거북이 등장, 높을수록 거의 완전한 거북목에서만 등장합니다."
            )

            sliderSection(
                title: "거북이 크기",
                value: $settings.overlaySize,
                range: 200...1000,
                step: 50,
                valueLabel: "\(Int(settings.overlaySize))px",
                caption: "다음 거북이 등장 시점부터 적용됩니다."
            )

            sliderSection(
                title: "거북이 투명도",
                value: $settings.overlayOpacity,
                range: 0.10...1.00,
                step: 0.05,
                valueLabel: "\(Int(settings.overlayOpacity * 100))%",
                caption: nil
            )

            Divider()

            Toggle("앱 실행 시 자동으로 모니터링 시작", isOn: $settings.autoStartMonitoring)
                .toggleStyle(.switch)

            HStack {
                Spacer()
                Button("기본값으로 초기화", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    @ViewBuilder
    private func sliderSection(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueLabel: String,
        caption: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(valueLabel)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
