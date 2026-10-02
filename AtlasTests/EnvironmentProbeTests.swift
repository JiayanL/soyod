import Testing
import Foundation
import UIKit
import Vision
@testable import Atlas
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Environment probes — prints results for the report rather than asserting
/// hard availability (simulator support varies).
struct EnvironmentProbeTests {

    @MainActor
    @Test func foundationModelsAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            print("PROBE FoundationModels availability: \(availability)")
            switch availability {
            case .available:
                print("PROBE FoundationModels: AVAILABLE")
            case .unavailable(let reason):
                print("PROBE FoundationModels: UNAVAILABLE reason=\(reason)")
            @unknown default:
                print("PROBE FoundationModels: UNKNOWN")
            }
        }
        #else
        print("PROBE FoundationModels: framework not importable")
        #endif
    }

    /// Which engine actually answers, and does its reply keep the time?
    @Test func engineActuallyUsed() async throws {
        let agent = CoachRouter.current()
        print("PROBE engine selected: \(type(of: agent))")
        var c = CoachContext(now: Date())
        c.targets = MacroTargets(kcal: 3000, proteinG: 168, carbsG: 330, fatG: 67)
        c.remaining = MacroTotals(kcal: 2300, protein: 118, carbs: 250, fat: 47)
        do {
            let r = try await agent.respond(to: "I have dinner at Nobu at 7:30 tonight",
                                            history: [], context: c)
            print("PROBE engine reply: \(r.text)")
            print("PROBE engine actions: \(r.actions.map { "\($0.kind):\($0.title)|\($0.subtitle)" })")
        } catch {
            print("PROBE engine threw: \(error)")
        }
        let r2 = try? await RuleBasedCoach().respond(to: "I have dinner at Nobu at 7:30 tonight",
                                                   history: [], context: c)
        if let r2 {
            print("PROBE rule reply: \(r2.text)")
            print("PROBE rule actions: \(r2.actions.map { "\($0.kind):\($0.title)|\($0.subtitle)" })")
        }
    }

    @Test func visionClassifyImageRequest() async throws {
        // Draw a simple food-ish image (red circle on tan background).
        let size = CGSize(width: 224, height: 224)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor(red: 0.85, green: 0.7, blue: 0.45, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.7, green: 0.2, blue: 0.15, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 60, y: 60, width: 100, height: 100))
        }
        guard let cg = img.cgImage else { return }
        let labels: [String] = await Task.detached {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            do {
                try handler.perform([request])
                return (request.results ?? []).prefix(5).map {
                    "\($0.identifier)(\(String(format: "%.2f", $0.confidence)))"
                }
            } catch {
                return ["ERROR: \(error.localizedDescription)"]
            }
        }.value
        print("PROBE VNClassifyImageRequest labels: \(labels)")
    }

    @Test func recognizerOnSamplePhoto() async throws {
        // The bundled sample photos must produce items even if Vision is dead.
        guard let url = Bundle.main.url(forResource: "chicken_rice_bowl", withExtension: "jpg",
                                        subdirectory: "SampleMeals"),
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else {
            print("PROBE sample photo missing")
            return
        }
        let r = await FoodRecognizer.recognize(img)
        print("PROBE recognizer: items=\(r.items.map(\.name)) labels=\(r.labels.map(\.name)) fallback=\(r.usedFallback)")
        #expect(!r.items.isEmpty)
    }
}
