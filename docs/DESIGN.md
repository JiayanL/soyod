# Atlas — Design System & UX Guidelines

> **North star:** Atlas should feel like a *$30/month* product built by the people who made Whoop, Oura, and Cal AI. That means calm, confident, editorial, and fast. Every screen answers "what do I do next?" in under 3 seconds.

## 0. Reference benchmark (studied from App Store screens)
Run `scripts/fetch-design-references.sh` to download the App Store screenshots locally (gitignored) and compare against them every iteration.

| App | What we borrow | What we avoid |
|---|---|---|
| **WHOOP** | Big thick-stroke score rings with % in the center; uppercase, letter-spaced micro labels; metric rows with a tiny trend bar + ▲▼ delta; one insight paragraph + a "DIVE INTO MY SLEEP →" text link; deep blue-slate dark gradient | Too much data density on one screen |
| **Oura** | Editorial **serif** headlines for the coach's voice ("Rising heart health, with a dip in stress"); atmospheric gradient hero that matches the day's state; 2-column metric tiles; calm teal/indigo darks | Scenic photography (we use generative gradients instead) |
| **Bevel** | Three pillar rings at the top of Today (Strain / Recovery / Sleep); an AI chat with suggestion chips above the composer; airy light mode with white cards on a soft gray | Cartoonish mascot |
| **Cal AI** | Huge black numerals ("1250 calories left"), a single ring, minimal macro trio; photo scan with floating labels on the food; black capsule "Done" CTA; "Fix results" secondary | Generic white-only look in dark mode |
| **MacroFactor** | Pure-black canvas, bold white type, one white circle CTA ("Check In"); dense but legible log rows with emoji/food thumbnails and P/C/F inline | Overwhelming tab chrome |
| **Hevy / Strong** | Set rows: `PREV · KG · REPS · ✓`, completed rows tint, rest timer, PR badges | Bright blue "default iOS" look |
| **Runna / Strava** | Plan overview with weeks + color-coded session types; pace/distance big-number trios | Busy maps and social |
| **Ladder** | One loud accent on black, confident uppercase session titles, START WORKOUT full-width CTA | Neon overuse |

