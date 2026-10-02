# Atlas — Product Requirements Document

**Version:** 1.0 (TestFlight beta)
**Platform:** iOS 17+ (iPhone), enhanced on iOS 26 with Apple Intelligence
**Status:** In development

---

## 1. Vision

General consumer agents try to do everything. **Atlas** is a *specialized* consumer agent with one job: get you to **one concrete physical outcome**, like "+10 inches on my vertical", "a 30-inch waist", "bigger glutes", "a sub-20 5K", or "a 405 lb deadlift".

The best athletes in the world have a team: a strength coach, a nutritionist, a sleep specialist, and a chief of staff who knows their schedule. Atlas gives everyone that **LeBron-level concierge**, available 24/7. It watches your sleep, training, nutrition, and calendar, remembers your long-term plan, and tells you exactly what to do today. Then it does the logistics for you: booking the restaurant, ordering lunch at the right time, and putting the workout on your calendar.

Being specialized doesn't mean being less capable. Atlas is still a full agent with memory, tools, and access to your data. What sets it apart is that it ranks everything against your goal.

## 2. Target users

| Persona | Outcome | Pain today |
|---|---|---|
| **"The Hooper"**, Marcus, 24, rec-league basketball | +6" vertical in 16 weeks | Generic YouTube programs, no idea how sleep/food affect jumping |
| **"The Rebuilder"**, Priya, 33, product manager | Waist 34" → 29" before her wedding | 4 apps (calories, gym, sleep, calendar) that don't talk to each other |
| **"The Glute Builder"**, Sam, 27 | Visibly bigger glutes, +40 lb hip thrust | Doesn't know how to progress or eat for growth |
| **"The Racer"**, Dev, 38 | Sub-20 5K | Overtrains, ignores recovery |

Common thread: they're motivated, they already own an iPhone and often an Apple Watch, Whoop, Oura, or Eight Sleep, and they'd pay for a coach but can't afford a human one.

## 3. Product principles

1. **Outcome first.** Every screen answers: "Am I on track for my goal, and what do I do next?"
2. **The coach is the interface.** Logging screens exist, but the Coach is the home screen and the main way you talk to the app.
3. **Proactive, not reactive.** Atlas reads context (bad sleep, dinner reservation, travel, a missed workout) and adjusts the plan before you ask.
4. **Zero-friction logging.** Snap a photo for a meal, use one tap for a set, and let sleep sync automatically.
5. **Tactical, specific, short.** "Eat 45 g protein before 1 pm, keep dinner under 700 kcal, skip box jumps today. Do 3×5 pogo hops instead." No platitudes.
6. **Premium feel.** It should look and feel like a $30/month product: calm, confident, fast, and beautiful.
7. **Private by default.** On-device intelligence first. Health data never leaves the phone unless the user opts in.

## 4. Scope — v1 (TestFlight)

### 4.1 Onboarding (≤ 90 seconds)
1. **Welcome**: brand moment ("Your goal. Your team. 24/7.").
2. **Pick your outcome**: goal templates shown as large cards:
   - Jump higher (vertical, inches)
   - Slim waist (waist, inches)
   - Build glutes (hip thrust 1RM / glute measurement)
   - Lose fat (body weight)
   - Build muscle (body weight / lean mass)
   - Get stronger (big-3 lift 1RM)
   - Run faster (5K / 10K time)
   - Custom (free text + metric + unit)
3. **Baseline → Target → Deadline**: current value, target value, target date (date picker with suggested realistic timeline).
4. **About you**: sex, age, height, weight, activity level, training experience, days/week available, equipment (gym / home / none).
5. **Fuel preferences**: diet style (no preference, high-protein, vegetarian, vegan, pescatarian, keto), optional intermittent fasting window (e.g. 16:8, 12 pm–8 pm), allergies.
6. **Connect**: Apple Health (sleep, workouts, steps, HRV, resting HR, weight; this covers Whoop, Oura, Eight Sleep, Garmin, and Apple Watch, which all sync to Apple Health), Calendar, Notifications. Every one is optional and skippable.
7. **Your plan**: animated reveal of the generated plan: daily calories + macros, weekly training split, sleep target, and the first week's milestones. CTA: "Meet your coach".

