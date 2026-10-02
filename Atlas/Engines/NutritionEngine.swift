import Foundation

/// Plain struct of profile fields so onboarding can preview targets
/// without a SwiftData UserProfile.
nonisolated struct ProfileInput: Codable, Hashable, Sendable {
    var sex: Sex
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var dietStyle: DietStyle = .none
}

nonisolated enum NutritionEngine {

    /// Mifflin–St Jeor BMR × activity → TDEE, then goal adjustment.
    static func targets(for p: ProfileInput, goal: GoalKind) -> MacroTargets {
        let bmr: Double
        if p.sex == .male {
            bmr = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age) + 5
        } else {
            bmr = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age) - 161
        }
        var kcal = bmr * p.activityLevel.factor

        switch goal {
        case .fatLoss, .waist:
            kcal *= 0.80
        case .muscle, .glutes:
            kcal *= 1.10
        case .vertical, .strength, .run, .custom:
            kcal *= 1.02
        }

        // Safe floors.
        let floor: Double = p.sex == .female ? 1200 : 1500
        kcal = max(kcal, floor)
        kcal = (kcal / 10).rounded() * 10

        let proteinPerKg: Double
        switch goal {
        case .muscle, .glutes: proteinPerKg = 2.2
        case .run: proteinPerKg = 1.8
        default: proteinPerKg = 2.0
        }
        var protein = proteinPerKg * p.weightKg
        var fat = 0.8 * p.weightKg

        // Make sure protein + fat don't blow the budget; shrink protein first
        // down to 1.6 g/kg, then fat.
        func kcalUsed() -> Double { protein * 4 + fat * 9 }
        if kcalUsed() > kcal * 0.9 {
            protein = 1.6 * p.weightKg
        }
        if kcalUsed() > kcal * 0.9 {
            fat = max(0.6 * p.weightKg, (kcal * 0.25) / 9)
        }
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4)

        return MacroTargets(
            kcal: Int(kcal.rounded()),
            proteinG: Int(protein.rounded()),
            carbsG: Int(carbs.rounded()),
            fatG: Int(fat.rounded())
        )
    }
}
