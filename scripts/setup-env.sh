#!/bin/bash

# Environment Variable Setup Script
# Sets up OAuth client IDs for the Nintendo Emulator app

set -e

echo "🔧 Nintendo Emulator - Environment Setup"
echo "========================================"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  This script is designed for macOS"
    exit 1
fi

# Function to prompt for value
prompt_for_value() {
    local var_name=$1
    local description=$2
    local current_value="${!var_name}"

    if [ -n "$current_value" ]; then
        echo "✅ $var_name is already set"
        return
    fi

    echo ""
    echo "📝 $description"
    read -p "Enter $var_name (or press Enter to skip): " value

    if [ -n "$value" ]; then
        export "$var_name"="$value"
        echo "export $var_name=\"$value\"" >> ~/.zshrc
        echo "✅ Set $var_name"
    else
        echo "⏭️  Skipped $var_name"
    fi
}

echo "Setting up OAuth Client IDs..."
echo "(Client SECRETS should ONLY be in backend .env file)"
echo ""

# Twitch
prompt_for_value "TWITCH_CLIENT_ID" "Twitch Client ID from https://dev.twitch.tv/console/apps"

# YouTube
prompt_for_value "YOUTUBE_CLIENT_ID" "YouTube Client ID from https://console.developers.google.com/"

# Discord
prompt_for_value "DISCORD_CLIENT_ID" "Discord Client ID from https://discord.com/developers/applications"

# Twitter
prompt_for_value "TWITTER_CLIENT_ID" "Twitter Client ID from https://developer.twitter.com/en/portal/dashboard"

# Instagram
prompt_for_value "INSTAGRAM_CLIENT_ID" "Instagram Client ID from https://developers.facebook.com/apps/"

# TikTok
prompt_for_value "TIKTOK_CLIENT_KEY" "TikTok Client Key from https://developers.tiktok.com/apps/"

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Set up backend OAuth proxy with client secrets"
echo "3. See backend/.env.example for backend configuration"
echo ""
echo "🔒 Security reminder:"
echo "- Client IDs are PUBLIC (safe in environment variables)"
echo "- Client SECRETS must ONLY be on backend server"
echo "- NEVER commit secrets to version control"
echo ""