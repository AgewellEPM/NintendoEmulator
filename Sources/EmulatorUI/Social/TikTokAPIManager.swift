import Foundation
import Combine
import EmulatorKit

class TikTokAPIManager: ObservableObject {
    private let clientKey = SocialAPIConfig.TikTok.clientKey
    // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
    private let redirectURI = SocialAPIConfig.TikTok.redirectURI
    private let baseURL = "https://open-api.tiktok.com"

    @Published var isConnected = false
    @Published var userInfo: TikTokUser?
    @Published var videos: [TikTokVideo] = []

    func authenticate() -> URL? {
        let scopes = [
            "user.info.basic",
            "video.list",
            "video.upload"
        ].joined(separator: ",")

        let csrfState = UUID().uuidString
        UserDefaults.standard.set(csrfState, forKey: "tiktok_csrf_state")

        let authURL = "https://www.tiktok.com/auth/authorize/?" +
            "client_key=\(clientKey)&" +
            "scope=\(scopes)&" +
            "response_type=code&" +
            "redirect_uri=\(redirectURI)&" +
            "state=\(csrfState)"

        return URL(string: authURL)
    }

    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            return
        }

        // Verify CSRF state
        let storedState = UserDefaults.standard.string(forKey: "tiktok_csrf_state")
        guard state == storedState else {
            print("TikTok CSRF state mismatch")
            return
        }

        UserDefaults.standard.removeObject(forKey: "tiktok_csrf_state")
        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        let tokenURL = "\(baseURL)/oauth/access_token/"

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // ⚠️ This will fail without client secret - backend proxy required
        let bodyString = "client_key=\(clientKey)&" +
            "code=\(code)&" +
            "grant_type=authorization_code&" +
            "redirect_uri=\(redirectURI)"

        request.httpBody = bodyString.data(using: String.Encoding.utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TikTokTokenResponse.self, from: data)

            if tokenResponse.data.error_code == 0 {
                // Store tokens securely
                KeychainManager.shared.storeToken(tokenResponse.data.access_token, for: "tiktok_access_token")
                KeychainManager.shared.storeToken(tokenResponse.data.refresh_token, for: "tiktok_refresh_token")

                await MainActor.run {
                    isConnected = true
                }

                await getUserInfo()
            } else {
                print("TikTok token error: \(tokenResponse.data.description)")
            }

        } catch {
            print("TikTok token exchange error: \(error)")
        }
    }

    func getUserInfo() async {
        guard let token = KeychainManager.shared.getToken(for: "tiktok_access_token") else { return }

        let url = "\(baseURL)/user/info/?fields=open_id,union_id,avatar_url,display_name,follower_count,following_count,likes_count"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TikTokUserResponse.self, from: data)

            if response.data.error_code == 0 {
                await MainActor.run {
                    userInfo = response.data.user
                }
            } else {
                print("TikTok user info error: \(response.data.description)")
            }
        } catch {
            print("TikTok user info request error: \(error)")
        }
    }

    func getUserVideos() async {
        guard let token = KeychainManager.shared.getToken(for: "tiktok_access_token") else { return }

        let url = "\(baseURL)/video/list/?fields=id,title,video_description,duration,cover_image_url,play_url,embed_link"
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TikTokVideosResponse.self, from: data)

            if response.data.error_code == 0 {
                await MainActor.run {
                    videos = response.data.videos
                }
            } else {
                print("TikTok videos error: \(response.data.description)")
            }
        } catch {
            print("TikTok videos request error: \(error)")
        }
    }

    // Note: TikTok video upload requires a more complex process with file uploads
    // This is a simplified version showing the API structure
    func uploadVideo(videoData: Data, title: String, description: String) async -> String? {
        guard KeychainManager.shared.getToken(for: "tiktok_access_token") != nil else { return nil }

        // Step 1: Get upload URL
        guard let uploadURL = await getUploadURL(videoSize: videoData.count) else {
            return nil
        }

        // Step 2: Upload video file (simplified)
        let success = await uploadVideoFile(videoData: videoData, uploadURL: uploadURL)
        guard success else { return nil }

        // Step 3: Publish video
        return await publishVideo(title: title, description: description)
    }

    private func getUploadURL(videoSize: Int) async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "tiktok_access_token") else { return nil }

        let uploadData: [String: Any] = [
            "source_info": [
                "source": "FILE_UPLOAD",
                "video_size": videoSize
            ]
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: uploadData)

        let url = "\(baseURL)/share/video/upload/"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TikTokUploadURLResponse.self, from: data)

            if response.data.error_code == 0 {
                return response.data.upload_url
            } else {
                print("TikTok upload URL error: \(response.data.description)")
                return nil
            }
        } catch {
            print("TikTok upload URL request error: \(error)")
            return nil
        }
    }

    private func uploadVideoFile(videoData: Data, uploadURL: String) async -> Bool {
        guard let url = URL(string: uploadURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = videoData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("TikTok video upload error: \(error)")
            return false
        }
    }

    private func publishVideo(title: String, description: String) async -> String? {
        guard let token = KeychainManager.shared.getToken(for: "tiktok_access_token") else { return nil }

        let publishData: [String: Any] = [
            "post_info": [
                "title": title,
                "description": description,
                "privacy_level": "SELF_ONLY", // or "PUBLIC_TO_EVERYONE"
                "disable_duet": false,
                "disable_comment": false,
                "disable_stitch": false,
                "video_cover_timestamp_ms": 1000
            ],
            "source_info": [
                "source": "FILE_UPLOAD"
            ]
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: publishData)

        let url = "\(baseURL)/share/video/upload/"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TikTokPublishResponse.self, from: data)

            if response.data.error_code == 0 {
                print("✅ TikTok video published: \(response.data.share_id)")
                return response.data.share_id
            } else {
                print("TikTok publish error: \(response.data.description)")
                return nil
            }
        } catch {
            print("TikTok publish request error: \(error)")
            return nil
        }
    }

    // Helper method for posting retro gaming clips
    func shareRetroGameplayClip(videoData: Data, gameName: String, description: String) async -> String? {
        let title = "🎮 \(gameName) Gameplay"
        let fullDescription = "\(description)\n\n#RetroGaming #\(gameName.replacingOccurrences(of: " ", with: "")) #Gaming #Nostalgia #GameClip #Retro"

        return await uploadVideo(videoData: videoData, title: title, description: fullDescription)
    }
}

