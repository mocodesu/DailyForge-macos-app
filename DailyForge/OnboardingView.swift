import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    // Unit preference stored in UserDefaults so the rest of the app can read it
    @AppStorage(PreferenceKeys.unitSystem) private var unitSystemRaw: String = UnitSystem.metric.rawValue

    private var unitSystem: UnitSystem {
        UnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    // Form fields
    @State private var displayName = ""
    @State private var weightText = ""
    @State private var goalText = ""
    @State private var heightCmText = ""        // used in metric mode
    @State private var heightFeetText = ""      // used in imperial mode
    @State private var heightInchesText = ""    // used in imperial mode

    // Photos
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?

    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                unitsBox
                aboutYouBox
                photosBox

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                actionsRow
            }
            .padding(32)
            .frame(minWidth: 580, minHeight: 680)
        }
        .onChange(of: unitSystemRaw) { oldRaw, newRaw in
            convertValues(fromRaw: oldRaw, toRaw: newRaw)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome to DailyForge")
                .font(.largeTitle.bold())
            Text("One set of exercises. Every day. No edits, no excuses.")
                .foregroundStyle(.secondary)
        }
    }

    private var unitsBox: some View {
        GroupBox("Units") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $unitSystemRaw) {
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.pickerLabel).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("You can change this any time. Entered values convert automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private var aboutYouBox: some View {
        GroupBox("About you") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "Your name") {
                    TextField("e.g. Alex", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                heightField

                LabeledField(label: "Starting weight (\(unitSystem.weightUnitLabel))") {
                    TextField(placeholderForWeight, text: $weightText)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledField(label: "Goal weight (\(unitSystem.weightUnitLabel))") {
                    TextField(placeholderForWeight, text: $goalText)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var heightField: some View {
        switch unitSystem {
        case .metric:
            LabeledField(label: "Height (cm)") {
                TextField("e.g. 175", text: $heightCmText)
                    .textFieldStyle(.roundedBorder)
            }
        case .imperial:
            LabeledField(label: "Height (ft / in)") {
                HStack(spacing: 8) {
                    TextField("ft", text: $heightFeetText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("ft").foregroundStyle(.secondary)
                    TextField("in", text: $heightInchesText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("in").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var photosBox: some View {
        GroupBox("Baseline photos (optional, used at your 30-day milestone)") {
            HStack(spacing: 20) {
                photoPicker(label: "Front", item: $frontItem, data: $frontData)
                photoPicker(label: "Side", item: $sideItem, data: $sideData)
                Spacer()
            }
            .padding(6)
        }
    }

    private var actionsRow: some View {
        HStack {
            Spacer()
            Button("Begin") { createProfile() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Field helper

    private func LabeledField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var placeholderForWeight: String {
        switch unitSystem {
        case .metric: return "e.g. 75"
        case .imperial: return "e.g. 165"
        }
    }

    // MARK: - Photo picker

    private func photoPicker(
        label: String,
        item: Binding<PhotosPickerItem?>,
        data: Binding<Data?>
    ) -> some View {
        VStack {
            PhotosPicker(selection: item, matching: .images) {
                if let data = data.wrappedValue, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 140, height: 180)
                        .overlay(Text("Choose \(label)").foregroundStyle(.secondary))
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: item.wrappedValue) { _, newValue in
            Task {
                if let newValue {
                    data.wrappedValue = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }

    // MARK: - Unit conversion on switch

    private func convertValues(fromRaw: String, toRaw: String) {
        guard let old = UnitSystem(rawValue: fromRaw),
              let new = UnitSystem(rawValue: toRaw),
              old != new else { return }

        // Weight fields
        if let w = Double(weightText.trimmingCharacters(in: .whitespaces)), w > 0 {
            let kg = UnitConversion.displayToKg(w, unit: old)
            weightText = UnitConversion.formatWeight(kg, unit: new)
        }
        if let g = Double(goalText.trimmingCharacters(in: .whitespaces)), g > 0 {
            let kg = UnitConversion.displayToKg(g, unit: old)
            goalText = UnitConversion.formatWeight(kg, unit: new)
        }

        // Height — metric ⇄ imperial
        switch (old, new) {
        case (.metric, .imperial):
            if let cm = Double(heightCmText.trimmingCharacters(in: .whitespaces)), cm > 0 {
                let (feet, inches) = UnitConversion.cmToFeetInches(cm)
                heightFeetText = "\(feet)"
                heightInchesText = "\(Int(inches.rounded()))"
            }
            heightCmText = ""

        case (.imperial, .metric):
            let feet = Int(heightFeetText.trimmingCharacters(in: .whitespaces)) ?? 0
            let inches = Double(heightInchesText.trimmingCharacters(in: .whitespaces)) ?? 0
            if feet > 0 || inches > 0 {
                let cm = UnitConversion.feetInchesToCm(feet: feet, inches: inches)
                heightCmText = "\(Int(cm.rounded()))"
            }
            heightFeetText = ""
            heightInchesText = ""

        default:
            break
        }
    }

    // MARK: - Validation

    private struct ValidationResult {
        let weightKg: Double?
        let goalKg: Double?
        let heightCm: Double?
        let error: String?
    }

    private func validate() -> ValidationResult {
        let empty = ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil, error: nil)

        // Name
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Please enter your name.")
        }

        // Weight
        guard let weightValue = Double(weightText.trimmingCharacters(in: .whitespaces)) else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Starting weight must be a number.")
        }
        guard let goalValue = Double(goalText.trimmingCharacters(in: .whitespaces)) else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Goal weight must be a number.")
        }

        let weightKg = UnitConversion.displayToKg(weightValue, unit: unitSystem)
        let goalKg = UnitConversion.displayToKg(goalValue, unit: unitSystem)

        let wr = UnitConversion.displayedWeightRange(unit: unitSystem)
        guard UnitConversion.weightRangeKg.contains(weightKg) else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Starting weight must be between \(wr.min) and \(wr.max) \(unitSystem.weightUnitLabel).")
        }
        guard UnitConversion.weightRangeKg.contains(goalKg) else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Goal weight must be between \(wr.min) and \(wr.max) \(unitSystem.weightUnitLabel).")
        }

        // Height
        let heightCm: Double
        switch unitSystem {
        case .metric:
            guard let cm = Double(heightCmText.trimmingCharacters(in: .whitespaces)) else {
                return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                        error: "Please enter your height in centimeters.")
            }
            heightCm = cm

        case .imperial:
            guard let feet = Int(heightFeetText.trimmingCharacters(in: .whitespaces)) else {
                return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                        error: "Please enter your height in feet.")
            }
            let inchesString = heightInchesText.trimmingCharacters(in: .whitespaces)
            let inches = inchesString.isEmpty ? 0.0 : (Double(inchesString) ?? 0)
            guard inches >= 0, inches < 12 else {
                return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                        error: "Inches must be between 0 and 11.")
            }
            heightCm = UnitConversion.feetInchesToCm(feet: feet, inches: inches)
        }

        let hr = UnitConversion.displayedHeightRange(unit: unitSystem)
        guard UnitConversion.heightRangeCm.contains(heightCm) else {
            return ValidationResult(weightKg: nil, goalKg: nil, heightCm: nil,
                                    error: "Height must be between \(hr.min) and \(hr.max).")
        }

        return ValidationResult(weightKg: weightKg, goalKg: goalKg, heightCm: heightCm, error: nil)
    }

    // MARK: - Create

    private func createProfile() {
        let result = validate()
        guard let weightKg = result.weightKg,
              let goalKg = result.goalKg,
              let heightCm = result.heightCm else {
            errorMessage = result.error ?? "Please check the form."
            return
        }

        errorMessage = nil

        let profile = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            initialWeightKg: weightKg,
            goalWeightKg: goalKg,
            initialHeightCm: heightCm
        )
        profile.initialFrontPhoto = frontData
        profile.initialSidePhoto = sideData
        context.insert(profile)
        try? context.save()
    }
}
