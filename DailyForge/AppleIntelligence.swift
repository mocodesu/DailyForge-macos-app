import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceError: Error {
    case unavailable
    case failed(String)
}

func generateWithAppleIntelligence(prompt: String) async throws -> String {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AppleIntelligenceError.unavailable
        }
        let session = LanguageModelSession()
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            throw AppleIntelligenceError.failed(error.localizedDescription)
        }
    }
    #endif
    throw AppleIntelligenceError.unavailable
}
