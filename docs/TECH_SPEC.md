# Atlas — Technical Specification

## 1. Stack
| Concern | Choice |
|---|---|
| Language / UI | Swift 6 (strict concurrency where practical), SwiftUI |
| Min OS | iOS 17.0 (iPhone). iOS 26 features (Liquid Glass, Foundation Models) gated with `#available` |
| Persistence | SwiftData (`@Model`), with a single `ModelContainer` |
| Charts | Swift Charts |
| Health | HealthKit (read: sleepAnalysis, workouts, HRV SDNN, restingHeartRate, bodyMass, stepCount, activeEnergyBurned; write: dietaryEnergyConsumed + macros, workouts, bodyMass) |
| Calendar | EventKit (full access for reading today's events; writing workouts) |
| Notifications | UserNotifications (local) |
| On-device AI | `FoundationModels` (`LanguageModelSession` + `Tool`) on iOS 26 when `SystemLanguageModel.default.availability == .available` |
| Image AI | Vision `VNClassifyImageRequest` (on-device) → food DB mapping; optional cloud vision (see §6) |
| Effects | [Pow](https://github.com/EmergeTools/Pow) (MIT) via SPM for delight effects; native `symbolEffect`, `contentTransition(.numericText())`, `PhaseAnimator`, `sensoryFeedback` |
| Project | XcodeGen `project.yml` → generated `Atlas.xcodeproj` (committed so it opens without XcodeGen) |
| Release | Fastlane (`beta` lane) + GitHub Actions workflow (`workflow_dispatch`) for TestFlight |

## 2. Repository layout
```
/project.yml                     XcodeGen spec
/Atlas.xcodeproj                 generated, committed
/Atlas/
  App/            AtlasApp.swift, RootView.swift, AppState.swift, DeepLinks
  DesignSystem/   Theme.swift (colors, type, spacing, radii), components/*
  Models/         SwiftData models + value types
  Services/       HealthKitService, CalendarService, NotificationService, KeychainStore
  Engines/        NutritionEngine, ProgramGenerator, ScoreEngine, GamePlanEngine, ProjectionEngine
  Coach/          CoachAgent protocol, FoundationModelsCoach, RuleBasedCoach, RemoteLLMCoach, CoachTools, MemoryStore
  Food/           FoodDatabase (JSON resource), FoodRecognizer, FoodTextParser
  Actions/        ActionService (reservation / delivery / calendar / reminder)
  Features/
    Onboarding/   Welcome, GoalPicker, Baseline, AboutYou, Fuel prefs, Connect, PlanReveal
    Coach/        CoachHomeView, GamePlanCard, ReadinessStrip, ActionCardView, CoachChatView, MemorySheet
    Fuel/         FuelView, EatingWindowView, LogMealSheet (Snap/Describe/Search/Quick), MealDetail
    Train/        TrainView, TodaySessionCard, WorkoutLoggerView, ExercisePicker, RestTimer, CardioLogSheet, SportLogSheet, HistoryView
    Sleep/        SleepView, Hypnogram, ScoreGauge, ManualSleepSheet
    Progress/     ProgressView (named GoalProgressView), MeasurementSheet, SettingsView, IntegrationsView
  Resources/      Assets.xcassets (AppIcon, colors), FoodDatabase.json, ExerciseLibrary.json, PrivacyInfo.xcprivacy, Info.plist, Atlas.entitlements
  SampleData/     SampleDataSeeder.swift
/AtlasTests/      unit tests for engines, parsers, coach intents
/AtlasUITests/    onboarding + screenshot tour (used by the review loop)
/fastlane/        Fastfile, Appfile
/.github/workflows/ ios-ci.yml (build+test), testflight.yml (manual)
/scripts/         screenshots.sh, archive-check.sh
/docs/            PRD.md, TECH_SPEC.md, DESIGN.md, screenshots/
```

## 3. Data model (SwiftData)
```swift
@Model UserProfile { name, sex, birthYear, heightCm, weightKg, activityLevel, experience, trainingDaysPerWeek, equipment, dietStyle, allergies:[String], fastingStartMinutes:Int?, fastingEndMinutes:Int?, unitSystem, coachTone, createdAt, onboardingComplete }
@Model Goal { kind: GoalKind, title, metric: GoalMetric, unit, baseline: Double, target: Double, startDate, targetDate, isActive }
@Model Measurement { date, metric, value, note? }
@Model PlanSnapshot { createdAt, kcalTarget, proteinG, carbsG, fatG, sleepTargetMin, weeklySplit: [PlannedSession] (Codable), rationale }
@Model MealEntry { date, mealType, title, photo: Data? (@Attribute(.externalStorage)), items:[FoodItem] (Codable), source: .photo/.text/.search/.quick/.coach }
struct FoodItem: Codable { name, servingDescription, quantity, kcal, protein, carbs, fat, confidence? }
@Model Workout { date, kind: .strength/.cardio/.sport/.mobility, title, durationSec, distanceM?, avgHR?, rpe?, load, exercises:[ExerciseLog] (Codable), source: .manual/.health }
struct ExerciseLog: Codable { exerciseId, name, sets:[SetLog] }   struct SetLog: Codable { weightKg, reps, rpe?, done, isPR }
@Model SleepSession { start, end, stages:[SleepStageSegment] (Codable), hrvMs?, restingHR?, quality?, source }
@Model CoachMessage { date, role: .user/.coach, text, actionPayloads:[CoachAction] (Codable) }
@Model MemoryItem { createdAt, kind: .fact/.preference/.task, text, dueDate?, isDone }
struct CoachAction: Codable, Identifiable { id, kind: .reserveTable/.orderMeal/.scheduleWorkout/.setReminder/.logMeal, title, subtitle, params:[String:String], status }
```

## 4. Engines (pure Swift, unit-tested)
- **NutritionEngine**: Mifflin-St Jeor BMR × activity factor = TDEE; goal adjustment (fat loss −20%, waist −20%, muscle/glutes +10%, vertical/strength/run maintenance ±0–5%); protein 1.8–2.2 g/kg, fat 0.8 g/kg, carbs = remainder. Clamp to safe floors (≥1,200 kcal F / ≥1,500 kcal M).
- **ProgramGenerator**: goal kind × days/week × equipment → weekly split of `PlannedSession`s (title, focus, blocks of exercises with sets×reps and cues). Program templates per goal kind (vertical: plyo+lower strength+mobility; glutes: hip thrust/RDL/split-squat emphasis 3×/wk; waist/fat-loss: full-body strength + Zone 2 + steps target; strength: 5/3/1-style; run: easy/tempo/intervals/long).
- **ScoreEngine**: sleepScore = 50%·durationVsNeed + 20%·efficiency + 15%·deep+REM share + 15%·consistency (bedtime SD). recoveryScore = 40%·sleepScore + 35%·HRV z-score vs 14-day baseline + 25%·RHR vs baseline (fallback: sleep-only). Training load = duration(min) × RPE (sRPE) with acute:chronic ratio.
- **GamePlanEngine**: rule-based context → ranked `Directive`s (title, detail, pillar, priority, optional `CoachAction`). Inputs: last sleep + recovery, today's planned session, today's calendar events (keyword detection: dinner, lunch, drinks, flight, reservation, restaurant names, "@ <restaurant>"), eating window + current time, calories/protein remaining, days to goal + projection status. When FoundationModels is available, the rule-based directives are passed to the LLM to rewrite in the user's chosen coach tone. The facts always come from the engine.
- **ProjectionEngine**: linear regression over measurements → projected date to hit target; on-track/ahead/behind status.

## 5. Coach agent
```swift
protocol CoachAgent { func respond(to text: String, context: CoachContext) async throws -> CoachReply }  // CoachReply { text, actions:[CoachAction], memoryWrites:[MemoryItem], logs:[LoggedEntity] }
```
- **FoundationModelsCoach** (iOS 26+, if available): `LanguageModelSession(tools: [...], instructions:)` with tools `GetTodaySummary`, `GetGoalStatus`, `LogMeal`, `LogWorkout`, `Remember`, `ProposeReservation`, `ProposeDeliveryOrder`, `ScheduleWorkout`, `SetReminder`. Instructions embed the profile, goal, plan, top memories, and tone. Stream responses into the chat bubble.
- **RemoteLLMCoach** (optional): OpenAI-compatible chat completions with tool calling, used only if the user pastes an API key in Settings → AI Engine (stored in Keychain). Disabled by default.
- **RuleBasedCoach** (always-available fallback): intent classifier (keywords + regex) for: status/on-track, bad sleep, dinner/restaurant, order food/lunch, log meal ("I ate …" → FoodTextParser), log workout, remember ("remember that …"), reschedule, motivation, plan explanation, generic. It composes tactical, data-grounded replies from the engines and attaches action cards. It must feel smart: reference real numbers, times, and memories.
- **MemoryStore**: extracts memories automatically from phrases ("I have/I'm/my … knee", "girlfriend is vegetarian", "remember …", "every Monday …") and via the `Remember` tool. Top-N memories are injected in context.

## 6. Food recognition
1. If a remote key is configured: send a downscaled JPEG to a vision model with a JSON schema prompt → `[FoodItem]`.
2. Otherwise (default): Vision `VNClassifyImageRequest` → take food-related labels with confidence > 0.1 → map to `FoodDatabase` entries (synonym table) → default portions → itemized estimate with confidence. If nothing matches, fall back to the "Describe" flow prefilled with the top label.
3. The user always reviews and adjusts the result (portion stepper ×0.5…×3, swap item, delete, add).

`FoodTextParser`: quantity + unit + food name parsing ("2 eggs", "1 cup rice", "200g chicken breast", "a banana") against the DB with fuzzy matching.

## 7. Agent actions
| Action | Implementation |
|---|---|
| Reserve table | Build `https://www.opentable.com/s?covers={n}&dateTime={ISO}&term={query}` (or Resy `https://resy.com/cities/{city}?date=…&seats=…`), `openURL`. Show a "What to order" guide that fits the remaining macros |
| Order meal | DoorDash `https://www.doordash.com/search/store/{query}/` / Uber Eats search URL, with a suggested order list; optionally schedule a reminder for the window opening |
| Schedule workout | EventKit: find the first free 60-min slot in 6–21h today/tomorrow → `EKEvent` with title + notes (session blocks) |
| Set reminder | `UNCalendarNotificationTrigger` |
| Log meal | Inserts a `MealEntry` (source `.coach`) |
Each action card has states: proposed → done / dismissed, persisted in `CoachMessage.actionPayloads`.

## 8. Integrations & permissions
- Request permissions just in time (onboarding Connect step, or first use). The app must be fully functional when every permission is denied.
- HealthKit import runs on launch + pull-to-refresh: last 30 days of sleep, workouts, HRV, RHR, weight, steps. Deduplicate by HK UUID.
- Whoop / Oura / Eight Sleep / Garmin: shown in Integrations as "via Apple Health" with setup instructions.

## 9. Sample data
`SampleDataSeeder` creates persona "Marcus" (vertical goal 24.5″ → 30″, 16 weeks, 6 weeks in), 21 days of meals with realistic macros, workouts (plyo/strength/basketball/Zone 2), sleep with stages + HRV/RHR variance (including one bad night = today), measurements trending up, memories (knee, girlfriend vegetarian, plays pickup Thursdays), and synthetic calendar context ("Dinner at Nobu 7:30 PM") used when Calendar access isn't granted. Launch argument `-AtlasSampleData YES` seeds and skips onboarding (used by UI tests / screenshots). `-AtlasResetOnboarding YES` resets the app.

## 10. Quality gates
- `xcodebuild test` passes (unit + UI).
- No compiler warnings in app target (best effort), no runtime purple warnings in the main flows.
- Screenshot tour (`scripts/screenshots.sh`) produces Light + Dark screenshots of every primary screen on iPhone 17 Pro (or the latest available) and iPhone SE-size device.
- `scripts/archive-check.sh`: `xcodebuild archive -scheme Atlas -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` succeeds.

## 11. Release / TestFlight
- Bundle ID `com.jiayanl.atlas` (change in `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`), Display name **Atlas**, `MARKETING_VERSION` 1.0.0, `CURRENT_PROJECT_VERSION` 1.
- Signing: Automatic. `DEVELOPMENT_TEAM` comes from `Config/Signing.xcconfig` (gitignored local override `Config/Signing.local.xcconfig`).
- Entitlements: HealthKit.
- Info.plist: `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSCalendarsWriteOnlyAccessUsageDescription`, `ITSAppUsesNonExemptEncryption = NO`, `LSApplicationQueriesSchemes` [doordash, opentable, resy, ubereats], `UILaunchScreen` with brand background color.
- `PrivacyInfo.xcprivacy`: no tracking; accessed API `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1); collected data types: Health & Fitness (app functionality, not linked to tracking).
- AppIcon: single 1024×1024 PNG (no alpha), plus dark/tinted variants.
- Fastlane `beta`: `app_store_connect_api_key(key_id: ENV["ASC_KEY_ID"], issuer_id: ENV["ASC_ISSUER_ID"], key_content: ENV["ASC_KEY_P8"])` → `increment_build_number` → `build_app(scheme: "Atlas", export_method: "app-store")` → `upload_to_testflight(skip_waiting_for_build_processing: true)`.
- `.github/workflows/testflight.yml`: `workflow_dispatch` on `macos-15`, same secrets, runs `bundle exec fastlane beta`.
