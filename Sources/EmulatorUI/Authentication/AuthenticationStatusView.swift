import SwiftUI
import EmulatorKit

/// Sprint 1 - AUTH Integration: Authentication Status Component
/// Shows current authentication state in the main navigation
struct AuthenticationStatusView: View {
    @ObservedObject var authManager: AuthenticationManager
    let onSignIn: () -> Void

    @State private var showingUserMenu = false
    @State private var showingProfile = false

    var body: some View {
        Group {
            switch authManager.authState {
            case .unauthenticated:
                // Sign in button for unauthenticated users
                Button(action: onSignIn) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                        Text("Sign In")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .loading:
                // Loading state
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .authenticatedUnverified:
                // Unverified user - show verification prompt
                Button(action: { showingProfile = true }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "envelope.badge")
                            .font(.title3)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Verify Email")
                                .font(.caption2)
                                .fontWeight(.medium)
                            if let user = authManager.currentUser {
                                Text(user.username)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .authenticated:
                // Authenticated user menu
                if let user = authManager.currentUser {
                    Menu {
                        UserMenuContent(
                            user: user,
                            onProfile: { showingProfile = true },
                            onSettings: {},
                            onSignOut: {
                                Task {
                                    await authManager.signOut()
                                }
                            }
                        )
                    } label: {
                        AuthenticatedUserButton(user: user)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .sheet(isPresented: $showingProfile) {
            if let user = authManager.currentUser {
                UserProfileSheet(user: user, authManager: authManager)
            }
        }
    }
}

struct AuthenticatedUserButton: View {
    let user: User

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Avatar or initials
            Group {
                if let avatarURL = user.profile?.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        UserInitialsView(username: user.username)
                    }
                } else {
                    UserInitialsView(username: user.username)
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())

            // User info
            VStack(alignment: .leading, spacing: 0) {
                Text(user.profile?.displayName ?? user.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Subscription tier indicator
                    Circle()
                        .fill(user.subscription.color)
                        .frame(width: 6, height: 6)

                    Text(user.subscription.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Dropdown indicator
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.md)
    }
}

struct UserInitialsView: View {
    let username: String

    private var initials: String {
        let components = username.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let letters = components.compactMap { $0.first }
        return String(letters.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(Color.accentColor)
            .clipShape(Circle())
    }
}

struct UserMenuContent: View {
    let user: User
    let onProfile: () -> Void
    let onSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // User header
            VStack(spacing: DesignSystem.Spacing.sm) {
                UserInitialsView(username: user.username)
                    .frame(width: 32, height: 32)

                VStack(spacing: 2) {
                    Text(user.profile?.displayName ?? user.username)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(user.subscription.color)
                            .frame(width: 6, height: 6)
                        Text(user.subscription.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.vertical, 12)

            Divider()

            // Menu items
            Button("Profile", action: onProfile)
            Button("Settings", action: onSettings)

            Divider()

            Button("Sign Out", action: onSignOut)
                .foregroundColor(.red)
        }
    }
}

struct UserProfileSheet: View {
    let user: User
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // Profile header
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        UserInitialsView(username: user.username)
                            .frame(width: 80, height: 80)

                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text(user.profile?.displayName ?? user.username)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            // Email verification status
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: user.isEmailVerified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(user.isEmailVerified ? .green : .orange)
                                Text(user.isEmailVerified ? "Email Verified" : "Email Not Verified")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(user.isEmailVerified ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .cornerRadius(DesignSystem.Radius.md)
                        }
                    }

                    // Subscription info
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Subscription")
                            .font(.headline)
                            .fontWeight(.semibold)

                        HStack {
                            Circle()
                                .fill(user.subscription.color)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.subscription.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if user.subscription != .free {
                                    let price = NSDecimalNumber(decimal: user.subscription.monthlyPrice).doubleValue
                                    Text("$" + String(format: "%.2f", price) + "/month")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if user.subscription == .free {
                                Button("Upgrade") {
                                    // TODO: Implement subscription upgrade
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(DesignSystem.Radius.lg)
                    }

                    // Quick actions
                    if !user.isEmailVerified {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Action Required")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Button("Verify Email Address") {
                                Task {
                                    try? await authManager.sendEmailVerification()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subscription Tier Extensions

extension SubscriptionTier {
    var color: Color {
        switch self {
        case .free:
            return .gray
        case .basic:
            return .blue
        case .pro:
            return .purple
        case .creator:
            return .orange
        }
    }
}

#if DEBUG
struct AuthenticationStatusView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            AuthenticationStatusView(
                authManager: AuthenticationManager(),
                onSignIn: {}
            )
        }
        .padding()
    }
}
#endif
