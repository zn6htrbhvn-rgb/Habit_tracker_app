import SwiftUI

/// What the "New habit" form remembers between openings (the name is cleared each time).
struct HabitForm: Equatable {
    var name = ""
    var time: TimeOfDay = .morning
    var color = HabitPalette.colors[0].hex
    var icon = HabitIcon.all[0]
}

/// The "New habit" sheet: a bottom sheet on iPhone, a centered card on iPad.
struct AddHabitSheet: View {
    @Binding var form: HabitForm
    /// Called with the trimmed name once it's valid.
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var showError = false
    @State private var shakes = 0
    @State private var appeared = false
    @State private var iconSwaps = 0
    @State private var timeTaps: [TimeOfDay: Int] = [:]
    @State private var iconTaps: [String: Int] = [:]

    private static let maxNameLength = 60

    private var tint: HabitTint { HabitTint(hex: form.color) }
    private var trimmedName: String { form.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                preview.stagger(appeared, 0)
                nameField.stagger(appeared, 1)
                timePicker.stagger(appeared, 2)
                colorPicker.stagger(appeared, 3)
                iconPicker.stagger(appeared, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions.stagger(appeared, 5)
        }
        .background { Theme.surface.ignoresSafeArea() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.surface)
        .sensoryFeedback(.error, trigger: shakes)
        .onAppear { appeared = true }
        .task {
            // Let the sheet finish sliding in before the keyboard comes up.
            try? await Task.sleep(for: .milliseconds(350))
            nameFocused = true
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("New habit")
                .font(.display(.title2))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface, in: Circle())
                    .overlay { Circle().strokeBorder(Theme.border, lineWidth: 1) }
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .hoverEffect(.highlight)
            .accessibilityLabel("Close")
        }
    }

    /// Live preview of the habit being made.
    private var preview: some View {
        HStack(spacing: 12) {
            IconTile(icon: form.icon, tint: tint)
                .keyframeAnimator(initialValue: SwapMotion(), trigger: iconSwaps) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.angle))
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.4)
                        SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                    }
                    KeyframeTrack(\.angle) {
                        MoveKeyframe(-20)
                        SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.2)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(trimmedName.isEmpty ? "Your new habit" : trimmedName)
                    .font(.headline)
                    .foregroundStyle(trimmedName.isEmpty ? Theme.textMuted : Theme.text)
                    .lineLimit(1)
                Text(form.time.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(Motion.ease(0.25), value: form.color)
        .accessibilityHidden(true)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habit name")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            TextField("Habit name", text: $form.name, prompt: Text("e.g. Read 10 pages").foregroundStyle(Theme.textMuted))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { submit() }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(fieldBorder, lineWidth: 1.5)
                }
                .background {
                    // Soft focus / error halo around the field.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fieldHalo)
                        .padding(-4)
                }
                .modifier(ShakeEffect(shakes: shakes))
                .animation(Motion.ease(0.2), value: nameFocused)
                .animation(Motion.ease(0.2), value: showError)
            if showError {
                Text("Give your habit a name first.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.danger)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
        .onChange(of: form.name) { _, newValue in
            if newValue.count > Self.maxNameLength {
                form.name = String(newValue.prefix(Self.maxNameLength))
            }
            if showError {
                withAnimation(Motion.ease(0.2)) { showError = false }
            }
        }
    }

    private var fieldBorder: Color {
        if showError { return Theme.danger }
        return nameFocused ? Theme.accent : Theme.borderStrong
    }

    private var fieldHalo: Color {
        if showError { return Theme.dangerSoft }
        return nameFocused ? Theme.accentSoft : .clear
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Time of day")
            HStack(spacing: 8) {
                ForEach(TimeOfDay.allCases) { slot in
                    timeButton(slot)
                }
            }
        }
    }

    private func timeButton(_ slot: TimeOfDay) -> some View {
        let active = form.time == slot
        let tile = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            withAnimation(Motion.ease(0.25)) { form.time = slot }
            timeTaps[slot, default: 0] += 1
        } label: {
            VStack(spacing: 4) {
                Image(systemName: slot.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(active ? Theme.accent : Theme.textMuted)
                    .symbolEffect(.bounce, value: timeTaps[slot, default: 0])
                Text(slot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(active ? Theme.text : Theme.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(active ? Theme.accentSoft : Theme.surface, in: tile)
            .overlay { tile.strokeBorder(active ? Theme.accent : Theme.border, lineWidth: 1.5) }
            .contentShape(tile)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Accent color")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(HabitPalette.colors) { swatch in
                    colorButton(swatch)
                }
            }
            // Room for the selection ring around the swatches.
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
        }
    }

    private func colorButton(_ swatch: HabitColor) -> some View {
        let active = form.color == swatch.hex
        let color = Color(uiColor: UIColor(hex: swatch.hex))
        return Button {
            withAnimation(Motion.spring(0.35)) { form.color = swatch.hex }
        } label: {
            Circle()
                .fill(color)
                .overlay { Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1) }
                .overlay {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .scaleEffect(active ? 1 : 0.01)
                }
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                        .padding(-5)
                        .opacity(active ? 1 : 0)
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .hoverEffect(.lift)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Icon")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(HabitIcon.all, id: \.self) { icon in
                    iconButton(icon)
                }
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        let active = form.icon == icon
        let tile = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            withAnimation(Motion.ease(0.25)) { form.icon = icon }
            iconSwaps += 1
            iconTaps[icon, default: 0] += 1
        } label: {
            tile
                .fill(active ? tint.tint : Theme.surface2)
                .aspectRatio(1, contentMode: .fit)
                .overlay { tile.strokeBorder(active ? tint.ink : Color.clear, lineWidth: 1.5) }
                .overlay {
                    Image(systemName: HabitIcon.symbol(for: icon))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(active ? tint.ink : Theme.textMuted)
                        .symbolEffect(.bounce, value: iconTaps[icon, default: 0])
                }
                .contentShape(tile)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityLabel(HabitIcon.label(for: icon))
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .buttonStyle(SecondaryButtonStyle(height: 52))
                .keyboardShortcut(.cancelAction)
            Button("Add habit") { submit() }
                .buttonStyle(PrimaryButtonStyle(height: 52, expands: true, font: .callout.weight(.semibold)))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            // Content scrolls away under a soft fade instead of a hard edge.
            LinearGradient(
                stops: [
                    .init(color: Theme.surface.opacity(0), location: 0),
                    .init(color: Theme.surface, location: 0.3),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.text)
    }

    // MARK: - Actions

    private func submit() {
        let name = trimmedName
        guard !name.isEmpty else {
            withAnimation(Motion.ease(0.25)) { showError = true }
            withAnimation(.easeOut(duration: 0.36)) { shakes += 1 }
            nameFocused = true
            return
        }
        onAdd(name)
    }
}

private struct SwapMotion {
    var scale: Double = 1
    var angle: Double = 0
    var opacity: Double = 1
}

private extension View {
    /// Sheet contents drift up one after another as the sheet opens.
    func stagger(_ appeared: Bool, _ index: Int) -> some View {
        fadeUpIn(appeared, delay: 0.12 + Double(index) * 0.045, distance: 16, duration: 0.48)
    }
}
