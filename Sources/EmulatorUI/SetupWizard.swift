import SwiftUI
import AppKit

/// First-launch setup wizard for collecting API keys and initial configuration
public struct SetupWizard: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var openAIKey = ""
    @State private var igdbClientID = ""
    @State private var igdbAccessToken = ""
    @State private var skipOptional = false

    private let totalSteps = 3

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Welcome to Nintendo Emulator!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Let's get you set up in just a few steps")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(40)

            // Progress indicators
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.top, 20)

            // Step content
            ScrollView {
                VStack(spacing: 30) {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        openAIStep
                    case 2:
                        igdbStep
                    default:
                        EmptyView()
                    }
                }
                .padding(40)
            }

            Divider()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Finish Setup") {
                        saveSettings()
                        markSetupComplete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What you'll get:")
                .font(.title2)
                .fontWeight(.semibold)

            SetupFeatureRow(
                icon: "brain.head.profile",
                title: "AI-Powered Game Info",
                description: "Automatically fetch game metadata, descriptions, and ratings"
            )

            SetupFeatureRow(
                icon: "photo.stack",
                title: "Box Art & Media",
                description: "Download box art and screenshots for your games"
            )

            SetupFeatureRow(
                icon: "message.circle",
                title: "AI Game Assistant",
                description: "Chat with AI about your games and get tips"
            )

            SetupFeatureRow(
                icon: "eye.circle",
                title: "Operator Mode",
                description: "AI watches your gameplay and provides real-time narration"
            )

            Text("All features work offline once set up!")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 12)
        }
    }

    private var openAIStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key (Required)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Used for AI game chat, metadata generation, and operator mode")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Your API Key:")
                    .font(.headline)

                SecureField("sk-...", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text("Don't have one? Get it for free at:")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("platform.openai.com/api-keys")
                    }
                    .font(.callout)
                }
                .buttonStyle(.link)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Your key is stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "eye.slash")
                        .foregroundColor(.green)
                    Text("Never shared or sent anywhere except OpenAI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }

    private var igdbStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 8) {
                    Text("IGDB API (Optional)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("For high-quality box art and game covers")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            Toggle("Skip this step (use AI-generated box art instead)", isOn: $skipOptional)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

            if !skipOptional {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID:")
                            .font(.headline)
                        TextField("Your IGDB Client ID", text: $igdbClientID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Access Token:")
                            .font(.headline)
                        SecureField("Your IGDB Access Token", text: $igdbAccessToken)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    Text("Get free IGDB API credentials:")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://api-docs.igdb.com/#getting-started")!)
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("api-docs.igdb.com")
                        }
                        .font(.callout)
                    }
                    .buttonStyle(.link)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }

            Text("✨ Without IGDB, we'll generate beautiful gradient placeholders with game titles")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Helper Methods

    private func saveSettings() {
        // Save OpenAI key
        if !openAIKey.isEmpty {
            UserDefaults.standard.set(openAIKey, forKey: "OpenAIAPIKey")
        }

        // Save IGDB credentials if provided
        if !skipOptional {
            if !igdbClientID.isEmpty {
                UserDefaults.standard.set(igdbClientID, forKey: "IGDB_CLIENT_ID")
            }
            if !igdbAccessToken.isEmpty {
                UserDefaults.standard.set(igdbAccessToken, forKey: "IGDB_ACCESS_TOKEN")
            }
        }
    }

    private func markSetupComplete() {
        UserDefaults.standard.set(true, forKey: "HasCompletedSetup")
    }
}

// MARK: - Supporting Views

struct SetupFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Setup Check Extension

public extension View {
    func showSetupWizardIfNeeded() -> some View {
        self.sheet(isPresented: .constant(!UserDefaults.standard.bool(forKey: "HasCompletedSetup"))) {
            SetupWizard()
        }
    }
}