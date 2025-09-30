import SwiftUI
import Foundation
import CoreInterface
import EmulatorKit

/// AI-powered chat manager for game discussions
@MainActor
public class GameChatManager: ObservableObject {
    @Published var messages: [GameChatMessage] = []
    @Published var isLoading = false

    private let openAIKey: String
    private var gameContext: String = ""

    public init() {
        if let key = UserDefaults.standard.string(forKey: "OpenAIAPIKey") {
            openAIKey = key
        } else if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            openAIKey = key
        } else {
            openAIKey = ""
        }
    }

    /// Initialize chat with game context
    public func initializeWithGame(_ game: ROMMetadata, metadata: GameMetadataFetcher.GameMetadata?) async {
        let title = metadata?.title ?? game.title
        let description = metadata?.description ?? "A classic video game"
        let genre = metadata?.genre ?? "Unknown"
        let year = metadata?.releaseYear ?? "Unknown"
        let developer = metadata?.developer ?? "Unknown"

        gameContext = """
        Game: \(title)
        System: \(game.system.displayName)
        Genre: \(genre)
        Release Year: \(year)
        Developer: \(developer)
        Description: \(description)
        """

        // Add welcome message
        let welcomeMessage = GameChatMessage(
            content: "Hi! I'm here to chat about \(title). Ask me anything about this game - its story, gameplay mechanics, historical significance, development, or any tips you might need!",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }

    /// Send a message and get AI response
    public func sendMessage(_ content: String) async {
        let userMessage = GameChatMessage(
            content: content,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)

        guard !openAIKey.isEmpty else {
            let errorMessage = GameChatMessage(
                content: "Sorry, I need an OpenAI API key to chat. You can add one in Settings.",
                isUser: false,
                timestamp: Date()
            )
            messages.append(errorMessage)
            return
        }

        isLoading = true

        let response = await generateAIResponse(for: content)
        let aiMessage = GameChatMessage(
            content: response,
            isUser: false,
            timestamp: Date()
        )
        messages.append(aiMessage)

        isLoading = false
    }

    /// Generate AI response using OpenAI
    private func generateAIResponse(for userMessage: String) async -> String {
        let systemPrompt = """
        You are an enthusiastic and knowledgeable video game expert specializing in retro gaming, particularly Nintendo 64 games. You have deep knowledge about game history, development, gameplay mechanics, stories, characters, and cultural impact.

        You're currently discussing this specific game:
        \(gameContext)

        Guidelines:
        - Be enthusiastic and engaging about gaming
        - Provide detailed, accurate information
        - Share interesting trivia and behind-the-scenes facts
        - Give helpful gameplay tips when asked
        - Discuss the game's place in gaming history
        - Be conversational and friendly
        - If you're not certain about something, say so
        - Keep responses focused on the game being discussed
        - Acknowledge the nostalgic value of retro gaming
        """

        do {
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody: [String: Any] = [
                "model": "gpt-4-turbo-preview",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userMessage]
                ],
                "max_tokens": 500,
                "temperature": 0.7
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            if let choices = response["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("AI chat error: \(error)")
        }

        // Fallback responses based on game context
        return generateFallbackResponse(for: userMessage)
    }

    /// Generate fallback response when AI is unavailable
    private func generateFallbackResponse(for userMessage: String) -> String {
        let message = userMessage.lowercased()

        if message.contains("gameplay") || message.contains("play") {
            return "This is a classic game with engaging gameplay mechanics that were innovative for its time on the Nintendo 64. The controls and game design really showcase what made this era special!"
        } else if message.contains("story") || message.contains("plot") {
            return "The story and narrative elements in this game were quite memorable for N64 players. Many consider it a great example of storytelling in that gaming era."
        } else if message.contains("tip") || message.contains("help") || message.contains("difficult") {
            return "Like many N64 games, this one has its challenging moments! The key is often patience and practice. Don't be afraid to experiment with different approaches."
        } else if message.contains("history") || message.contains("significant") {
            return "This game holds an important place in Nintendo 64's library and gaming history overall. It represents the innovative spirit of that console generation."
        } else if message.contains("special") || message.contains("unique") {
            return "What makes this game special is how it captured the essence of N64 gaming - from the controller innovations to the 3D graphics that were revolutionary at the time."
        } else {
            return "That's an interesting question! This game has so many layers to explore and discuss. What specifically interests you most about it?"
        }
    }

    /// Clear chat history
    public func clearChat() {
        messages.removeAll()
    }
}

/// Chat message model for game discussions
public struct GameChatMessage: Identifiable, Codable {
    public let id: UUID
    public let content: String
    public let isUser: Bool
    public let timestamp: Date

    public init(content: String, isUser: Bool, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}