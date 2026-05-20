import AppKit
import Combine
import Foundation

@MainActor
final class UpdateService: ObservableObject {

    static let shared = UpdateService()

    private static let releaseAPI = URL(string: "https://api.github.com/repos/NoahShin/no_more_turtle/releases/latest")!

    enum State: Equatable {
        case idle
        case checking
        case upToDate(checkedAt: Date)
        case available(LatestRelease)
        case downloading
        case installing
        case failed(message: String)
    }

    struct LatestRelease: Equatable {
        let version: String
        let dmgURL: URL
        let releaseNotes: String
        let publishedAt: Date
    }

    @Published private(set) var state: State = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private init() {}

    func checkForUpdates() async {
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            if Self.isNewer(release.version, than: currentVersion) {
                state = .available(release)
            } else {
                state = .upToDate(checkedAt: Date())
            }
        } catch {
            state = .failed(message: "업데이트 확인 실패: \(error.localizedDescription)")
        }
    }

    func downloadAndInstall(_ release: LatestRelease) async {
        state = .downloading
        do {
            let dmgURL = try await downloadDMG(from: release.dmgURL)
            state = .installing
            try install(dmgURL: dmgURL)
            // install() relaunches and calls NSApp.terminate; never returns.
        } catch {
            state = .failed(message: "업데이트 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - GitHub API

    private func fetchLatestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: Self.releaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("no_more_turtle/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.api("GitHub API가 비정상 응답을 반환했습니다.")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release = try decoder.decode(GitHubRelease.self, from: data)

        guard let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
            throw UpdateError.api("최신 릴리즈에 .dmg 파일이 없습니다.")
        }
        guard let dmgURL = URL(string: dmg.browserDownloadURL) else {
            throw UpdateError.api("DMG URL이 잘못됐습니다.")
        }

        let version = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        return LatestRelease(
            version: version,
            dmgURL: dmgURL,
            releaseNotes: release.body,
            publishedAt: release.publishedAt
        )
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let body: String
        let publishedAt: Date
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case publishedAt = "published_at"
            case assets
        }
    }

    // MARK: - Download

    private func downloadDMG(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.download("다운로드 중 서버 오류가 발생했습니다.")
        }

        // Move out of the auto-deletion temp into our own scratch space so the file survives.
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("no-more-turtle-update-\(UUID().uuidString.prefix(8)).dmg")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    // MARK: - Install

    private func install(dmgURL: URL) throws {
        let mountPoint = "/private/tmp/no-more-turtle-mount-\(UUID().uuidString.prefix(8))"

        try shell(["/usr/bin/hdiutil", "attach", "-nobrowse", "-noautoopen",
                   "-mountpoint", mountPoint, dmgURL.path])
        defer { _ = try? shell(["/usr/bin/hdiutil", "detach", mountPoint, "-force"]) }

        let appInDMG = URL(fileURLWithPath: mountPoint).appendingPathComponent("NoMoreTurtle.app")
        guard FileManager.default.fileExists(atPath: appInDMG.path) else {
            throw UpdateError.install("DMG 안에서 NoMoreTurtle.app을 찾을 수 없습니다.")
        }

        let currentAppURL = Bundle.main.bundleURL
        let parent = currentAppURL.deletingLastPathComponent()
        let stagingURL = parent.appendingPathComponent(
            ".no-more-turtle-staging-\(UUID().uuidString.prefix(8)).app"
        )
        let backupURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("NoMoreTurtle-backup-\(Int(Date().timeIntervalSince1970)).app")

        // Stage new bundle alongside the current one (same volume = atomic mv possible).
        try? FileManager.default.removeItem(at: stagingURL)
        try FileManager.default.copyItem(at: appInDMG, to: stagingURL)

        // Strip quarantine on the staged copy before it goes live.
        _ = try? shell(["/usr/bin/xattr", "-dr", "com.apple.quarantine", stagingURL.path])

        // Swap: old → backup, staging → current location.
        do {
            try FileManager.default.moveItem(at: currentAppURL, to: backupURL)
            try FileManager.default.moveItem(at: stagingURL, to: currentAppURL)
        } catch {
            // Best-effort rollback if the second move failed and the first succeeded.
            if !FileManager.default.fileExists(atPath: currentAppURL.path),
               FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.moveItem(at: backupURL, to: currentAppURL)
            }
            throw UpdateError.install("앱 교체에 실패했습니다: \(error.localizedDescription)")
        }

        try relaunch(at: currentAppURL)
    }

    private func relaunch(at appURL: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        // Detached subshell: wait for our PID to die, then open the new bundle.
        // The trailing `& disown` and IO redirection make sure the child survives our exit.
        let escapedPath = appURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        (
          while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
          sleep 0.2
          /usr/bin/open -n '\(escapedPath)'
        ) </dev/null >/dev/null 2>&1 &
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        try task.run()
        task.waitUntilExit()

        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    @discardableResult
    private func shell(_ args: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: args[0])
        task.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard task.terminationStatus == 0 else {
            throw UpdateError.install("\(args.joined(separator: " ")) 실패: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return output
    }

    // MARK: - Version comparison

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

enum UpdateError: LocalizedError {
    case api(String)
    case download(String)
    case install(String)

    var errorDescription: String? {
        switch self {
        case .api(let m), .download(let m), .install(let m):
            return m
        }
    }
}