## 1. Brand
- **Name:** Atlas. **Promise:** "Your goal. Your team. 24/7."
- **Personality:** elite coach. Direct, warm, specific, never cheesy. No exclamation-point spam and no emoji in coach copy (one per message, max, and only when celebrating).
- **Logo mark:** a simple geometric mark. A circle (the world) resting on a horizon line / arc (the titan's shoulders). Render it in SwiftUI (`AtlasMark` view) and export it for the app icon.
- **App icon:** Obsidian background (#0B0D12 → #161A24 subtle radial), mark in warm white with a faint volt glow. Dark + tinted variants.

## 2. Color
Dark mode is the hero (the App Store screenshots are dark), and light mode must be just as polished.

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | #07080B | #F4F3EF (warm paper) | App background |
| `surface` | #12141A | #FFFFFF | Cards |
| `surfaceElevated` | #1A1D25 | #FFFFFF + shadow(0.06, y4, r16) | Sheets, popovers |
| `hairline` | white 8% | black 6% | 0.5pt separators/borders |
| `textPrimary` | #F5F5F2 | #0E0F12 | |
| `textSecondary` | white 62% | black 56% | |
| `textTertiary` | white 38% | black 36% | |
| `accent` (Volt) | #D4FF3F | #3B5A00 (text) / #C6F432 (fills) | Brand accent: progress, active states, the one thing to tap |
| `fuel` | #FFB547 | #E08A00 | Nutrition pillar |
| `train` | #FF6B4A | #E5482A | Training pillar |
| `sleep` | #8E8CFF | #5D5BE0 | Sleep pillar |
| `recovery` | #3EE0A8 | #13A877 | Recovery pillar (+ score color ramp: red #FF4D5E <34, amber #FFB547 34–66, green ≥67) |

Rules:
- One accent per screen region. Pillar colors appear only on that pillar's data (ring, chart, icon tint).
- Primary CTA: **solid capsule** in `textPrimary` with `bg`-colored label (white pill on black, black pill on paper), like Cal AI and MacroFactor. Volt is for progress, not buttons, except the single hero CTA on onboarding.
- Atmosphere: the Coach home header sits on a slow-moving `MeshGradient` (iOS 18+; `LinearGradient` fallback) tinted by recovery (green / amber / red at ~25% opacity over `bg`). Keep it subtle.

## 3. Typography
| Style | Font | Use |
|---|---|---|
| `display` | New York (`.serif`), 34/40 semibold | Coach greeting, onboarding headlines, insight headlines (Oura-style editorial) |
| `title` | SF Pro 22 semibold | Screen section titles |
| `headline` | SF Pro 17 semibold | Card titles |
| `body` | SF Pro 17 regular | Coach text, descriptions |
| `callout` | SF Pro 15 | Secondary text |
| `micro` | SF Pro 11–12 semibold, UPPERCASE, tracking +1.2 | Labels over numbers ("SLEEP PERFORMANCE", "PROTEIN LEFT") |
| `metricXL` | SF Pro Rounded 56–64 semibold, `monospacedDigit` | Hero numbers (calories left, score) |
| `metricL` | SF Pro Rounded 28–34 semibold | Tiles |
| `metricM` | SF Pro Rounded 20 semibold | Rows |
- Use semantic text styles (`.font(.system(.title2, design: .serif, weight: .semibold))`) so Dynamic Type works.
- Numbers animate with `.contentTransition(.numericText())`.
- Units are smaller and secondary: "**7**h **42**m", "**1,240** kcal".

## 4. Layout & spacing
- 4-pt grid. Allowed: 4, 8, 12, 16, 20, 24, 32, 40, 48.
- Screen horizontal padding 20. Section gap 32. Card padding 16 (20 for hero cards). Card radius 24 (`.continuous`), inner elements 14–16, chips/capsules full.
- Cards: `surface` fill + 0.5pt `hairline` border in dark; white + soft shadow in light. Use no gradients on cards except the hero.
- Max 3 type sizes per card.
- Lists use native `List`/`Form` for settings-type screens (insetGrouped) with our colors.

## 5. Components (DesignSystem/)
- `ScoreRing(value, color, lineWidth, label)`: thick round-capped ring (lineWidth = 10% of diameter), a track at 12% opacity, and the value centered in `metricXL/L`. Animate from 0 on appear (`.spring(duration: 1.0, bounce: 0.2)`).
- `PillarRingsRow`: three rings (Recovery / Sleep / Fuel) like Bevel and Whoop's top row, each tappable to its tab.
- `MacroBar(label, value, target, color)`: rounded 8pt bar, "**112** / 180 g".
- `MetricTile(icon, label, value, unit, delta, color)`: 2-column grid tile.
- `DirectiveRow(index, title, detail, pillar, action?)`: Game Plan items. A pillar-colored SF Symbol in a 32pt circle, headline + callout, and an optional trailing action chip.
- `ActionCard(kind, title, subtitle, primary, secondary)`: agentic proposals with brand logos rendered as SF Symbols + text (no third-party logos). Primary capsule "Book for 7:30" / "Order" / "Add to calendar". States: proposed → in progress (spinner) → done (checkmark with `symbolEffect(.bounce)` + success haptic).
- `InsightCard(headline (serif), body, linkTitle)`: Whoop/Oura-style insight with a text link.
- `ChatBubble`: coach messages left-aligned with **no bubble background** (editorial text with a small Atlas mark avatar). User messages are right-aligned in a `surfaceElevated` rounded bubble. Typing indicator: 3 pulsing dots.
- `Composer`: floating capsule (glass on iOS 26 via `.glassEffect()`, `.ultraThinMaterial` fallback) with a text field, mic glyph (dictation via keyboard), and a send button that morphs into active state. Suggestion chips scroll horizontally above it.
- `Hypnogram`: stepped stage chart (Awake / REM / Core / Deep) with stage colors from the sleep palette (tints of `sleep`).
- `EatingWindowBar`: 24h timeline with the eating window highlighted in `fuel` and a "now" needle, plus "Window closes in 2h 14m".
- `SegmentedPills`: custom capsule segmented control (7D / 30D / 90D).
- `PrimaryButton`, `SecondaryButton` (outline hairline capsule), `IconButton` (36pt circle).
- `EmptyState(symbol, title, body, cta)` for every list.

## 6. Navigation & structure
`TabView` with 5 tabs (SF Symbols): **Coach** (`sparkles`), **Fuel** (`fork.knife`), **Train** (`figure.strengthtraining.traditional`), **Sleep** (`moon.stars.fill`), **Progress** (`chart.line.uptrend.xyaxis`). On iOS 26 the tab bar is Liquid Glass automatically. Center "+" quick-log is done as a toolbar button on each tab (Cal AI/MacroFactor style) that opens a quick-log sheet: Snap meal / Log workout / Log sleep / Measurement.
- Large titles on Fuel/Train/Sleep/Progress; Coach uses a custom editorial header ("Good morning, Marcus" in serif) over the atmosphere gradient.
- Sheets use `.presentationDetents([.medium, .large])`, `.presentationCornerRadius(32)`, and `.presentationBackground(.thinMaterial)` where appropriate.

## 7. Motion & haptics
- Default animation: `.spring(duration: 0.45, bounce: 0.15)` (`.snappy` for small toggles).
- Rings and bars fill on appear. Numbers use `numericText`.
- Tab/scroll: hero header parallax + fade on scroll (`.scrollTransition`/`visualEffect`).
- Haptics via `.sensoryFeedback`: `.selection` on pickers, `.success` on log saved / action done, `.impact(weight: .light)` on set check, `.increase` on PR.
- **Pow** effects, used sparingly: `.changeEffect(.spray { Image(systemName: "star.fill") })` on PR, `.changeEffect(.shine)` on the plan-reveal CTA, `.transition(.movingParts.pop)` for checkmarks, `.conditionalEffect(.repeat(.glow(color:), every: 2.5), condition:)` on the "Coach is thinking" orb.
- Plan reveal (onboarding end): staggered reveal of kcal → macros → split → sleep target with `PhaseAnimator`.
- Respect Reduce Motion (`@Environment(\.accessibilityReduceMotion)`): no parallax or particle effects.

## 8. Copy guidelines
- Coach directives: imperative, numeric, short. ≤ 90 characters headline, ≤ 140 characters detail.
  - "Swap depth jumps for mobility + 20 min Zone 2" / "HRV is 18% below baseline after 5h 40m of sleep. Go light today and get the jump work back on Thursday."
- Use real names, times, and numbers. Never say "Lorem", "Sample", or "TBD" in UI.
- Labels are sentence case except `micro` labels (UPPERCASE).

## 9. Screen blueprints
**Coach (home)**: atmosphere header → serif greeting + date → goal chip ("Vertical 26.0″ → 30″ · 62 days · On track", which opens Progress) → `PillarRingsRow` → **Today's Game Plan** card (3–5 `DirectiveRow`s) → Action cards carousel (snap paging) → InsightCard ("Why today looks like this") → recent coach conversation preview + "Talk to Atlas" composer pinned at the bottom (tap → full chat).

**Coach chat**: full-screen, editorial coach messages, inline action cards, suggestion chips, memory button (brain icon) → "What Atlas remembers" sheet (facts / preferences / tasks with swipe to delete and add).

**Fuel**: big "1,240 kcal left" numeral with ring (Cal AI) → macro trio bars → EatingWindowBar → "Today" meals list (photo thumbnails, P/C/F inline) → 7-day chart. Toolbar camera button → **Snap** (full-screen camera/photo picker) → **Review** screen with the photo on top, floating detected-item labels, an itemized list with portion steppers, totals, and "Fix results" / black "Log meal" CTAs.

**Train**: "Today · Lower power" hero (Ladder-style uppercase title, blocks, "START WORKOUT" full-width) → this week strip (Mon–Sun session dots color-coded) → recent workouts → PR board. **Logger**: Hevy-style set table, sticky rest timer pill, finish summary with volume, PRs, and load.

**Sleep**: WHOOP-style big "Sleep 78%" ring + "7h 42m" → hypnogram → metric rows (Hours vs. needed, Consistency, Efficiency, Deep+REM) with mini bars → Recovery card (HRV, RHR deltas) → serif insight → "Tonight: be in bed by 10:45 PM" card with a reminder action → trends.

**Progress**: serif "26.0″ of 30″" headline + projection chart (baseline dot, actual line, dashed projection, target band) → "On pace for Nov 18 · 6 days early" → milestones → measurements history → Integrations → Settings.

**Onboarding**: full-bleed black, serif headlines, the large goal card grid with SF Symbol art, one question per screen, a progress hairline at the top, white capsule CTA at the bottom, and the plan reveal with animated numbers.

## 10. Taste review checklist (run on every screenshot)
1. Does the screen have one obvious focal point and one obvious next action?
2. Are all spacings from the grid? Are the edges aligned (20pt gutters)?
3. ≤ 3 font sizes per card; are numbers rounded and monospaced?
4. Is color used only for meaning (pillar/accent)? Is there no random blue?
5. Is the copy specific and short, with no truncation or awkward wrapping (check iPhone SE + XXL Dynamic Type)?
6. Do Dark and Light both look intentional, with contrast ≥ 4.5:1 for text?
7. Are the empty, loading, and error states designed?
8. Does it hold up side by side with the WHOOP / Oura / Cal AI references?
