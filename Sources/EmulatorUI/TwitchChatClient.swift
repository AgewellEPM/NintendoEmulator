import Foundation
import Network
import SwiftUI

/// Minimal Twitch IRC chat client over TLS
/// Connects to irc.chat.twitch.tv and emits chat messages.
final class TwitchChatClient {
    struct Message {
        let username: String
        let text: String
        let colorHex: String?
        let badges: String?
    }

    private let host = NWEndpoint.Host("irc.chat.twitch.tv")
    private let port = NWEndpoint.Port(rawValue: 6697)!
    private var connection: NWConnection?
    private var receiveBuffer = Data()

    private var onMessage: ((Message) -> Void)?
    private var onStateChange: ((Bool) -> Void)?

    private var channel: String = ""
    private var isConnected: Bool = false {
        didSet { onStateChange?(isConnected) }
    }

    func connect(oauthToken: String?, username: String?, channel: String,
                 onStateChange: ((Bool) -> Void)? = nil,
                 onMessage: @escaping (Message) -> Void) {
        self.onMessage = onMessage
        self.onStateChange = onStateChange
        self.channel = channel

        let params = NWParameters.tls
        params.allowLocalEndpointReuse = true

        let conn = NWConnection(host: host, port: port, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.performLogin(oauthToken: oauthToken, username: username, channel: channel)
                self?.receiveLoop()
            case .failed, .cancelled:
                self?.isConnected = false
            default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInitiated))
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    func sendMessage(_ text: String) {
        guard let connection else { return }
        let line = "PRIVMSG #\(channel) :\(text)\r\n"
        send(line, over: connection)
    }

    // MARK: - Private

    private func performLogin(oauthToken: String?, username: String?, channel: String) {
        guard let connection else { return }

        // Request Twitch IRC capabilities (tags, commands, membership)
        send("CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership\r\n", over: connection)

        if let token = oauthToken, !token.isEmpty {
            // Authenticated connection
            let pass = token.hasPrefix("oauth:") ? token : "oauth:\(token)"
            send("PASS \(pass)\r\n", over: connection)
            let nick = (username?.isEmpty == false ? (username ?? "") : channel)
            send("NICK \(nick)\r\n", over: connection)
        } else {
            // Anonymous read-only connection
            let anonNick = "justinfan\(Int.random(in: 10000...99999))"
            send("NICK \(anonNick)\r\n", over: connection)
        }

        // Join channel
        send("JOIN #\(channel)\r\n", over: connection)
    }

    private func send(_ string: String, over connection: NWConnection) {
        let data = string.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receiveLoop() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.receiveBuffer.append(data)
                self?.processBuffer()
            }

            if isComplete || error != nil {
                self?.disconnect()
                return
            }

            self?.receiveLoop()
        }
    }

    private func processBuffer() {
        while let range = receiveBuffer.firstRange(of: Data([13, 10])) { // CRLF
            let lineData = receiveBuffer.subdata(in: 0..<range.lowerBound)
            receiveBuffer.removeSubrange(0..<(range.upperBound))
            if let line = String(data: lineData, encoding: .utf8) {
                handleLine(line)
            }
        }
    }

    private func handleLine(_ line: String) {
        // Respond to PING
        if line.hasPrefix("PING ") {
            if let connection { send(line.replacingOccurrences(of: "PING", with: "PONG") + "\r\n", over: connection) }
            return
        }

        // Parse IRC line with optional tags
        // Example: @badge-info=;badges=broadcaster/1;color=#FF69B4;display-name=User; :user!user@user.tmi.twitch.tv PRIVMSG #channel :Hello
        var tags: [String: String] = [:]
        var remainder = line
        if remainder.hasPrefix("@"), let spaceIdx = remainder.firstIndex(of: " ") {
            let tagPart = String(remainder[..<spaceIdx]).dropFirst() // drop '@'
            remainder = String(remainder[spaceIdx...]).trimmingCharacters(in: .whitespaces)
            tagPart.split(separator: ";").forEach { pair in
                let s = String(pair)
                if let eq = s.firstIndex(of: "=") {
                    let key = String(s[..<eq])
                    let value = String(s[s.index(after: eq)...])
                    tags[key] = value
                }
            }
        }

        // We care about PRIVMSG for chat messages
        if remainder.contains(" PRIVMSG ") {
            // Extract username
            var username = ""
            if let bang = remainder.firstIndex(of: "!"), remainder.first == ":" {
                username = String(remainder[remainder.index(after: remainder.startIndex)..<bang])
            } else if let display = tags["display-name"], !display.isEmpty {
                username = display
            }

            // Extract message text (after ' :')
            let components = remainder.components(separatedBy: " :")
            guard components.count >= 2 else { return }
            let text = components.suffix(1).joined(separator: " :")

            let message = Message(
                username: username.isEmpty ? (tags["display-name"] ?? "?") : username,
                text: text,
                colorHex: tags["color"],
                badges: tags["badges"]
            )
            onMessage?(message)
        }
    }
}

// MARK: - Helpers
extension Color {
    static func from(hex: String?) -> Color? {
        guard let hex = hex, hex.hasPrefix("#") else { return nil }
        let hexString = String(hex.dropFirst())
        var int: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&int) else { return nil }
        switch hexString.count {
        case 6:
            let r = Double((int >> 16) & 0xff) / 255.0
            let g = Double((int >> 8) & 0xff) / 255.0
            let b = Double(int & 0xff) / 255.0
            return Color(red: r, green: g, blue: b)
        default:
            return nil
        }
    }
}

// Lightweight connection test for settings UI
enum TwitchConnectionTester {
    static func test(oauthToken: String?, username: String?, channel: String) async -> Bool {
        let client = TwitchChatClient()
        var success = false
        client.connect(oauthToken: oauthToken, username: username, channel: channel, onStateChange: { isUp in
            if isUp { success = true }
        }, onMessage: { _ in })

        // Wait up to ~1.5s and then disconnect
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        client.disconnect()
        return success
    }
}
