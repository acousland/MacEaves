/*
 OpenAI API Service for MacEaves
 Provides text summarization using OpenAI's API
 */

// NOTE: All uses of self or class properties in nonisolated(nonsending) functions must be performed on MainActor for data-race safety.

import Foundation
import Observation

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

/// All @Published properties must only be accessed on the MainActor to ensure thread safety.
@MainActor
public class OpenAIService: ObservableObject {
    @Published public var summary: String = ""
    @Published public var isGeneratingSummary: Bool = false
    @Published public var lastError: String?
    
    @Published public var actionItems: String = ""
    @Published public var isGeneratingActionItems: Bool = false
    @Published public var lastActionItemsError: String?
    
    @Published public var topicContext: String = ""
    @Published public var isGeneratingTopicContext: Bool = false
    @Published public var lastTopicContextError: String?
    
    private var apiKey: String?
    
    /// Returns true if the OpenAI service is properly configured with an API key
    public var isConfigured: Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    private var baseURL: String = "https://api.openai.com/v1"
    private var model: String = "gpt-4o-mini"
    
    public init() {
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
    
    /// Generates action items from a transcript.
    /// Note: All access to self and its properties is done on MainActor to ensure data race safety and comply with the Sendable model.
    public func generateActionItems(from transcript: String) async throws {
        print("📋 Debug: Starting action items generation...")
        print("📝 Transcript length: \(transcript.count) characters")
        
        let apiKey = self.apiKey
        if apiKey == nil || apiKey!.isEmpty {
            let error = "OpenAI API key not configured"
            print("❌ Error: \(error)")
            self.lastActionItemsError = error
            throw OpenAIError.invalidConfiguration
        }
        print("🔑 API key available (length: \(apiKey!.count))")
        
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("⚠️ Warning: Empty transcript provided")
            self.actionItems = "No content to analyze for action items yet..."
            return
        }

        self.isGeneratingActionItems = true
        self.lastActionItemsError = nil
        
        print("📤 Making API request for action items...")

        do {
            let actionItems = try await requestActionItems(transcript: transcript, apiKey: apiKey!)
            print("✅ Action items generated successfully (length: \(actionItems.count) characters)")
            self.actionItems = actionItems
            self.isGeneratingActionItems = false
        } catch {
            let errorMessage = "Failed to generate action items: \(error.localizedDescription)"
            print("❌ API Error: \(errorMessage)")
            print("🔍 Error details: \(error)")
            self.lastActionItemsError = errorMessage
            self.isGeneratingActionItems = false
            throw error
        }
    }
    
    /// Requests action items from OpenAI API.
    /// Note: Accesses to self's properties are done on MainActor for thread safety and Sendable compliance.
    private func requestActionItems(transcript: String, apiKey: String) async throws -> String {
        let (baseURL, model) = (self.baseURL, self.model)
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
                "content": "You are a helpful assistant that extracts action items from conversations. Focus specifically on commitments, tasks, and follow-ups where people say they will do something. Look for phrases like 'I will...', 'I'll...', 'I need to...', 'I should...', 'Let me...', or similar commitments. Format as a clear bulleted list with who is doing what. Group action items by themes or categories when appropriate (e.g., Technical Tasks, Administrative Items, Follow-ups, etc.)."
            ],
            [
                "role": "user",
                "content": "Please extract all action items and commitments from the following transcript, focusing on what people said they would do. Group them by themes or categories where appropriate:\n\n\(transcript)"
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

    /// Generates a summary from a transcript.
    /// Note: All access to self and its properties is done on MainActor to ensure data race safety and comply with the Sendable model.
    public func generateSummary(from transcript: String) async throws {
        print("🚀 Debug: Starting summary generation...")
        print("📝 Transcript length: \(transcript.count) characters")
        
        let apiKey = self.apiKey
        if apiKey == nil || apiKey!.isEmpty {
            let error = "OpenAI API key not configured"
            print("❌ Error: \(error)")
            self.lastError = error
            throw OpenAIError.invalidConfiguration
        }
        
        print("🔑 API key available (length: \(apiKey!.count))")
        
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("⚠️ Warning: Empty transcript provided")
            self.summary = "No content to summarize yet..."
            return
        }

        self.isGeneratingSummary = true
        self.lastError = nil
        
        print("📤 Making API request...")

        do {
            let previousSummary = self.summary.isEmpty ? nil : self.summary
            let summary = try await requestSummary(transcript: transcript, previousSummary: previousSummary, apiKey: apiKey!)
            print("✅ Summary generated successfully (length: \(summary.count) characters)")
            self.summary = summary
            self.isGeneratingSummary = false
        } catch {
            let errorMessage = "Failed to generate summary: \(error.localizedDescription)"
            print("❌ API Error: \(errorMessage)")
            print("🔍 Error details: \(error)")
            self.lastError = errorMessage
            self.isGeneratingSummary = false
            throw error
        }
    }
    
