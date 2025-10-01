/**
 * Authentication Service Backend
 *
 * Purpose: Secure password hashing and user authentication
 * Security: Uses Argon2id for password hashing (OWASP recommended)
 *
 * Setup:
 * 1. npm install express argon2 jsonwebtoken bcrypt dotenv
 * 2. Create .env file with JWT_SECRET
 * 3. node auth-service.js
 */

require('dotenv').config();
const express = require('express');
const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const app = express();

app.use(express.json());

// CORS configuration
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGIN || 'http://localhost');
    res.header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

// In-memory user store (replace with database in production)
const users = new Map();

// Argon2id configuration (OWASP recommended)
const argon2Config = {
    type: argon2.argon2id,
    memoryCost: 65536,      // 64 MB
    timeCost: 3,            // 3 iterations
    parallelism: 4          // 4 threads
};

/**
 * Register new user
 * POST /auth/register
 * Body: { email, password, username, deviceID }
 */
app.post('/auth/register', async (req, res) => {
    const { email, password, username, deviceID } = req.body;

    // Validation
    if (!email || !password || !username) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if user exists
    if (users.has(email)) {
        return res.status(409).json({ error: 'User already exists' });
    }

    try {
        // Hash password with Argon2id
        const passwordHash = await argon2.hash(password, argon2Config);

        // Create user object
        const user = {
            id: generateUserId(),
            email,
            username,
            passwordHash,
            deviceID,
            isEmailVerified: false,
            createdAt: new Date().toISOString(),
            subscription: 'free'
        };

        // Store user
        users.set(email, user);

        // Generate JWT tokens
        const accessToken = jwt.sign(
            { userId: user.id, email: user.email },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '1h' }
        );

        const refreshToken = jwt.sign(
            { userId: user.id },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '7d' }
        );

        res.status(201).json({
            userID: user.id,
            accessToken,
            refreshToken,
            createdAt: user.createdAt
        });

        console.log(`✅ User registered: ${username} (${email})`);
    } catch (error) {
        console.error('❌ Registration failed:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

/**
 * Sign in user
 * POST /auth/signin
 * Body: { email, password, deviceID }
 */
app.post('/auth/signin', async (req, res) => {
    const { email, password, deviceID } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Missing email or password' });
    }

    try {
        // Find user
        const user = users.get(email);
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Verify password with Argon2id
        const isValid = await argon2.verify(user.passwordHash, password);
        if (!isValid) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Update device ID
        user.deviceID = deviceID;

        // Generate JWT tokens
        const accessToken = jwt.sign(
            { userId: user.id, email: user.email },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '1h' }
        );

        const refreshToken = jwt.sign(
            { userId: user.id },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '7d' }
        );

        res.json({
            userID: user.id,
            accessToken,
            refreshToken
        });

        console.log(`✅ User signed in: ${user.username} (${email})`);
    } catch (error) {
        console.error('❌ Sign in failed:', error);
        res.status(500).json({ error: 'Sign in failed' });
    }
});

/**
 * Get current user
 * GET /auth/me
 * Headers: Authorization: Bearer <access_token>
 */
app.get('/auth/me', authenticateToken, (req, res) => {
    const user = Array.from(users.values()).find(u => u.id === req.userId);

    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }

    // Return user without password hash
    res.json({
        id: user.id,
        email: user.email,
        username: user.username,
        isEmailVerified: user.isEmailVerified,
        createdAt: user.createdAt,
        subscription: user.subscription
    });
});

/**
 * Refresh access token
 * POST /auth/refresh
 * Body: { refreshToken }
 */
app.post('/auth/refresh', (req, res) => {
    const { refreshToken } = req.body;

    if (!refreshToken) {
        return res.status(400).json({ error: 'Missing refresh token' });
    }

    try {
        const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET || 'change-me-in-production');

        const accessToken = jwt.sign(
            { userId: decoded.userId },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '1h' }
        );

        const newRefreshToken = jwt.sign(
            { userId: decoded.userId },
            process.env.JWT_SECRET || 'change-me-in-production',
            { expiresIn: '7d' }
        );

        res.json({ accessToken, refreshToken: newRefreshToken });
    } catch (error) {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

/**
 * Password reset request
 * POST /auth/reset-password
 * Body: { email }
 */
app.post('/auth/reset-password', async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ error: 'Missing email' });
    }

    const user = users.get(email);
    if (!user) {
        // Don't reveal if user exists (security best practice)
        return res.json({ message: 'If account exists, reset email sent' });
    }

    // TODO: Send password reset email
    console.log(`📧 Password reset requested for: ${email}`);

    res.json({ message: 'If account exists, reset email sent' });
});

/**
 * Email verification
 * POST /auth/verify-email
 * Headers: Authorization: Bearer <access_token>
 * Body: { code }
 */
app.post('/auth/verify-email', authenticateToken, (req, res) => {
    const { code } = req.body;

    // TODO: Verify code from database/cache
    // For now, accept any code for demo

    const user = Array.from(users.values()).find(u => u.id === req.userId);
    if (user) {
        user.isEmailVerified = true;
        console.log(`✅ Email verified for: ${user.email}`);
    }

    res.json({ message: 'Email verified successfully' });
});

// Authentication middleware
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Missing access token' });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'change-me-in-production');
        req.userId = decoded.userId;
        next();
    } catch (error) {
        return res.status(401).json({ error: 'Invalid access token' });
    }
}

// Helper functions
function generateUserId() {
    return `user_${Date.now()}_${Math.random().toString(36).substring(7)}`;
}

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'auth-service', users: users.size });
});

const PORT = process.env.AUTH_PORT || 3001;
app.listen(PORT, () => {
    console.log(`🔐 Authentication Service running on port ${PORT}`);
    console.log(`✅ Using Argon2id password hashing (OWASP recommended)`);
    console.log(`⚠️  Set JWT_SECRET in .env for production!`);
});

module.exports = app; // For testing