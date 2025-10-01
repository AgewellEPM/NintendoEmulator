import Foundation

/// Configuration for all social platform APIs
/// 🔒 SECURITY: Client IDs loaded from environment variables
/// ⚠️ IMPORTANT: Client secrets MUST NEVER be stored in the app
///              Use a backend OAuth proxy for token exchange
struct SocialAPIConfig {

    // MARK: - Twitch Configuration
    struct Twitch {
        static let clientId = ProcessInfo.processInfo.environment["TWITCH_CLIENT_ID"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://twitch/callback"

        // Get these from: https://dev.twitch.tv/console/apps
        // Instructions:
        // 1. Create a new application
        // 2. Set OAuth Redirect URL to: universalemulator://twitch/callback
        // 3. Set environment variable: export TWITCH_CLIENT_ID="your_client_id"
        // 4. NEVER hardcode client secrets - use backend proxy for token exchange
    }

    // MARK: - YouTube Configuration
    struct YouTube {
        static let clientId = ProcessInfo.processInfo.environment["YOUTUBE_CLIENT_ID"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://youtube/callback"

        // Get these from: https://console.developers.google.com/
        // Instructions:
        // 1. Create new project or select existing
        // 2. Enable YouTube Data API v3
        // 3. Create OAuth 2.0 credentials
        // 4. Set environment variable: export YOUTUBE_CLIENT_ID="your_client_id"
        // 5. Add redirect URI: universalemulator://youtube/callback
    }

    // MARK: - Discord Configuration
    struct Discord {
        static let clientId = ProcessInfo.processInfo.environment["DISCORD_CLIENT_ID"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://discord/callback"

        // Get these from: https://discord.com/developers/applications
        // Instructions:
        // 1. Create New Application
        // 2. Go to OAuth2 section
        // 3. Set environment variable: export DISCORD_CLIENT_ID="your_client_id"
        // 4. Add redirect: universalemulator://discord/callback
    }

    // MARK: - Twitter Configuration
    struct Twitter {
        static let clientId = ProcessInfo.processInfo.environment["TWITTER_CLIENT_ID"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://twitter/callback"

        // Get these from: https://developer.twitter.com/en/portal/dashboard
        // Instructions:
        // 1. Create new App in Twitter Developer Portal
        // 2. Enable OAuth 2.0 in App settings
        // 3. Set environment variable: export TWITTER_CLIENT_ID="your_client_id"
        // 4. Add callback URL: universalemulator://twitter/callback
    }

    // MARK: - Instagram Configuration
    struct Instagram {
        static let clientId = ProcessInfo.processInfo.environment["INSTAGRAM_CLIENT_ID"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://instagram/callback"

        // Get these from: https://developers.facebook.com/apps/
        // Instructions:
        // 1. Create new Facebook App
        // 2. Add Instagram Basic Display product
        // 3. Set environment variable: export INSTAGRAM_CLIENT_ID="your_app_id"
        // 4. Configure OAuth redirect: universalemulator://instagram/callback
    }

    // MARK: - TikTok Configuration
    struct TikTok {
        static let clientKey = ProcessInfo.processInfo.environment["TIKTOK_CLIENT_KEY"] ?? ""
        // ⚠️ REMOVED: Client secrets must be handled by backend OAuth proxy
        static let redirectURI = "universalemulator://tiktok/callback"

        // Get these from: https://developers.tiktok.com/apps/
        // Instructions:
        // 1. Apply for TikTok for Developers
        // 2. Create new app
        // 3. Set environment variable: export TIKTOK_CLIENT_KEY="your_client_key"
        // 4. Add redirect URL: universalemulator://tiktok/callback
    }

    // MARK: - Security Settings
    struct Security {
        // Only allow HTTPS OAuth URLs from these trusted domains
        static let allowedOAuthDomains = [
            "id.twitch.tv",
            "www.twitch.tv",
            "accounts.google.com",
            "discord.com",
            "twitter.com",
            "api.instagram.com",
            "www.tiktok.com"
        ]

        // Enable/disable OAuth state parameter validation (recommended: true)
        static let enableCSRFProtection = true

        // Enable/disable PKCE for enhanced OAuth security (recommended: true)
        static let enablePKCE = true
    }
}

// MARK: - Quick Setup Instructions
/*

 🚀 SECURE SETUP GUIDE FOR CONTENT CREATORS:

 🔒 SECURITY NOTICE:
 - Client IDs are public and can be stored in environment variables
 - Client SECRETS must NEVER be stored in the app or source code
 - Use a backend OAuth proxy for secure token exchange

 📝 SETUP STEPS:

 1. **Twitch** (Essential for streaming):
    - Visit: https://dev.twitch.tv/console/apps
    - Create app, set redirect to: universalemulator://twitch/callback
    - Set environment: export TWITCH_CLIENT_ID="your_client_id"
    - Store client secret ONLY on your backend server

 2. **YouTube** (For video uploads & live streaming):
    - Visit: https://console.developers.google.com/
    - Enable YouTube Data API v3
    - Create OAuth credentials with redirect: universalemulator://youtube/callback
    - Set environment: export YOUTUBE_CLIENT_ID="your_client_id"

 3. **Discord** (For community engagement):
    - Visit: https://discord.com/developers/applications
    - Create app, add redirect: universalemulator://discord/callback
    - Set environment: export DISCORD_CLIENT_ID="your_client_id"

 4. **Twitter** (For social media updates):
    - Visit: https://developer.twitter.com/en/portal/dashboard
    - Create app with OAuth 2.0, redirect: universalemulator://twitter/callback
    - Set environment: export TWITTER_CLIENT_ID="your_client_id"

 5. **Instagram** (For highlights & story updates):
    - Visit: https://developers.facebook.com/apps/
    - Create Facebook app with Instagram Basic Display
    - Add redirect: universalemulator://instagram/callback
    - Set environment: export INSTAGRAM_CLIENT_ID="your_app_id"

 6. **TikTok** (For short-form content):
    - Visit: https://developers.tiktok.com/apps/
    - Apply for developer access, create app
    - Add redirect: universalemulator://tiktok/callback
    - Set environment: export TIKTOK_CLIENT_KEY="your_client_key"

 ⚡ PRIORITY FOR RETRO STREAMERS:
 1. Twitch (essential)
 2. Twitter (quick updates)
 3. Discord (community)
 4. YouTube (VODs & highlights)
 5. Instagram (visual content)
 6. TikTok (viral clips)

 🔐 BACKEND OAUTH PROXY SETUP:
 The app now requires a backend service to handle OAuth token exchange.
 See: NintendoEmulator/SECURITY_ASSESSMENT_REPORT.md Section 1.1

 */