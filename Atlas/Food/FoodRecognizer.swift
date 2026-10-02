import Foundation
import UIKit
import Vision
import CoreImage

struct RecognizedLabel: Sendable, Hashable {
    var name: String
    var confidence: Double
}

struct FoodRecognition: Sendable {
    var items: [FoodItem]
    var labels: [RecognizedLabel]
    var usedFallback: Bool
}

/// Food photo recognition.
///
/// 1. Tries Vision `VNClassifyImageRequest` off the main thread → label →
///    FoodDB mapping → default portions.
/// 2. Simulator fallback: when Vision yields nothing usable (common on iOS
///    simulators), compares a tiny color histogram of the image against the
///    bundled sample photos' precomputed signatures and returns the known
///    items of the closest sample — keeps the Snap flow demoable.
///    Results are flagged `usedFallback`.
enum FoodRecognizer {

    /// Known contents of each bundled sample photo (id → item ids + qty).
    /// Populated from `SampleMeals/manifest.json` in Resources.
    private struct SampleSignature: Sendable {
        var name: String
        var histogram: [Double]   // 4x4x4 RGB bins, normalized
        var foodIds: [String]
    }

    /// Vision label word → food database search term(s).
    private static let labelMap: [(match: String, query: String)] = [
        ("pizza", "pizza"), ("burger", "burger"), ("hamburger", "burger"),
        ("sushi", "sushi_roll"), ("sashimi", "sashimi"), ("rice", "white_rice"),
        ("salad", "garden_salad"), ("pasta", "pasta_marinara"), ("spaghetti", "pasta_marinara"),
        ("steak", "steak"), ("chicken", "chicken_breast"), ("salmon", "salmon"),
        ("egg", "egg"), ("burrito", "burrito"), ("taco", "taco"),
        ("sandwich", "sandwich"), ("soup", "soup"), ("fries", "fries"),
        ("pancake", "pancakes"), ("waffle", "waffles"), ("oatmeal", "oatmeal"),
        ("yogurt", "greek_yogurt"), ("bagel", "bagel"), ("toast", "toast"),
        ("banana", "banana"), ("apple", "apple"), ("avocado", "avocado"),
        ("broccoli", "broccoli"), ("coffee", "coffee"), ("smoothie", "protein_shake"),
        ("cake", "cake"), ("donut", "donut"), ("cookie", "cookie"),
        ("noodle", "pad_thai"), ("poke", "poke_bowl"), ("bowl", "chipotle_bowl"),
    ]

    static func recognize(_ image: UIImage) async -> FoodRecognition {
        guard let cg = image.cgImage else {
            return FoodRecognition(items: [], labels: [], usedFallback: false)
        }

        // 1. Vision classification (off main thread).
        let labels = await classify(cg)
        let foodLabels = labels.filter { $0.confidence > 0.1 }
        if !foodLabels.isEmpty {
            var items: [FoodItem] = []
            for label in foodLabels.prefix(6) {
                if let mapped = mapLabel(label.name, confidence: label.confidence) {
                    items.append(mapped)
                }
            }
            if !items.isEmpty {
                return FoodRecognition(items: dedupe(items), labels: foodLabels, usedFallback: false)
            }
            // Vision worked but nothing food-like: return labels so the UI can
            // fall back to Describe with the top label prefilled.
            let fallback = sampleMatch(for: cg)
            if let fallback, !fallback.items.isEmpty {
                return FoodRecognition(items: fallback.items, labels: foodLabels, usedFallback: true)
            }
            return FoodRecognition(items: [], labels: foodLabels, usedFallback: false)
        }

        // 2. Vision unusable (simulator) → sample-photo histogram match.
        if let match = sampleMatch(for: cg) {
            return FoodRecognition(items: match.items,
                                   labels: [RecognizedLabel(name: match.name, confidence: 0.6)],
                                   usedFallback: true)
        }
        return FoodRecognition(items: [], labels: [], usedFallback: false)
    }

    // MARK: - Vision

    private static func classify(_ image: CGImage) async -> [RecognizedLabel] {
        await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            do {
                try handler.perform([request])
                let results = (request.results ?? [])
                    .filter { $0.hasMinimumPrecision(0.05) || $0.confidence > 0.1 }
                    .prefix(12)
                return results.map { RecognizedLabel(name: $0.identifier,
                                                     confidence: Double($0.confidence)) }
            } catch {
                return []
            }
        }.value
    }

    private static func mapLabel(_ label: String, confidence: Double) -> FoodItem? {
        let l = label.lowercased().replacingOccurrences(of: "_", with: " ")
        for m in labelMap where l.contains(m.match) {
            if let entry = FoodDatabase.shared.bestMatch(for: m.query) {
                return entry.item(quantity: 1, confidence: confidence)
            }
        }
        // Direct DB match on the label itself.
        if let entry = FoodDatabase.shared.bestMatch(for: l) {
            return entry.item(quantity: 1, confidence: confidence * 0.8)
        }
        return nil
    }

    private static func dedupe(_ items: [FoodItem]) -> [FoodItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.foodId ?? $0.name).inserted }
    }

    // MARK: - Simulator fallback: histogram match against sample photos

    private static var signatures: [SampleSignature]? = nil

    /// Loads bundled sample photos + manifest and computes histograms once.
    private static func loadSignatures() -> [SampleSignature] {
        if let signatures { return signatures }
        var result: [SampleSignature] = []
        let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json",
                                          subdirectory: "SampleMeals")
        let manifest = manifestURL.flatMap {
            try? JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: $0))
        } ?? [:]
        for (name, foodIds) in manifest {
            guard let url = Bundle.main.url(forResource: name, withExtension: "jpg",
                                            subdirectory: "SampleMeals"),
                  let data = try? Data(contentsOf: url),
                  let img = UIImage(data: data)?.cgImage else { continue }
            result.append(SampleSignature(name: name, histogram: histogram(img), foodIds: foodIds))
        }
        signatures = result
        return result
    }

    /// 4×4×4 RGB histogram, normalized.
    static func histogram(_ image: CGImage) -> [Double] {
        let w = 16, h = 16
        let space = CGColorSpaceCreateDeviceRGB()
        var bins = [Double](repeating: 0, count: 64)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return bins
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return bins }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for i in 0..<(w * h) {
            let r = Int(ptr[i * 4]) >> 6
            let g = Int(ptr[i * 4 + 1]) >> 6
            let b = Int(ptr[i * 4 + 2]) >> 6
            bins[r * 16 + g * 4 + b] += 1
        }
        let total = Double(w * h)
        return bins.map { $0 / total }
    }

    /// Closest bundled sample photo by histogram distance; returns its items.
    private static func sampleMatch(for image: CGImage) -> (name: String, items: [FoodItem])? {
        let sigs = loadSignatures()
        guard !sigs.isEmpty else { return nil }
        let h = histogram(image)
        var best: (sig: SampleSignature, dist: Double)?
        for sig in sigs {
            var d = 0.0
            for i in 0..<64 { d += (h[i] - sig.histogram[i]) * (h[i] - sig.histogram[i]) }
            if best == nil || d < best!.dist { best = (sig, d) }
        }
        guard let best else { return nil }
        let items = best.sig.foodIds.compactMap { FoodDatabase.shared.entry(id: $0)?.item(quantity: 1, confidence: 0.55) }
        return (best.sig.name, items)
    }
}