A **"Explore with sample data"** option on the welcome screen loads a realistic demo persona so reviewers and TestFlight testers can see a full app right away.

### 4.2 Coach (Home tab)
The main interface.
- **Greeting header**: "Good morning, Marcus", goal progress chip ("Vertical 24.5″ → 30″ · 62 days left · On track").
- **Today's Game Plan** (hero card): 3–5 prioritized, tactical directives generated from all context, for example:
  - "Sleep was 5h 40m (score 58). Swap today's depth jumps for low-intensity mobility + 20 min Zone 2."
  - "Dinner at Nobu at 7:30 pm is on your calendar. Keep lunch light: ~550 kcal, 45 g protein. Order suggestion ready."
  - "Eating window opens at 12:00. First meal: 40 g+ protein."
- **Readiness strip**: Recovery %, Sleep score, Fuel remaining, Training load, shown as compact rings/gauges.
- **Action cards** (agentic): proposed actions the user approves with one tap:
  - **Reserve a table**: restaurant suggestion with a healthy order guide; opens OpenTable/Resy with party size + time prefilled.
  - **Order a meal**: DoorDash/Uber Eats search deep link timed to the eating window, with a suggested macro-fit order.
  - **Schedule workout**: writes an event to the user's calendar (EventKit) at a free slot.
  - **Set reminder**: local notification (e.g. "Eating window closes in 30 min", "Wind down: lights out in 45 min").
- **Chat with your coach**: full conversational agent with:
  - **Long-horizon memory**: Atlas stores facts ("knee tweaks on deep squats", "girlfriend is vegetarian", "travels to NYC every other Monday") and open tasks ("re-test vertical on Nov 1"). Memory is viewable/editable in a "What Atlas remembers" sheet.
  - **Tools**: read today's nutrition, training, sleep, calendar, goal; log a meal; log a workout; add memory; create calendar event; schedule reminder; propose a reservation or delivery order.
  - Suggested prompts ("I have a work dinner tonight", "I slept badly — what should I change?", "Order me lunch that fits my macros", "Am I on track?").
- **Weekly check-in**: every 7 days, the coach summarizes adherence, trend vs. target, and adjusts the plan (calories ±, volume ±).

### 4.3 Fuel (Nutrition tab)
- **Daily rings**: calories remaining + protein / carbs / fat bars against targets.
- **Eating window timeline**: shows the fasting/feeding window with a "now" marker and a countdown.
- **Log a meal**:
  - **Snap**: camera or photo library → AI recognition → itemized estimate (name, portion, kcal, P/C/F) with confidence → user adjusts portions with steppers → save. (Like Cal AI or MacroFactor.)
  - **Describe**: type "2 eggs, toast with avocado, black coffee" → parsed estimate.
  - **Search**: built-in food database (≥ 250 common foods and restaurant staples) with serving sizes.
  - **Quick add**: calories + macros manually.
- **Meal list** grouped by meal with photo thumbnails, swipe to delete, tap to edit.
- **Trends**: 7/30-day calories and protein vs. target (Swift Charts).

### 4.4 Train (Activity tab)
- **Today's session** from the goal-specific program (e.g. Vertical: plyometrics + strength + mobility blocks; Waist: strength + conditioning + steps), with exercises, sets × reps, and coaching cues.
- **Log strength workouts** (like Hevy or Strong): exercise picker (library ≥ 80 exercises, grouped by muscle), set rows (weight × reps, RPE), check off sets, auto rest timer with haptics, previous-session values shown inline, PR detection + celebration.
- **Log cardio** (like Strava): run / ride / swim / row / walk with duration, distance, auto-computed pace, and optional HR.
- **Log sport**: basketball, soccer, tennis, climbing, etc. with duration + RPE → training load.
- **Import**: workouts from Apple Health (Apple Watch, Strava, Whoop all sync there).
- **History**: calendar heatmap + list; weekly volume and load chart; PR board.

