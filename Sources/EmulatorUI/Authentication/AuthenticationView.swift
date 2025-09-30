import SwiftUI
import EmulatorKit

/// Sprint 1 - AUTH-001: Authentication UI Implementation
/// SwiftUI interface for user authentication flows
public struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var oauthManager: OAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentFlow: AuthFlow = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var verificationCode = ""
    @State private var showingForgotPassword = false
    @State private var showingEmailVerification = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {
        let authManager = AuthenticationManager()
        _oauthManager = StateObject(wrappedValue: OAuthManager(authManager: authManager))
    }

    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.1),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.section) {
                    // Header
                    AuthenticationHeader()

                    // Main content
                    VStack(spacing: DesignSystem.Spacing.xxl) {
                        // Flow selector
                        AuthFlowSelector(currentFlow: $currentFlow)

                        // Content based on current flow
                        Group {
                            switch currentFlow {
                            case .signIn:
                                SignInForm(
                                    email: $email,
                                    password: $password,
                                    isLoading: $isLoading,
                                    onSignIn: performSignIn,
                                    onForgotPassword: { showingForgotPassword = true }
                                )

                            case .signUp:
                                SignUpForm(
                                    email: $email,
                                    password: $password,
                                    confirmPassword: $confirmPassword,
                                    username: $username,
                                    isLoading: $isLoading,
                                    onSignUp: performSignUp
                                )
                            }
                        }

                        // OAuth options
                        OAuthButtonsSection(
                            isLoading: $isLoading,
                            onAppleSignIn: performAppleSignIn,
                            onGoogleSignIn: performGoogleSignIn
                        )

                        // Error display
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.vertical, 40)
            }
        }
        .onReceive(authManager.$authState) { newState in
            handleAuthStateChange(newState)
        }
        .onReceive(authManager.$lastError) { error in
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordSheet(
                onSendReset: { email in
                    Task {
                        try await authManager.resetPassword(email: email)
                        showingForgotPassword = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingEmailVerification) {
            EmailVerificationSheet(
                email: email,
                onVerify: { code in
                    Task {
                        try await authManager.verifyEmail(code: code)
                        showingEmailVerification = false
                        dismiss()
                    }
                },
                onResend: {
                    Task {
                        try await authManager.sendEmailVerification()
                    }
                }
            )
        }
    }

    // MARK: - Authentication Actions

    private func performSignIn() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func performSignUp() {
        Task { @MainActor in
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match"
                return
            }

            isLoading = true
            errorMessage = nil

            do {
                try await authManager.registerUser(
                    email: email,
                    password: password,
                    username: username
                )
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func performAppleSignIn() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                try await oauthManager.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func performGoogleSignIn() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                try await oauthManager.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func handleAuthStateChange(_ newState: AuthState) {
        switch newState {
        case .authenticated:
            dismiss()
        case .authenticatedUnverified:
            showingEmailVerification = true
        default:
            break
        }
    }
}

// MARK: - Supporting Views

struct AuthenticationHeader: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Welcome to Nintendo Emulator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Join the creator community")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

enum AuthFlow: String, CaseIterable {
    case signIn = "Sign In"
    case signUp = "Sign Up"
}

struct AuthFlowSelector: View {
    @Binding var currentFlow: AuthFlow

    var body: some View {
        Picker("Authentication Flow", selection: $currentFlow) {
            ForEach(AuthFlow.allCases, id: \.self) { flow in
                Text(flow.rawValue).tag(flow)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

struct SignInForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isLoading: Bool
    let onSignIn: () -> Void
    let onForgotPassword: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Email field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                    .textContentType(.emailAddress)
#endif
                    #if !os(macOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .disabled(isLoading)
            }

            // Password field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .disabled(isLoading)
            }

            // Forgot password link
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    onForgotPassword()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }

            // Sign in button
            Button(action: onSignIn) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(isLoading ? "Signing In..." : "Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
    }
}

struct SignUpForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var username: String
    @Binding var isLoading: Bool
    let onSignUp: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Username field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Username")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Choose a username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .disabled(isLoading)
            }

            // Email field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                    .textContentType(.emailAddress)
#endif
                    #if !os(macOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .disabled(isLoading)
            }

            // Password field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Create a password", text: $password)
                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                    .textContentType(.newPassword)
#endif
                    .disabled(isLoading)
            }

            // Confirm password field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Confirm your password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                    .textContentType(.newPassword)
#endif
                    .disabled(isLoading)
            }

            // Password requirements
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Password must contain:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    RequirementIndicator(
                        text: "8+ characters",
                        isMet: password.count >= 8
                    )
                    RequirementIndicator(
                        text: "Uppercase",
                        isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil
                    )
                    RequirementIndicator(
                        text: "Number",
                        isMet: password.rangeOfCharacter(from: .decimalDigits) != nil
                    )
                }
                .font(.caption2)
            }

            // Sign up button
            Button(action: onSignUp) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(isLoading ? "Creating Account..." : "Create Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || !isFormValid)
        }
    }

    private var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8
    }
}

struct RequirementIndicator: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .secondary)
            Text(text)
                .foregroundColor(isMet ? .green : .secondary)
        }
    }
}

struct OAuthButtonsSection: View {
    @Binding var isLoading: Bool
    let onAppleSignIn: () -> Void
    let onGoogleSignIn: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Divider
            HStack {
                VStack { Divider() }
                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack { Divider() }
            }

            // OAuth buttons
            VStack(spacing: DesignSystem.Spacing.md) {
                // Apple Sign In
                Button(action: onAppleSignIn) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        Text("Continue with Apple")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isLoading)

                // Google Sign In
                Button(action: onGoogleSignIn) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Google logo placeholder
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("G")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        Text("Continue with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isLoading)
            }
        }
    }
}

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Sheet Views

struct ForgotPasswordSheet: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var isEmailSent = false
    @Environment(\.dismiss) private var dismiss

    let onSendReset: (String) async -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                if isEmailSent {
                    // Success state
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Reset Email Sent")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Check your email for reset instructions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    // Input state
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text("Enter your email address and we'll send you instructions to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                TextField("Email address", text: $email)
                    .textFieldStyle(.roundedBorder)
#if !os(macOS)
                    .textContentType(.emailAddress)
#endif

                        Button(action: sendResetEmail) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Sending..." : "Send Reset Email")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || email.isEmpty)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reset Password")
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

    private func sendResetEmail() {
        Task { @MainActor in
            isLoading = true
            await onSendReset(email)
            isLoading = false
            isEmailSent = true
        }
    }
}

struct EmailVerificationSheet: View {
    let email: String
    @State private var verificationCode = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    let onVerify: (String) async -> Void
    let onResend: () async -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.section) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Check Your Email")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("We sent a verification code to:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(spacing: DesignSystem.Spacing.lg) {
                    TextField("Enter verification code", text: $verificationCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.monospacedDigit())
                        .multilineTextAlignment(.center)

                    Button(action: verifyEmail) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Verifying..." : "Verify Email")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || verificationCode.isEmpty)

                    Button("Resend Code") {
                        Task {
                            await onResend()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Verify Email")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func verifyEmail() {
        Task { @MainActor in
            isLoading = true
            await onVerify(verificationCode)
            isLoading = false
        }
    }
}

#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
#endif
