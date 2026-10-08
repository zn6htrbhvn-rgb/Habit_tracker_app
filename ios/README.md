# ZenHabit for iPhone & iPad

A native SwiftUI version of the ZenHabit web app in this repo (`index.html` / `script.js` / `style.css`).
It has the same features, the same calm warm-stone look in light and dark mode, the same animations,
and the same saved-data format.

## Run it

Requirements: **Xcode 16 or newer**, iOS/iPadOS **17.0+**.

1. Open `ios/ZenHabit.xcodeproj`.
2. Pick an iPhone or iPad simulator and press **⌘R**.
3. To run on your own device, select the **ZenHabit** target → *Signing & Capabilities*, choose your Team,
   and change the bundle identifier (`app.zenhabit.ZenHabit`) to something unique.

Press **⌘U** to run the unit tests (streaks, progress math, heatmap levels, undo, web-data compatibility).

### Swift Playgrounds on iPad

Playgrounds can't open `.xcodeproj`, so `ios/ZenHabit.swiftpm` is the same app packaged as an App Playground.

1. Download this repo as a ZIP from GitHub (Code → Download ZIP) and unzip it in the Files app.
2. Open `ios/ZenHabit.swiftpm` (tap it, or open it from inside Swift Playgrounds 4.4+).
3. Tap **▶** to run. Needs iPadOS 17+.

Keep `ZenHabit.swiftpm` and `ZenHabit/` in sync if you edit either one.

## What's in it

| Web app | iOS app |
| --- | --- |
| Header with date, light/dark toggle (circular reveal), streak pill with flickering flame | `HeaderView`, `ThemeReveal` |
| "Today's progress" card: counting %, springy bar, messages, shimmer + glow at 100% | `ProgressCard` |
| Habits grouped into Morning / Afternoon / Evening with `done/total` counts | `ContentView`, `SectionHeader` |
| Habit card: tap the circle, swipe right to complete/undo, press and hold for options, "…" menu | `HabitCard` (+ haptics) |
| Completion effects: check pop, ring burst, icon bounce, color wash | `HabitCard` |
| One-time swipe tip with a "peek" of the first card | `SwipeHint`, `HabitCard` |
| Empty state with one-tap starter habits | `EmptyStateView` |
| New habit sheet: live preview, name validation with shake, time of day, 8 colors, 21 icons | `AddHabitSheet` |
| Habit menu: mark done / not done, delete | `HabitMenuSheet` + native context menu |
| Toasts with Undo and a countdown bar | `ToastView` |
| Confetti when every habit is done | `ConfettiView` |
| "Velocity Visualizer" 90-day heatmap with per-habit filter chips and a diagonal color ripple | `HeatmapView` |
| Staggered entrance animation on launch | `ContentView` (`fadeUpIn`) |
| Respects "Reduce Motion" | everywhere |

### iPad

- Narrow windows (Split View, Slide Over, portrait) use the single column, like the web app.
- Wide windows switch to two columns: habits on the left, progress and heatmap on the right.
- Hardware keyboard: **⌘N** for a new habit, **Return** to add, **Esc** to close sheets.
- Trackpad/mouse: right-click (two-finger click) a card for its menu.

## Differences from the web version

- **Fonts:** Fraunces and Inter become Apple's New York (serif) and SF Pro, so the text scales with Dynamic Type.
- **Icons:** Lucide icons become their closest SF Symbols. Saved habits still store the Lucide name
  (for example `"book-open"`), so data moves between the two apps unchanged.
- **Press and hold** opens the native iOS context menu. The "…" button opens the same menu sheet as the web.
- **Heatmap tooltips:** tap a day to see its details under the grid.
- **Storage:** habits are saved in `UserDefaults` under the same key and JSON shape as the web app's
  `localStorage` (`zenhabits_state_vanilla` → `{ "habits": [...] }`).

## Layout

```
ios/
├── ZenHabit.xcodeproj
├── ZenHabit/
│   ├── App/ZenHabitApp.swift        entry point
│   ├── Model/                       Habit, catalog (colors/icons/starters), day keys + streaks, HabitStore
│   ├── Design/                      theme tokens, shared components, circular theme reveal
│   ├── Views/                       every screen element
│   └── Assets.xcassets              app icon, accent color
└── ZenHabitTests/                   Swift Testing unit tests for HabitStore
```
