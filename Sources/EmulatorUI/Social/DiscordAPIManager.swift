import Foundation
import Combine
import EmulatorKit

class DiscordAPIManager: ObservableObject {
    private let clientId = SocialAPIConfig.Discord.clientId
    private let clientSecret = SocialAPIConfig.Discord.clientSecret
    private let redirectURI = SocialAPIConfig.Discord.redirectURI
    private let baseURL = "https://discord.com/api/v10"

    @Published var isConnected = false
    @Published var userInfo: DiscordUser?
    @Published var guilds: [DiscordGuild] = []

    func authenticate() -> URL? {
        let scopes = [
            "identify",
            "guilds",
            "messages.read",
            "webhook.incoming"
        ].joined(separator: "%20")

        let authURL = "https://discord.com/api/oauth2/authorize?" +
            "client_id=\(clientId)&" +
            "redirect_uri=\(redirectURI)&" +
            "response_type=code&" +
            "scope=\(scopes)&" +
            "prompt=consent"

        return URL(string: authURL)
    }

    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }

        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        let tokenURL = "https://discord.com/api/oauth2/token"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "client_id=\(clientId)&" +
            "client_secret=\(clientSecret)&" +
            "grant_type=authorization_code&" +
            "code=\(code)&" +
            "redirect_uri=\(redirectURI)"

        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(DiscordTokenResponse.self, from: data)

            // Store tokens securely
            KeychainManager.shared.storeToken(tokenResponse.access_token, for: "discord_access_token")
            KeychainManager.shared.storeToken(tokenResponse.refresh_token, for: "discord_refresh_token")

            await MainActor.run {
                isConnected = true
            }

            await getUserInfo()
            await getGuilds()

        } catch {
            print("Discord token exchange error: \(error)")
        }
    }

    func getUserInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "discord_access_token") else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/users/@me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(DiscordUser.self, from: data)

            await MainActor.run {
                userInfo = user
            }
        } catch {
            print("Discord user info error: \(error)")
        }
    }

    func getGuilds() async {
        guard let token = KeychainManager.shared.getToken(for: "discord_access_token") else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/users/@me/guilds")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let guilds = try JSONDecoder().decode([DiscordGuild].self, from: data)

            await MainActor.run {
                self.guilds = guilds
            }
        } catch {
            print("Discord guilds error: \(error)")
        }
    }

    func sendWebhookMessage(webhookURL: String, content: String, embeds: [DiscordEmbed] = []) async {
        guard let url = URL(string: webhookURL) else { return }

        let message: [String: Any] = [
            "content": content,
            "embeds": embeds.map { embed in
                var embedDict: [String: Any] = [:]
                if let title = embed.title { embedDict["title"] = title }
                if let description = embed.description { embedDict["description"] = description }
                if let color = embed.color { embedDict["color"] = color }
                if let timestamp = embed.timestamp { embedDict["timestamp"] = timestamp }
                if let url = embed.url { embedDict["url"] = url }

                if let thumbnail = embed.thumbnail {
                    embedDict["thumbnail"] = ["url": thumbnail.url]
                }

                if let image = embed.image {
                    embedDict["image"] = ["url": image.url]
                }

                if let author = embed.author {
                    var authorDict: [String: Any] = ["name": author.name]
                    if let iconURL = author.icon_url { authorDict["icon_url"] = iconURL }
                    if let url = author.url { authorDict["url"] = url }
                    embedDict["author"] = authorDict
                }

                if let footer = embed.footer {
                    var footerDict: [String: Any] = ["text": footer.text]
                    if let iconURL = footer.icon_url { footerDict["icon_url"] = iconURL }
                    embedDict["footer"] = footerDict
                }

                if !embed.fields.isEmpty {
                    embedDict["fields"] = embed.fields.map { field in
                        [
                            "name": field.name,
                            "value": field.value,
                            "inline": field.inline
                        ]
                    }
                }

                return embedDict
            }
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: message)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let _ = try await URLSession.shared.data(for: request)
            print("✅ Discord webhook message sent")
        } catch {
            print("Discord webhook error: \(error)")
        }
    }

    func createStreamGoLiveEmbed(streamTitle: String, gameName: String, viewerCount: Int? = nil) -> DiscordEmbed {
        let description = "🎮 Now playing: **\(gameName)**"

        var fields: [DiscordEmbedField] = [
            DiscordEmbedField(name: "Game", value: gameName, inline: true)
        ]

        if let count = viewerCount {
            fields.append(DiscordEmbedField(name: "Viewers", value: "\(count)", inline: true))
        }

        return DiscordEmbed(
            title: "🔴 LIVE: \(streamTitle)",
            description: description,
            color: 0x9146FF, // Twitch purple
            timestamp: ISO8601DateFormatter().string(from: Date()),
            thumbnail: DiscordEmbedThumbnail(url: "https://example.com/retro-gaming-icon.png"),
            footer: DiscordEmbedFooter(text: "Universal Emulator", icon_url: nil),
            fields: fields
        )
    }

    func postStreamUpdate(webhookURL: String, streamTitle: String, gameName: String, viewerCount: Int? = nil) async {
        let embed = createStreamGoLiveEmbed(streamTitle: streamTitle, gameName: gameName, viewerCount: viewerCount)
        await sendWebhookMessage(webhookURL: webhookURL, content: "", embeds: [embed])
    }
}

// MARK: - Data Models
struct DiscordTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let token_type: String
}

struct DiscordUser: Codable {
    let id: String
    let username: String
    let discriminator: String
    let avatar: String?
    let email: String?
    let verified: Bool?
}

struct DiscordGuild: Codable {
    let id: String
    let name: String
    let icon: String?
    let owner: Bool
    let permissions: String
}

struct DiscordEmbed: Codable {
    let title: String?
    let description: String?
    let color: Int?
    let timestamp: String?
    let url: String?
    let author: DiscordEmbedAuthor?
    let thumbnail: DiscordEmbedThumbnail?
    let image: DiscordEmbedImage?
    let footer: DiscordEmbedFooter?
    let fields: [DiscordEmbedField]

    init(title: String? = nil, description: String? = nil, color: Int? = nil,
         timestamp: String? = nil, url: String? = nil, author: DiscordEmbedAuthor? = nil,
         thumbnail: DiscordEmbedThumbnail? = nil, image: DiscordEmbedImage? = nil,
         footer: DiscordEmbedFooter? = nil, fields: [DiscordEmbedField] = []) {
        self.title = title
        self.description = description
        self.color = color
        self.timestamp = timestamp
        self.url = url
        self.author = author
        self.thumbnail = thumbnail
        self.image = image
        self.footer = footer
        self.fields = fields
    }
}

struct DiscordEmbedAuthor: Codable {
    let name: String
    let url: String?
    let icon_url: String?
}

struct DiscordEmbedThumbnail: Codable {
    let url: String
}

struct DiscordEmbedImage: Codable {
    let url: String
}

struct DiscordEmbedFooter: Codable {
    let text: String
    let icon_url: String?
}

struct DiscordEmbedField: Codable {
    let name: String
    let value: String
    let inline: Bool
}