// MARK: - Data Models
struct TikTokTokenResponse: Codable {
    let data: TikTokTokenData
    let message: String
}

struct TikTokTokenData: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String
    let refresh_expires_in: Int
    let token_type: String
    let scope: String
    let error_code: Int
    let description: String
}

struct TikTokUserResponse: Codable {
    let data: TikTokUserData
    let message: String
}

struct TikTokUserData: Codable {
    let user: TikTokUser
    let error_code: Int
    let description: String
}

struct TikTokUser: Codable {
    let open_id: String
    let union_id: String
    let avatar_url: String?
    let display_name: String
    let follower_count: Int?
    let following_count: Int?
    let likes_count: Int?
}

struct TikTokVideosResponse: Codable {
    let data: TikTokVideosData
    let message: String
}

struct TikTokVideosData: Codable {
    let videos: [TikTokVideo]
    let cursor: String?
    let has_more: Bool
    let error_code: Int
    let description: String
}

struct TikTokVideo: Codable {
    let id: String
    let title: String?
    let video_description: String
    let duration: Int
    let cover_image_url: String?
    let play_url: String?
    let embed_link: String?
}

struct TikTokUploadURLResponse: Codable {
    let data: TikTokUploadURLData
    let message: String
}

struct TikTokUploadURLData: Codable {
    let upload_url: String
    let error_code: Int
    let description: String
}

struct TikTokPublishResponse: Codable {
    let data: TikTokPublishData
    let message: String
}

struct TikTokPublishData: Codable {
    let share_id: String
    let error_code: Int
    let description: String
}