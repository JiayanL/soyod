# AGENTS.md — Atlas iOS

## Must-read
- `docs/PRD.md` (what), `docs/TECH_SPEC.md` (how), `docs/DESIGN.md` (look & feel + taste checklist).
- Skills vendored in `.agents/skills/` (MIT): `swiftui-expert-skill` (SwiftUI best practices, Liquid Glass, Charts, animations) and `swiftui-design-principles` (spacing/typography/color discipline). Read their SKILL.md before writing UI.

## Conventions
- SwiftUI + SwiftData, iOS 17 min, iOS 26 features behind `#available`.
- Only design tokens from `Atlas/DesignSystem/Theme.swift`. Don't use hardcoded colors, fonts, or spacing in feature views.
- Engines are pure Swift and unit-tested. Views stay thin.
- The project is generated with XcodeGen from `project.yml`. After editing it, run `xcodegen generate` and commit the regenerated `Atlas.xcodeproj`.
