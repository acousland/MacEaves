/*
 OpenAI API Service for MacEaves
 Provides text summarization using OpenAI's API
 */

import Foundation

enum OpenAIError: Error, LocalizedError {
    case invalidConfiguration
    case invalidURL
    case invalidResponse
    case invalidResponseFormat
    case networkError(String)
    case decodingError(String)
    case apiError(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidResponseFormat:
            return "Unexpected response format"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        }
    }
}

@MainActor
class OpenAIService: ObservableObject {
    @Published var summary: String = ""
    @Published var isGeneratingSummary: Bool = false
    @Published var lastError: String?
    
    @Published var actionItems: String = ""
    @Published var isGeneratingActionItems: Bool = false
    @Published var lastActionItemsError: String?
    
    private var apiKey: String?
    private var baseURL: String = "https://api.openai.com/v1"
    private var model: String = "gpt-4o-mini"
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        print("🔍 Debug: Looking for Config.plist in bundle...")
        
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist") else {
            print("❌ Error: Config.plist file not found in bundle")
            print("📂 Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        print("✅ Found Config.plist at: \(configPath)")
        
        guard let configDict = NSDictionary(contentsOfFile: configPath) else {
            print("❌ Error: Could not read Config.plist file")
            return
        }
        
        print("📋 Config file contents: \(configDict)")
        
        guard let openAIConfig = configDict["OpenAI"] as? [String: Any] else {
            print("❌ Error: No 'OpenAI' section found in Config.plist")
            return
        }
        
        self.apiKey = openAIConfig["APIKey"] as? String
        self.baseURL = openAIConfig["BaseURL"] as? String ?? "https://api.openai.com/v1"
        self.model = openAIConfig["Model"] as? String ?? "gpt-4o-mini"
        
        if let apiKey = self.apiKey, !apiKey.isEmpty {
            print("✅ OpenAI API key loaded (length: \(apiKey.count))")
            print("🔗 Base URL: \(self.baseURL)")
            print("🤖 Model: \(self.model)")
        } else {
            print("❌ Error: API key is empty or nil")
        }
    }
    
    func generateActionItems(from transcript: String) async throws {
        print("📋 Debug: Starting action items generation...")
        print("📝 Transcript length: \(transcript.count) characters")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = "OpenAI API key not configured"
            print("❌ Error: \(error)")
            await MainActor.run {
                self.lastActionItemsError = error
            }
            throw OpenAIError.invalidConfiguration
        }
        
