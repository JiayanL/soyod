import SwiftUI
import UIKit

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension Theme.Palette {
    static func scoreWord(_ value: Int) -> String {
        switch value {
        case ..<34: "Low — go easy"
        case 34..<67: "Moderate"
        default: "Primed"
        }
    }
}