### 4.5 Sleep & Recovery tab
- **Last night**: total sleep, time in bed, efficiency, stages (Awake/REM/Core/Deep) hypnogram, bed/wake times.
- **Sleep score** (0–100) and **Recovery score** (0–100), computed from sleep duration vs. need, consistency, HRV vs. baseline, and resting HR vs. baseline.
- **Sleep need tonight** (base need + strain debt) and a recommended bedtime based on tomorrow's first calendar event.
- **Manual log** if no wearable is connected (bedtime, wake time, quality 1–5).
- **Trends**: 7/30-day sleep duration, consistency, HRV.

### 4.6 Progress (You tab)
- **Goal hero**: baseline → current → target with a projected-date line chart ("At this pace you'll hit 30″ on Nov 18 — 6 days early").
- **Log measurement** (vertical, waist, weight, lift 1RM, run time), quick-add from the hero.
- **Milestones**: auto-generated checkpoints along the way.
- **Integrations**: status of Apple Health, Calendar, Notifications; info on Whoop/Oura/Eight Sleep/Garmin via Apple Health.
- **Settings**: units (imperial/metric), edit profile and targets, eating window, coach tone (Direct / Encouraging / Data-nerd), AI engine status, privacy, reset/sample data, about.

## 5. Out of scope for v1
- Direct Whoop/Oura/Eight Sleep APIs (covered through Apple Health).
- Fully autonomous checkout on OpenTable/DoorDash. v1 deep-links with prefilled parameters and suggested orders; the user confirms in the partner app.
- Email access / server-side computer use (needs backend + OAuth; planned for v2).
- Social, Android, Apple Watch app, hardware.

## 6. Success metrics (beta)
- Onboarding completion ≥ 80%.
- D7 retention ≥ 40%; ≥ 4 days/week with ≥ 1 log.
- ≥ 60% of days where the Game Plan is viewed.
- ≥ 25% of proposed action cards accepted.
- Qualitative: testers describe it as "like having a coach".

## 7. Functional acceptance criteria (v1)
| # | Requirement | Acceptance |
|---|---|---|
| F1 | Goal onboarding | User can pick a template or custom goal, enter baseline/target/date, and see a generated plan with kcal + macros + weekly split |
| F2 | Sample data | "Explore with sample data" loads ≥ 14 days of meals, workouts, sleep, and measurements, and every tab looks populated |
| F3 | Game Plan | Home shows ≥ 3 context-aware directives that change with sleep score, calendar events, eating window, and training schedule |
| F4 | Coach chat | User can chat; responses reference their real data; coach can log meals/workouts and add memories through tools |
| F5 | Memory | Facts and tasks persist across launches, are viewable/editable/deletable |
| F6 | Agent actions | Reserve-table, order-meal, schedule-workout, and set-reminder cards work (deep link opens / event created / notification scheduled) |
| F7 | Food photo | Taking or choosing a photo yields an itemized editable estimate and saves to the log |
| F8 | Food text/search/quick | All three paths log food and update rings immediately |
| F9 | Strength logging | Create a workout, add exercises, log sets, rest timer runs, PRs detected, saved to history |
| F10 | Cardio/sport logging | Log with duration/distance/RPE; pace and load computed |
| F11 | Sleep | Shows last night stages + sleep/recovery scores from HealthKit or manual entry |
| F12 | Apple Health | Read permission request; imports sleep, workouts, HRV, RHR, weight, steps when granted; app works fully when denied |
| F13 | Progress | Log a measurement; chart shows baseline→target with projection |
| F14 | Settings | Units, profile, eating window, coach tone, reset all persist |
| F15 | Quality | No crashes; Dark and Light mode; Dynamic Type up to XXL usable; VoiceOver labels on primary controls |
| F16 | Release | Archive build succeeds; app icon, launch screen, privacy manifest, usage strings, version/build set; Fastlane `beta` lane ready |
