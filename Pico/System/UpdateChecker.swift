import Foundation

enum VersionCompare {
    /// True when `latest` is a higher dotted version than `current`. A leading "v" is ignored.
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let next = parts(latest)
        let now = parts(current)
        let count = max(next.count, now.count)
        for index in 0..<count {
            let lhs = index < next.count ? next[index] : 0
            let rhs = index < now.count ? now[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed
        return bare.split(separator: ".").map { Int($0) ?? 0 }
    }
}

struct UpdateCheckResult: Equatable, Sendable {
    var message: String
    var releaseURL: URL?
}

enum UpdateChecker {
    static let repository = "iam-mhaseeb/Pico"

    static func check(currentVersion: String = appVersion()) async -> UpdateCheckResult {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return UpdateCheckResult(message: "Couldn’t look for an update.", releaseURL: nil)
        }
        var request = URLRequest(url: url)
        request.setValue("Pico", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return UpdateCheckResult(
                    message: "No public release yet. You’re on \(currentVersion).",
                    releaseURL: nil
                )
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return UpdateCheckResult(message: "Couldn’t look for an update.", releaseURL: nil)
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = release.tagName
            let page = URL(string: release.htmlURL)
            if VersionCompare.isNewer(latest, than: currentVersion) {
                return UpdateCheckResult(
                    message: "Version \(latest) is available. You’re on \(currentVersion).",
                    releaseURL: page
                )
            }
            return UpdateCheckResult(
                message: "You’re up to date (\(currentVersion)).",
                releaseURL: page
            )
        } catch {
            return UpdateCheckResult(message: "Couldn’t look for an update.", releaseURL: nil)
        }
    }

    static func appVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
