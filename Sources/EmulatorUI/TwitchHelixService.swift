import Foundation

enum TwitchHelixService {
    static func fetchViewerCount(channel: String, clientID: String, oauthToken: String) async -> Int? {
        guard let url = URL(string: "https://api.twitch.tv/helix/streams?user_login=\(channel)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientID, forHTTPHeaderField: "Client-ID")
        let token = oauthToken.hasPrefix("Bearer ") ? oauthToken : "Bearer \(oauthToken)"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]],
               let first = dataArr.first,
               let count = first["viewer_count"] as? Int {
                return count
            }
        } catch {
            print("Twitch Helix viewer count error: \(error)")
        }
        return nil
    }
}

