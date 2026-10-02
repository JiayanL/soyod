import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Picks the best available coach engine.
enum CoachRouter {

    static func current() -> any CoachAgent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           SystemLanguageModel.default.availability == .available {
            return FoundationModelsCoach()
        }
        #endif
        let remote = RemoteLLMCoach()
        if remote.isConfigured { return remote }
        return RuleBasedCoach()
    }

    static var engineStatus: CoachEngineStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return CoachEngineStatus(name: "Apple Intelligence",
                                         detail: "On-device foundation model with Atlas tools.")
            case .unavailable(let reason):
                // Fall through to whichever engine is actually serving replies.
                let remote = RemoteLLMCoach()
                if remote.isConfigured {
                    let model = UserDefaults.standard.string(forKey: "atlas.remote.model") ?? "remote"
                    return CoachEngineStatus(name: "Remote · \(model)",
                                             detail: "OpenAI-compatible endpoint from Settings.")
                }
                let why: String
                switch reason {
                case .deviceNotEligible: why = "this device isn't eligible for Apple Intelligence"
                case .appleIntelligenceNotEnabled: why = "Apple Intelligence is off in Settings"
                case .modelNotReady: why = "the model is still downloading"
                @unknown default: why = "Apple Intelligence is unavailable"
                }
                return CoachEngineStatus(name: "Atlas on-device",
                                         detail: "Rule-based coach (\(why)).")
            @unknown default:
                break
            }
        }
        #endif
        let remote = RemoteLLMCoach()
        if remote.isConfigured {
            let model = UserDefaults.standard.string(forKey: "atlas.remote.model") ?? "remote"
            return CoachEngineStatus(name: "Remote · \(model)",
                                     detail: "OpenAI-compatible endpoint from Settings.")
        }
        return CoachEngineStatus(name: "Atlas on-device",
                                 detail: "Rule-based coach — always available, fully private.")
    }
}
