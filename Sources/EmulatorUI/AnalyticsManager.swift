import Foundation
import SwiftUI

// Analytics session model
struct AnalyticsSession: Codable, Identifiable {
    let id: UUID
    let gameTitle: String
    let platform: String
    let channel: String
    let startDate: Date
    var endDate: Date?

    // Aggregates
    var totalMessages: Int
    var viewerSamples: [Int]
    var sampleTimestamps: [Date]

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    var averageViewers: Double {
        guard !viewerSamples.isEmpty else { return 0 }
        return Double(viewerSamples.reduce(0, +)) / Double(viewerSamples.count)
    }

    var peakViewers: Int { viewerSamples.max() ?? 0 }
    var viewTimeScore: Double { averageViewers * duration } // rough engagement metric
}

// Aggregated daily metrics
struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    let viewTimeScore: Double
    let sessions: [AnalyticsSession]
}

@MainActor
final class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    @Published private(set) var sessions: [AnalyticsSession] = []
    @Published private(set) var suggestions: [String] = []

    private var currentSessionID: UUID?
    private let storageKey = "analytics_sessions"

    // Optional: API for AI suggestions
    private var openAIKey: String {
        if let key = UserDefaults.standard.string(forKey: "OpenAIAPIKey") { return key }
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] { return key }
        return ""
    }

    private init() {
        load()
        setupObservers()
    }

    // MARK: - Public API

    func startSession(gameTitle: String, platform: String = "twitch", channel: String = "") {
        endCurrentSession() // close any open session
        let session = AnalyticsSession(
            id: UUID(),
            gameTitle: gameTitle,
            platform: platform,
            channel: channel,
            startDate: Date(),
            endDate: nil,
            totalMessages: 0,
            viewerSamples: [],
            sampleTimestamps: []
        )
        sessions.append(session)
        currentSessionID = session.id
        save()
    }

    func endCurrentSession() {
        guard let id = currentSessionID, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].endDate = Date()
        currentSessionID = nil
        save()
    }

    func recordChatMessage() {
        guard let id = currentSessionID, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].totalMessages += 1
        save()
    }

    func recordViewerCount(_ count: Int) {
        guard let id = currentSessionID, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].viewerSamples.append(max(0, count))
        sessions[idx].sampleTimestamps.append(Date())
        save()
    }

    func updateCurrentSession(platform: String, channel: String) {
        guard let id = currentSessionID, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx] = AnalyticsSession(
            id: sessions[idx].id,
            gameTitle: sessions[idx].gameTitle,
            platform: platform,
            channel: channel,
            startDate: sessions[idx].startDate,
            endDate: sessions[idx].endDate,
            totalMessages: sessions[idx].totalMessages,
            viewerSamples: sessions[idx].viewerSamples,
            sampleTimestamps: sessions[idx].sampleTimestamps
        )
        save()
    }

    func topGamesByEngagement(limit: Int = 5) -> [(String, Double)] {
        let grouped = Dictionary(grouping: sessions, by: { $0.gameTitle })
        let scored = grouped.map { (title, sessions) -> (String, Double) in
            let score = sessions.reduce(0.0) { $0 + $1.viewTimeScore }
            return (title, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }

    func dailyStats(lastDays: Int = 30) -> [DailyStat] {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date().addingTimeInterval(TimeInterval(-lastDays * 24 * 3600)))
        var map: [Date: [AnalyticsSession]] = [:]
        for s in sessions {
            let day = cal.startOfDay(for: s.startDate)
            guard day >= from else { continue }
            map[day, default: []].append(s)
        }
        return map.keys.sorted().map { day in
            let ss = map[day] ?? []
            let score = ss.reduce(0.0) { $0 + $1.viewTimeScore }
            return DailyStat(date: day, viewTimeScore: score, sessions: ss)
        }
    }

    func generateSuggestions() async {
        let top = topGamesByEngagement(limit: 5)
        let hotHours = hotStreamingHours()

        // Fallback heuristic suggestions
        var ideas: [String] = []
        if let best = top.first { ideas.append("Double down on \(best.0) — highest engagement.") }
        if top.count > 1 { ideas.append("Rotate \(top[1].0) as your backup headliner.") }
        if !hotHours.isEmpty {
            let bestHour = hotHours.max(by: { $0.value < $1.value })?.key ?? 20
            ideas.append("Stream around \(bestHour):00 — peak viewer activity.")
        }
        ideas.append("Create shorts from peak-chat moments to funnel viewers.")

        // Try AI if available
        if !openAIKey.isEmpty {
            do {
                let prompt = buildAISummaryPrompt(topGames: top, hotHours: hotHours)
                let ai = try await callOpenAI(prompt: prompt)
                suggestions = ai.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                return
            } catch {
                // Ignore and use heuristics
            }
        }
        suggestions = ideas
    }

    // MARK: - Private

    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .gameStarted, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                let title = (note.object as? String) ?? "Unknown Game"
                self?.startSession(gameTitle: title)
            }
        }
        NotificationCenter.default.addObserver(forName: .gameStopped, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.endCurrentSession()
            }
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Analytics save failed: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([AnalyticsSession].self, from: data) {
            sessions = saved
        }
    }

    private func hotStreamingHours() -> [Int: Double] {
        // Aggregate viewTimeScore by hour of day across sessions
        var map: [Int: Double] = [:]
        let cal = Calendar.current
        for s in sessions {
            let hour = cal.component(.hour, from: s.startDate)
            map[hour, default: 0] += s.viewTimeScore
        }
        return map
    }

    private func buildAISummaryPrompt(topGames: [(String, Double)], hotHours: [Int: Double]) -> String {
        let gamesList = topGames.map { "- \($0.0): score=\(Int($0.1))" }.joined(separator: "\n")
        let hoursList = hotHours.sorted { $0.key < $1.key }.map { "Hour \($0.key): score=\(Int($0.value))" }.joined(separator: "\n")
        return """
        You are a creator growth coach. Given streaming analytics, propose a concise plan:
        - Top games to focus on next 2 weeks (why)
        - Ideal streaming schedule (days/times)
        - 3 content ideas for VOD/Shorts from past peaks
        Keep it to 5-7 bullet points.

        Data:
        Top Games by engagement:
        \(gamesList)

        Activity by hour:
        \(hoursList)
        """
    }

    private func callOpenAI(prompt: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return "" }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": "You are a streaming analytics assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 300,
            "temperature": 0.5
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if let choices = json["choices"] as? [[String: Any]],
           let msg = choices.first?["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content
        }
        return ""
    }
}
