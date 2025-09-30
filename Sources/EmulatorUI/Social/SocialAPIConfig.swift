import Foundation

/// Configuration for all social platform APIs
/// Replace these placeholder values with your actual API credentials
struct SocialAPIConfig {

    // MARK: - Twitch Configuration
    struct Twitch {
        static let clientId = "your_twitch_client_id_here"
        static let clientSecret = "your_twitch_client_secret_here"
        static let redirectURI = "universalemulator://twitch/callback"

        // Get these from: https://dev.twitch.tv/console/apps
        // Instructions:
        // 1. Create a new application
        // 2. Set OAuth Redirect URL to: universalemulator://twitch/callback
        // 3. Copy Client ID and generate Client Secret
    }

    // MARK: - YouTube Configuration
    struct YouTube {
        static let clientId = "your_youtube_client_id.googleusercontent.com"
        static let clientSecret = "your_youtube_client_secret_here"
        static let redirectURI = "universalemulator://youtube/callback"

        // Get these from: https://console.developers.google.com/
        // Instructions:
        // 1. Create new project or select existing
        // 2. Enable YouTube Data API v3
        // 3. Create OAuth 2.0 credentials
        // 4. Add redirect URI: universalemulator://youtube/callback
    }

    // MARK: - Discord Configuration
    struct Discord {
        static let clientId = "your_discord_client_id_here"
        static let clientSecret = "your_discord_client_secret_here"
        static let redirectURI = "universalemulator://discord/callback"

        // Get these from: https://discord.com/developers/applications
        // Instructions:
        // 1. Create New Application
        // 2. Go to OAuth2 section
        // 3. Add redirect: universalemulator://discord/callback
        // 4. Copy Client ID and Client Secret
    }

    // MARK: - Twitter Configuration
    struct Twitter {
        static let clientId = "your_twitter_client_id_here"
        static let clientSecret = "your_twitter_client_secret_here"
        static let redirectURI = "universalemulator://twitter/callback"

        // Get these from: https://developer.twitter.com/en/portal/dashboard
        // Instructions:
        // 1. Create new App in Twitter Developer Portal
        // 2. Enable OAuth 2.0 in App settings
        // 3. Add callback URL: universalemulator://twitter/callback
        // 4. Copy Client ID and Client Secret
    }

    // MARK: - Instagram Configuration
    struct Instagram {
        static let clientId = "your_instagram_client_id_here"
        static let clientSecret = "your_instagram_client_secret_here"
        static let redirectURI = "universalemulator://instagram/callback"

        // Get these from: https://developers.facebook.com/apps/
        // Instructions:
        // 1. Create new Facebook App
        // 2. Add Instagram Basic Display product
        // 3. Configure OAuth redirect: universalemulator://instagram/callback
        // 4. Copy App ID and App Secret
    }

    // MARK: - TikTok Configuration
    struct TikTok {
        static let clientKey = "your_tiktok_client_key_here"
        static let clientSecret = "your_tiktok_client_secret_here"
        static let redirectURI = "universalemulator://tiktok/callback"

        // Get these from: https://developers.tiktok.com/apps/
        // Instructions:
        // 1. Apply for TikTok for Developers
        // 2. Create new app
        // 3. Add redirect URL: universalemulator://tiktok/callback
        // 4. Copy Client Key and Client Secret
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

 🚀 QUICK SETUP GUIDE FOR CONTENT CREATORS:

 1. **Twitch** (Essential for streaming):
    - Visit: https://dev.twitch.tv/console/apps
    - Create app, set redirect to: universalemulator://twitch/callback
    - Replace Twitch.clientId and Twitch.clientSecret above

 2. **YouTube** (For video uploads & live streaming):
    - Visit: https://console.developers.google.com/
    - Enable YouTube Data API v3
    - Create OAuth credentials with redirect: universalemulator://youtube/callback
    - Replace YouTube.clientId and YouTube.clientSecret above

 3. **Discord** (For community engagement):
    - Visit: https://discord.com/developers/applications
    - Create app, add redirect: universalemulator://discord/callback
    - Replace Discord.clientId and Discord.clientSecret above

 4. **Twitter** (For social media updates):
    - Visit: https://developer.twitter.com/en/portal/dashboard
    - Create app with OAuth 2.0, redirect: universalemulator://twitter/callback
    - Replace Twitter.clientId and Twitter.clientSecret above

 5. **Instagram** (For highlights & story updates):
    - Visit: https://developers.facebook.com/apps/
    - Create Facebook app with Instagram Basic Display
    - Add redirect: universalemulator://instagram/callback
    - Replace Instagram.clientId and Instagram.clientSecret above

 6. **TikTok** (For short-form content):
    - Visit: https://developers.tiktok.com/apps/
    - Apply for developer access, create app
    - Add redirect: universalemulator://tiktok/callback
    - Replace TikTok.clientKey and TikTok.clientSecret above

 ⚡ PRIORITY FOR RETRO STREAMERS:
 1. Twitch (essential)
 2. Twitter (quick updates)
 3. Discord (community)
 4. YouTube (VODs & highlights)
 5. Instagram (visual content)
 6. TikTok (viral clips)

 */