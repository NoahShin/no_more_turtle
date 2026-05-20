import SwiftUI

struct UpdateView: View {

    @ObservedObject var service: UpdateService
    @State private var confirmInstall = false
    @State private var pendingRelease: UpdateService.LatestRelease?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("업데이트").font(.headline)
                Spacer()
                Text("현재 v\(service.currentVersion)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            content
        }
        .confirmationDialog(
            "지금 업데이트할까요?",
            isPresented: $confirmInstall,
            presenting: pendingRelease
        ) { release in
            Button("업데이트 (앱이 자동 재시작됩니다)") {
                Task { await service.downloadAndInstall(release) }
            }
            Button("취소", role: .cancel) { }
        } message: { release in
            Text("v\(release.version)로 업데이트합니다. 새 버전을 다운로드하고 앱을 자동으로 재시작합니다.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.state {

        case .idle:
            Button {
                Task { await service.checkForUpdates() }
            } label: {
                Label("업데이트 확인", systemImage: "arrow.clockwise")
            }

        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("최신 버전 확인 중…").foregroundStyle(.secondary)
            }

        case .upToDate(let date):
            HStack {
                Label("최신 버전이에요", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("다시 확인") {
                    Task { await service.checkForUpdates() }
                }
                .controlSize(.small)
            }
            Text("마지막 확인: \(date.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)

        case .available(let release):
            HStack {
                Label("새 버전 v\(release.version) 사용 가능", systemImage: "sparkles")
                    .foregroundStyle(.orange)
                Spacer()
            }
            if !release.releaseNotes.isEmpty {
                ScrollView {
                    Text(release.releaseNotes)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Button {
                pendingRelease = release
                confirmInstall = true
            } label: {
                Label("지금 업데이트", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)

        case .downloading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("새 버전 다운로드 중…").foregroundStyle(.secondary)
            }

        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("설치 중… 곧 재시작합니다.").foregroundStyle(.secondary)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Button("다시 시도") {
                    Task { await service.checkForUpdates() }
                }
                .controlSize(.small)
            }
        }
    }
}
