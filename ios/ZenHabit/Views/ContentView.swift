import SwiftUI
import Combine

/// The whole app on one screen. iPhone (and narrow iPad windows) get the web app's single
/// column; wide iPad windows put the habits on the left and progress + heatmap on the right.
struct ContentView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// "light", "dark", or "" to follow the system. Same key as the web app.
    @AppStorage("zenhabit_theme") private var themePreference = ""
    @AppStorage("zenhabit_swipe_hint_dismissed") private var hintDismissed = false

    @State private var showAddSheet = false
    @State private var form = HabitForm()
    @State private var menuTarget: HabitRef?
    @State private var toast: Toast?
    @State private var toastBumps = 0
    @State private var celebrations = 0
    @State private var confetti: ConfettiBurst?
    @State private var introVisible = false
    @State private var justAddedID: String?
    @State private var peekHabitID: String?
    @State private var frames = FrameBox()

    private static let introStep = 0.07

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                page(width: proxy.size.width)
                    .padding(.horizontal, gutter(for: proxy.size.width))
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) { glow }
            }
        }
        .background { Theme.bg.ignoresSafeArea() }
        .overlay { confettiLayer }
        .overlay(alignment: .bottom) { toastLayer }
        .sheet(isPresented: $showAddSheet) {
            AddHabitSheet(form: $form) { name in
                showAddSheet = false
                addHabit(name: name, iconName: form.icon, color: form.color, timeOfDay: form.time)
            }
            .preferredColorScheme(preferredScheme)
        }
        .sheet(item: $menuTarget) { target in
            menuSheet(for: target)
                .preferredColorScheme(preferredScheme)
        }
        .tint(Theme.accent)
        .preferredColorScheme(preferredScheme)
        .sensoryFeedback(.success, trigger: celebrations)
        .task(id: toast?.id) { await autoHideToast() }
        .onAppear { start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            store.refreshDate()
        }
    }

    // MARK: - Layout

    private func gutter(for width: CGFloat) -> CGFloat {
        width >= 700 ? 32 : 16
    }

    @ViewBuilder
    private func page(width: CGFloat) -> some View {
        let available = width - gutter(for: width) * 2
        if available >= 860 {
            wideLayout(contentWidth: min(available, 1100))
        } else {
            VStack(spacing: 32) {
                header
                progressCard
                habitsColumn
                heatmapCard
                footer
            }
            .frame(maxWidth: 640)
        }
    }

    private func wideLayout(contentWidth: CGFloat) -> some View {
        VStack(spacing: 32) {
            header
            HStack(alignment: .top, spacing: 32) {
                habitsColumn
                    .frame(maxWidth: .infinity, alignment: .top)
                VStack(spacing: 32) {
                    progressCard
                    heatmapCard
                    footer
                }
                .frame(width: min(440, contentWidth * 0.42))
            }
        }
        .frame(maxWidth: contentWidth)
    }

    /// The soft warm glow at the top of the page: a wide, flat ellipse centered just above it.
    private var glow: some View {
        EllipticalGradient(
            colors: [Theme.bgGlow, Theme.bgGlow.opacity(0)],
            center: UnitPoint(x: 0.5, y: 0.17),
            startRadiusFraction: 0,
            endRadiusFraction: 0.7
        )
        .frame(height: 1200)
        .scaleEffect(x: 2.4, y: 1)
        .padding(.top, -300)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Pieces

    private var header: some View {
        HeaderView(
            date: store.now,
            streak: store.globalStreak,
            isDark: colorScheme == .dark,
            introVisible: introVisible,
            onToggleTheme: { toggleTheme() },
            onThemeButtonFrame: { frames.themeButton = $0 }
        )
    }

    private var progressCard: some View {
        ProgressCard(
            percent: store.percent,
            done: store.doneTodayCount,
            total: store.habits.count,
            message: store.progressMessage,
            celebrations: celebrations
        )
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            frames.progressCard = frame
        }
        .fadeUpIn(introVisible, delay: 2 * Self.introStep)
    }

    private var showHint: Bool { !hintDismissed && !store.habits.isEmpty }

    private var habitsColumn: some View {
        VStack(spacing: 32) {
            actionRow
                .padding(.bottom, -12)
            if showHint {
                SwipeHint(onDismiss: { dismissHint() })
                    .fadeUpIn(introVisible, delay: 4 * Self.introStep)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            habitsList
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Text("Your habits")
                .font(.display(.title2))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                openAddSheet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("New habit")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut("n", modifiers: .command)
            .hoverEffect(.lift)
        }
        .fadeUpIn(introVisible, delay: 3 * Self.introStep)
    }

    @ViewBuilder
    private var habitsList: some View {
        if store.habits.isEmpty {
            EmptyStateView(onStarter: { addStarter($0) }, onCreate: { openAddSheet() })
                .fadeUpIn(introVisible, delay: 5 * Self.introStep)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            let order = introOrder
            VStack(spacing: 32) {
                ForEach(TimeOfDay.allCases) { slot in
                    let items = store.habits(in: slot)
                    if !items.isEmpty {
                        section(slot, items: items, order: order)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
        }
    }

    private func section(_ slot: TimeOfDay, items: [Habit], order: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(slot: slot, done: items.filter(store.isDoneToday).count, total: items.count)
                .fadeUpIn(introVisible, delay: introDelay(order[slot.rawValue]))
            VStack(spacing: 12) {
                ForEach(items) { habit in
                    card(for: habit)
                        .fadeUpIn(introVisible, delay: introDelay(order[habit.id]))
                        .transition(cardTransition)
                }
            }
        }
    }

    private func card(for habit: Habit) -> some View {
        HabitCard(
            habit: habit,
            isDone: store.isDoneToday(habit),
            streak: store.streak(for: habit),
            justAdded: justAddedID == habit.id,
            peek: peekHabitID == habit.id,
            onToggle: { toggle(habit.id) },
            onMore: { menuTarget = HabitRef(id: habit.id) },
            onDelete: { delete(habit.id) }
        )
    }

    /// New cards grow in; deleted ones slide right and fade while the gap closes.
    private var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .offset(x: 28)).combined(with: .scale(scale: 0.97))
        )
    }

    private var heatmapCard: some View {
        let listEnd = introOrder.values.max().map { $0 + 1 } ?? 6
        return HeatmapView(
            heatmap: store.heatmap(),
            habits: store.habits,
            filter: store.selectedHeatmapHabit?.id ?? HabitStore.allFilter,
            introVisible: introVisible,
            introDelay: introDelay(listEnd) + 0.2,
            onSelectFilter: { id in
                withAnimation(Motion.ease(0.3)) { store.heatmapFilter = id }
            }
        )
        .fadeUpIn(introVisible, delay: introDelay(listEnd))
    }

    private var footer: some View {
        Text("Small steps, every day.")
            .font(.system(.callout, design: .serif))
            .italic()
            .foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .fadeUpIn(introVisible, delay: introDelay((introOrder.values.max() ?? 5) + 2))
    }

    @ViewBuilder
    private func menuSheet(for target: HabitRef) -> some View {
        if let habit = store.habits.first(where: { $0.id == target.id }) {
            HabitMenuSheet(
                habit: habit,
                isDone: store.isDoneToday(habit),
                // Let the sheet start sliding away before the card reacts.
                onToggle: { runAfter(reduceMotion ? 0 : 0.25) { toggle(habit.id) } },
                onDelete: { runAfter(reduceMotion ? 0 : 0.25) { delete(habit.id) } }
            )
        }
    }

    @ViewBuilder
    private var confettiLayer: some View {
        if let confetti {
            ConfettiView(burst: confetti)
                .id(confetti.id)
                .task(id: confetti.id) {
                    try? await Task.sleep(for: .seconds(2.4))
                    if self.confetti?.id == confetti.id { self.confetti = nil }
                }
        }
    }

    private var toastLayer: some View {
        ZStack {
            if let toast {
                ToastView(toast: toast, bump: toastBumps, onUndo: { performUndo() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Intro choreography

    /// Order in which the time headers and cards rise in on launch (after header, progress, title, tip).
    private var introOrder: [String: Int] {
        var order: [String: Int] = [:]
        var index = showHint ? 5 : 4
        for slot in TimeOfDay.allCases {
            let items = store.habits(in: slot)
            guard !items.isEmpty else { continue }
            order[slot.rawValue] = index
            index += 1
            for habit in items {
                order[habit.id] = index
                index += 1
            }
        }
        return order
    }

    private func introDelay(_ index: Int?) -> Double {
        Double(index ?? 0) * Self.introStep
    }

    // MARK: - Actions

    private var preferredScheme: ColorScheme? {
        switch themePreference {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    private func start() {
        guard !introVisible else { return }
        store.refreshDate()
        if showHint && !reduceMotion {
            peekHabitID = store.firstHabitID
            runAfter(3) { peekHabitID = nil }
        }
        introVisible = true
    }

    private func toggleTheme() {
        let next = colorScheme == .dark ? "light" : "dark"
        let button = frames.themeButton
        guard !reduceMotion, button != .zero else {
            themePreference = next
            return
        }
        // Circular reveal growing out of the toggle button.
        ThemeReveal.perform(from: CGPoint(x: button.midX, y: button.midY)) {
            themePreference = next
        }
    }

    private func openAddSheet() {
        form.name = ""
        showAddSheet = true
    }

    private func dismissHint() {
        withAnimation(Motion.ease(0.5)) { hintDismissed = true }
    }

    private func toggle(_ id: String) {
        let before = store.percent
        withAnimation(Motion.ease(0.4)) { store.toggle(id) }
        if before < 100 && store.percent == 100 { celebrate() }
    }

    private func celebrate() {
        celebrations += 1
        showToast("Every habit done today 🌿")
        guard !reduceMotion else { return }
        var colors: [String] = []
        for habit in store.habits where !colors.contains(habit.color) {
            colors.append(habit.color)
        }
        confetti = ConfettiBurst(originY: frames.progressCard.midY, colors: colors)
    }

    private func addStarter(_ starter: StarterHabit) {
        addHabit(name: starter.name, iconName: starter.iconName, color: starter.color, timeOfDay: starter.timeOfDay)
    }

    private func addHabit(name: String, iconName: String, color: String, timeOfDay: TimeOfDay) {
        let habit = Habit(name: name, iconName: iconName, color: color, timeOfDay: timeOfDay)
        justAddedID = habit.id
        withAnimation(Motion.ease(0.6)) { store.add(habit) }
        showToast("Added “\(name)”")
    }

    private func delete(_ id: String) {
        guard let removed = withAnimation(Motion.ease(0.55), { store.remove(id) }) else { return }
        showToast("Deleted “\(removed.habit.name)”") {
            justAddedID = removed.habit.id
            withAnimation(Motion.ease(0.6)) { store.restore(removed.habit, at: removed.index) }
        }
    }

    private func showToast(_ message: String, undo: (() -> Void)? = nil) {
        let replacing = toast != nil
        withAnimation(Motion.snappy) {
            toast = Toast(message: message, undo: undo)
        }
        // A toast replacing another one gives a small bump instead of popping in again.
        if replacing { toastBumps += 1 }
        AccessibilityNotification.Announcement(message).post()
    }

    private func performUndo() {
        let undo = toast?.undo
        withAnimation(Motion.snappy) { toast = nil }
        undo?()
    }

    private func autoHideToast() async {
        guard let current = toast else { return }
        try? await Task.sleep(for: .seconds(current.duration))
        guard !Task.isCancelled, toast?.id == current.id else { return }
        withAnimation(Motion.snappy) { toast = nil }
    }
}

/// Which habit the "…" menu is open for.
struct HabitRef: Identifiable, Equatable {
    let id: String
}

#Preview("Light") {
    ContentView()
        .environment(HabitStore(defaults: UserDefaults(suiteName: "preview-light") ?? .standard))
}

#Preview("Dark") {
    ContentView()
        .environment(HabitStore(defaults: UserDefaults(suiteName: "preview-dark") ?? .standard))
        .preferredColorScheme(.dark)
}