        print("🔑 API key available (length: \(apiKey.count))")
        
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Warning: Empty transcript provided")
            await MainActor.run {
                self.actionItems = "No content to analyze for action items yet..."
            }
            return
        }

        await MainActor.run {
            self.isGeneratingActionItems = true
            self.lastActionItemsError = nil
        }
        
        print("📤 Making API request for action items...")

        do {
            let actionItems = try await requestActionItems(transcript: transcript, apiKey: apiKey)
            print("✅ Action items generated successfully (length: \(actionItems.count) characters)")
            await MainActor.run {
                self.actionItems = actionItems
                self.isGeneratingActionItems = false
            }
        } catch {
            let errorMessage = "Failed to generate action items: \(error.localizedDescription)"
            print("❌ API Error: \(errorMessage)")
            print("🔍 Error details: \(error)")
            await MainActor.run {
                self.lastActionItemsError = errorMessage
                self.isGeneratingActionItems = false
            }
            throw error
        }
    }
    
    private func requestActionItems(transcript: String, apiKey: String) async throws -> String {
        let urlString = "\(baseURL)/chat/completions"
        print("🌐 API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Error: Invalid URL - \(urlString)")
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            [
                "role": "system",
                "content": "You are a helpful assistant that extracts action items from conversations. Focus specifically on commitments, tasks, and follow-ups where people say they will do something. Look for phrases like 'I will...', 'I'll...', 'I need to...', 'I should...', 'Let me...', or similar commitments. Format as a clear bulleted list with who is doing what."
            ],
            [
                "role": "user", 
                "content": "Please extract all action items and commitments from the following transcript, focusing on what people said they would do:\n\n\(transcript)"
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 400,
            "temperature": 0.2
        ]
        
        print("📋 Request body: \(requestBody)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 Request prepared, sending...")
        } catch {
            print("❌ Error serializing request body: \(error)")
            throw OpenAIError.networkError("Failed to serialize request: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Response received")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ API Error: \(message)")
                    throw OpenAIError.apiError(message)
                }
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                throw OpenAIError.httpError(httpResponse.statusCode)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Error: Could not parse JSON response")
                throw OpenAIError.invalidResponseFormat
            }
            
            print("✅ JSON parsed successfully")
            
            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("❌ Error: Invalid response format - missing content")
                print("🔍 JSON structure: \(json)")
                throw OpenAIError.invalidResponseFormat
            }
            
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Action items extracted: \(trimmedContent.count) characters")
            return trimmedContent
            
        } catch {
            print("❌ Network error: \(error)")
            throw OpenAIError.networkError(error.localizedDescription)
        }
    }

    func generateSummary(from transcript: String) async throws {
        print("🚀 Debug: Starting summary generation...")
        print("📝 Transcript length: \(transcript.count) characters")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = "OpenAI API key not configured"
            print("❌ Error: \(error)")
            await MainActor.run {
                self.lastError = error
            }
            throw OpenAIError.invalidConfiguration
        }
        
        print("🔑 API key available (length: \(apiKey.count))")
        
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Warning: Empty transcript provided")
            await MainActor.run {
                self.summary = "No content to summarize yet..."
            }
            return
        }

        await MainActor.run {
            self.isGeneratingSummary = true
            self.lastError = nil
        }
        
        print("📤 Making API request...")

        do {
            let summary = try await requestSummary(transcript: transcript, apiKey: apiKey)
            print("✅ Summary generated successfully (length: \(summary.count) characters)")
            await MainActor.run {
                self.summary = summary
                self.isGeneratingSummary = false
            }
        } catch {
            let errorMessage = "Failed to generate summary: \(error.localizedDescription)"
            print("❌ API Error: \(errorMessage)")
            print("🔍 Error details: \(error)")
            await MainActor.run {
                self.lastError = errorMessage
                self.isGeneratingSummary = false
            }
            throw error
        }
    }
    
    private func requestSummary(transcript: String, apiKey: String) async throws -> String {
        let urlString = "\(baseURL)/chat/completions"
        print("🌐 API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Error: Invalid URL - \(urlString)")
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            [
                "role": "system",
                "content": "You are a helpful assistant that creates concise summaries. Focus on key points, decisions, and action items. Keep summaries clear and well-organized."
            ],
            [
                "role": "user", 
                "content": "Please provide a concise summary of the following transcript:\n\n\(transcript)"
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.3
        ]
        
        print("📋 Request body: \(requestBody)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 Request prepared, sending...")
        } catch {
            print("❌ Error serializing request body: \(error)")
            throw OpenAIError.networkError("Failed to serialize request: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Response received")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            print("📋 Response headers: \(httpResponse.allHeaderFields)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ API Error: \(message)")
                    throw OpenAIError.apiError(message)
                }
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                throw OpenAIError.httpError(httpResponse.statusCode)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Error: Could not parse JSON response")
                throw OpenAIError.invalidResponseFormat
            }
            
            print("✅ JSON parsed successfully")
            
            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("❌ Error: Invalid response format - missing content")
                print("🔍 JSON structure: \(json)")
                throw OpenAIError.invalidResponseFormat
            }
            
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Summary extracted: \(trimmedContent.count) characters")
            return trimmedContent
            
        } catch {
            print("❌ Network error: \(error)")
            throw OpenAIError.networkError(error.localizedDescription)
        }
    }
}
