/**
 * OAuth Proxy Backend Server
 *
 * Purpose: Securely handle OAuth token exchange for social platforms
 * Security: Client secrets stored ONLY on server, never sent to client
 *
 * Setup:
 * 1. npm install express axios dotenv
 * 2. Create .env file with secrets (see .env.example)
 * 3. node oauth-proxy.js
 */

require('dotenv').config();
const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// CORS configuration (adjust for production)
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGIN || 'http://localhost');
    res.header('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'oauth-proxy' });
});

// Twitch OAuth token exchange
app.post('/oauth/twitch/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;

    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }

    try {
        const response = await axios.post('https://id.twitch.tv/oauth2/token', {
            client_id: process.env.TWITCH_CLIENT_ID,
            client_secret: process.env.TWITCH_CLIENT_SECRET,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri
        });

        // Return only access_token, refresh_token, expires_in
        // NEVER return client_secret to client
        res.json({
            access_token: response.data.access_token,
            refresh_token: response.data.refresh_token,
            expires_in: response.data.expires_in,
            token_type: response.data.token_type
        });

        console.log(`✅ Twitch token exchanged successfully`);
    } catch (error) {
        console.error('❌ Twitch token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// YouTube OAuth token exchange
app.post('/oauth/youtube/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;

    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }

    try {
        const response = await axios.post('https://oauth2.googleapis.com/token', {
            client_id: process.env.YOUTUBE_CLIENT_ID,
            client_secret: process.env.YOUTUBE_CLIENT_SECRET,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri
        });

        res.json({
            access_token: response.data.access_token,
            refresh_token: response.data.refresh_token,
            expires_in: response.data.expires_in,
            token_type: response.data.token_type,
            scope: response.data.scope
        });

        console.log(`✅ YouTube token exchanged successfully`);
    } catch (error) {
        console.error('❌ YouTube token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// Discord OAuth token exchange
app.post('/oauth/discord/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;

    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }

    try {
        const params = new URLSearchParams({
            client_id: process.env.DISCORD_CLIENT_ID,
            client_secret: process.env.DISCORD_CLIENT_SECRET,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri
        });

        const response = await axios.post('https://discord.com/api/oauth2/token', params, {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });

        res.json({
            access_token: response.data.access_token,
            refresh_token: response.data.refresh_token,
            expires_in: response.data.expires_in,
            token_type: response.data.token_type
        });

        console.log(`✅ Discord token exchanged successfully`);
    } catch (error) {
        console.error('❌ Discord token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// Twitter OAuth token exchange
app.post('/oauth/twitter/exchange', async (req, res) => {
    const { code, redirect_uri, code_verifier } = req.body;

    if (!code || !redirect_uri || !code_verifier) {
        return res.status(400).json({ error: 'Missing required parameters' });
    }

    try {
        const params = new URLSearchParams({
            client_id: process.env.TWITTER_CLIENT_ID,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri,
            code_verifier: code_verifier
        });

        // Twitter uses Basic auth with client_id:client_secret
        const auth = Buffer.from(`${process.env.TWITTER_CLIENT_ID}:${process.env.TWITTER_CLIENT_SECRET}`).toString('base64');

        const response = await axios.post('https://api.twitter.com/2/oauth2/token', params, {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${auth}`
            }
        });

        res.json({
            access_token: response.data.access_token,
            refresh_token: response.data.refresh_token,
            expires_in: response.data.expires_in,
            token_type: response.data.token_type
        });

        console.log(`✅ Twitter token exchanged successfully`);
    } catch (error) {
        console.error('❌ Twitter token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// Instagram OAuth token exchange
app.post('/oauth/instagram/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;

    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }

    try {
        const params = new URLSearchParams({
            client_id: process.env.INSTAGRAM_CLIENT_ID,
            client_secret: process.env.INSTAGRAM_CLIENT_SECRET,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri
        });

        const response = await axios.post('https://api.instagram.com/oauth/access_token', params, {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });

        res.json({
            access_token: response.data.access_token,
            user_id: response.data.user_id
        });

        console.log(`✅ Instagram token exchanged successfully`);
    } catch (error) {
        console.error('❌ Instagram token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// TikTok OAuth token exchange
app.post('/oauth/tiktok/exchange', async (req, res) => {
    const { code, redirect_uri } = req.body;

    if (!code || !redirect_uri) {
        return res.status(400).json({ error: 'Missing code or redirect_uri' });
    }

    try {
        const response = await axios.post('https://open-api.tiktok.com/oauth/access_token/', {
            client_key: process.env.TIKTOK_CLIENT_KEY,
            client_secret: process.env.TIKTOK_CLIENT_SECRET,
            code: code,
            grant_type: 'authorization_code',
            redirect_uri: redirect_uri
        });

        res.json({
            access_token: response.data.data.access_token,
            refresh_token: response.data.data.refresh_token,
            expires_in: response.data.data.expires_in,
            open_id: response.data.data.open_id
        });

        console.log(`✅ TikTok token exchanged successfully`);
    } catch (error) {
        console.error('❌ TikTok token exchange failed:', error.response?.data || error.message);
        res.status(400).json({ error: 'Token exchange failed' });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🔒 OAuth Proxy Server running on port ${PORT}`);
    console.log(`✅ Configured platforms: Twitch, YouTube, Discord, Twitter, Instagram, TikTok`);
    console.log(`⚠️  Make sure all client secrets are set in .env file`);
});

module.exports = app; // For testing