    /// Requests summary from OpenAI API.
    /// Note: Accesses to self's properties are done on MainActor for thread safety and Sendable compliance.
    private func requestSummary(transcript: String, previousSummary: String?, apiKey: String) async throws -> String {
        let (baseURL, model) = (self.baseURL, self.model)
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
        
        let systemMessage: String
        let userMessage: String
        
        if let previousSummary = previousSummary, !previousSummary.isEmpty && !previousSummary.contains("No content to summarize yet") {
            // Update existing summary
            systemMessage = "You are a helpful assistant that updates and refines meeting summaries. IMPORTANT: Preserve the existing thematic groupings and structure. Only add new information or refine existing content. Do not reorganize or change the established themes unless absolutely necessary. Keep the same section headings and organization."
            userMessage = "Here is the current summary:\n\n\(previousSummary)\n\nHere is the full transcript (which includes previous content plus new content):\n\n\(transcript)\n\nPlease update the summary by adding any new information or refining existing content. Keep the same thematic structure and groupings. Only add new themes if there is genuinely new topic areas not covered in the existing summary."
        } else {
            // Create initial summary
            systemMessage = "You are a helpful assistant that creates concise summaries. Focus on key points, decisions, and action items. Organize content by themes or topics when appropriate. Keep summaries clear and well-organized, grouping related discussions together."
            userMessage = "Please provide a concise summary of the following transcript, organizing the content by themes or topics where appropriate:\n\n\(transcript)"
        }
        
        let messages = [
            [
                "role": "system",
                "content": systemMessage
            ],
            [
                "role": "user",
                "content": userMessage
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
    
    /// Generates topic context from a transcript.
    /// Note: All access to self and its properties is done on MainActor to ensure data race safety and comply with the Sendable model.
    public func generateTopicContext(from transcript: String) async throws {
        print("🎯 Debug: Starting topic context generation...")
        print("📝 Transcript length: \(transcript.count) characters")
        
        let apiKey = self.apiKey
        if apiKey == nil || apiKey!.isEmpty {
            let error = "OpenAI API key not configured"
            print("❌ Error: \(error)")
            self.lastTopicContextError = error
            throw OpenAIError.invalidConfiguration
        }
        print("🔑 API key available (length: \(apiKey!.count))")
        
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("⚠️ Warning: Empty transcript provided")
            self.topicContext = "--- No topic detected ---"
            return
        }

        self.isGeneratingTopicContext = true
        self.lastTopicContextError = nil
        
        print("📤 Making API request for topic context...")

        do {
            let topicContext = try await requestTopicContext(transcript: transcript, apiKey: apiKey!)
            print("✅ Topic context generated successfully (length: \(topicContext.count) characters)")
            self.topicContext = topicContext
            self.isGeneratingTopicContext = false
        } catch {
            let errorMessage = "Failed to generate topic context: \(error.localizedDescription)"
            print("❌ API Error: \(errorMessage)")
            print("🔍 Error details: \(error)")
            self.lastTopicContextError = errorMessage
            self.isGeneratingTopicContext = false
            throw error
        }
    }
    
    /// Requests topic context from OpenAI API.
    /// Note: Accesses to self's properties are done on MainActor for thread safety and Sendable compliance.
    private func requestTopicContext(transcript: String, apiKey: String) async throws -> String {
        let (baseURL, model) = (self.baseURL, self.model)
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
        
        let systemMessage = """
You are an assistant who pinpoints and summarises **only** the latest substantive \
topic in a conversation transcript. A "substantive topic" is the final cluster of \
at least two turns that share a common subject matter, excluding greetings, \
house-keeping, or meta-comments.  

Guidelines for your reply  
• Produce exactly 3–4 bullet points, each starting with "• ".  
• Keep every point under 15 words, use Australian English, and include Oxford commas.  
• Do not mention earlier topics or the rules themselves.  
• If you cannot detect a substantive topic, reply with exactly:  
  --- No topic detected ---
"""
        
        let userMessage = """
Identify the latest substantive topic in the transcript below and summarise it in \
3–4 ultra-concise bullet points. Follow the system guidelines strictly. If no topic \
fits the definition, output: --- No topic detected ---

### TRANSCRIPT START
\(transcript)
### TRANSCRIPT END
"""
        


        let messages = [
            [
                "role": "system", 
                "content": systemMessage
            ],
            [
                "role": "user",
                "content": userMessage
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 150,
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
            print("✅ Topic context extracted: \(trimmedContent.count) characters")
            return trimmedContent
            
        } catch {
            print("❌ Network error: \(error)")
            throw OpenAIError.networkError(error.localizedDescription)
        }
    }
}

