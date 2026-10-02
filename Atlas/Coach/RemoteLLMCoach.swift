import Foundation

/// Optional OpenAI-compatible remote coach. Disabled by default; any error
/// falls back to RuleBasedCoach. Key is stored in Keychain ("atlas.remote.apiKey"),
/// base URL + model in UserDefaults.
final class RemoteLLMCoach: CoachAgent {
    let displayName: String
    private let fallback = RuleBasedCoach()

    private var apiKey: String? { KeychainStore.string(for: "atlas.remoteLLMKey") }
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "atlas.remote.baseURL") ?? "https://api.openai.com/v1"
    }
    private var model: String {
        UserDefaults.standard.string(forKey: "atlas.remote.model") ?? "gpt-4o-mini"
    }

    var isConfigured: Bool { apiKey != nil }

    init() {
        displayName = "Remote"
    }

    func respond(to text: String, history: [ChatTurn], context c: CoachContext) async throws -> CoachReply {
        guard let key = apiKey else {
            return try await fallback.respond(to: text, history: history, context: c)
        }
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt(for: c)]
        ]
        for t in history.suffix(20) {
            messages.append(["role": t.role == .user ? "user" : "assistant", "content": t.text])
        }
        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 400,
        ]
        var req = URLRequest(url: URL(string: baseURL + "/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let content = msg["content"] as? String else {
                return try await fallback.respond(to: text, history: history, context: c)
            }
            var reply = CoachReply(text: content)
            reply.memoryWrites = MemoryExtractor.extract(from: text, now: c.now)
            return reply
        } catch {
            return try await fallback.respond(to: text, history: history, context: c)
        }
    }

    private func systemPrompt(for c: CoachContext) -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsCoach.instructions(for: c)
        }
        #endif
        return "You are Atlas, a tactical fitness coach. Be brief, cite numbers."
    }
}
