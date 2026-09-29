import Foundation

/// Relay between the two phones through ntfy.sh (free, no account, no Apple push entitlement).
/// Each person has a private topic; the app polls its own topic while it is alive (foreground,
/// or all night in Sleep Mode thanks to the keep-alive audio) and the other phone posts to it.
/// Messages are plain text: "ring:<sender id>" to wake someone, "awake:<id>" as the reply.
enum BuddyLink {

    struct Message {
        let id: String
        let time: Date
        let text: String
    }

    private static let base = URL(string: "https://ntfy.sh")!
    /// Random suffix so strangers don't stumble onto the topics.
    private static let topicPrefix = "wakeqr-wg2hv5di6qka-"

    private static func topicURL(_ person: String) -> URL {
        base.appendingPathComponent(topicPrefix + person)
    }

    /// Returns false when the message did not reach the server (no internet, rate limit...).
    static func send(_ text: String, to person: String) async -> Bool {
        var req = URLRequest(url: topicURL(person))
        req.httpMethod = "POST"
        req.httpBody = Data(text.utf8)
        req.timeoutInterval = 15
        guard let result = try? await URLSession.shared.data(for: req) else { return false }
        return (result.1 as? HTTPURLResponse)?.statusCode == 200
    }

    /// Messages posted to `person`'s topic in the last few minutes (the caller dedupes by id).
    static func recent(for person: String) async -> [Message] {
        var comps = URLComponents(url: topicURL(person).appendingPathComponent("json"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "poll", value: "1"),
                            URLQueryItem(name: "since", value: "5m")]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 15
        req.cachePolicy = .reloadIgnoringLocalCacheData
        guard let result = try? await URLSession.shared.data(for: req) else { return [] }

        struct Raw: Decodable {
            let id: String
            let time: Double
            let event: String
            let message: String?
        }
        // One JSON object per line.
        return result.0.split(separator: UInt8(ascii: "\n")).compactMap { line in
            guard let raw = try? JSONDecoder().decode(Raw.self, from: Data(line)),
                  raw.event == "message", let text = raw.message else { return nil }
            return Message(id: raw.id, time: Date(timeIntervalSince1970: raw.time), text: text)
        }
    }
}
