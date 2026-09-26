import SwiftUI
import SwiftData
import PhotosUI

struct MilestoneView: View {
    let profile: UserProfile
    @Bindable var milestone: Milestone

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var unitSystem: UnitSystem { UserDefaults.standard.unitSystem }

    @State private var weightText = ""
    @State private var notes = ""
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?
    @State private var aiSummary: String?
    @State private var isAnalyzing = false
    @State private var aiError: String?
    @State private var errorMessage: String?
    @State private var shareStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                weightBox
                photosBox
                notesBox
                if let aiSummary { reflectionBox(aiSummary) }
                if let aiError { Text(aiError).foregroundStyle(.red).font(.callout) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.callout) }
                if let shareStatus { shareBanner(shareStatus) }
                shareCardSection
                actionsRow
            }
            .padding(28)
        }
        .frame(width: 640, height: 780)
        .onAppear {
            notes = milestone.userNotes
            if let w = milestone.currentWeightKg {
                weightText = UnitConversion.formatWeight(w, unit: unitSystem)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(milestone.day)-Day Milestone").font(.largeTitle.bold())
            Text("You've been consistent. Time to reflect.")
                .foregroundStyle(.secondary)
        }
    }

    private var weightBox: some View {
        GroupBox("Weight") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Started at").foregroundStyle(.secondary)
                    Spacer()
                    Text(UnitConversion.formatWeight(profile.initialWeightKg, unit: unitSystem) + " \(unitSystem.weightUnitLabel)")
                        .monospacedDigit()
                }
                HStack {
                    Text("Goal").foregroundStyle(.secondary)
                    Spacer()
                    Text(UnitConversion.formatWeight(profile.goalWeightKg, unit: unitSystem) + " \(unitSystem.weightUnitLabel)")
                        .monospacedDigit()
                }
                HStack {
                    Text("Height").foregroundStyle(.secondary)
                    Spacer()
                    Text(UnitConversion.formatHeight(profile.initialHeightCm, unit: unitSystem))
                        .monospacedDigit()
                }
                HStack {
                    Text("Today (\(unitSystem.weightUnitLabel))").foregroundStyle(.secondary)
                    Spacer()
                    TextField("", text: $weightText)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(8)
        }
    }

    private var photosBox: some View {
        GroupBox("Photos") {
            HStack(spacing: 20) {
                photoColumn(label: "Day 1", data: profile.initialFrontPhoto, pickerItem: nil, pickerData: nil)
                photoColumn(label: "Today", data: frontData, pickerItem: $frontItem, pickerData: $frontData)
                Spacer()
            }
            .padding(8)
        }
    }

    private var notesBox: some View {
        GroupBox("How do you feel?") {
            TextField("Notes about your progress…", text: $notes, axis: .vertical)
                .lineLimit(4...8)
                .padding(8)
        }
    }

    private func reflectionBox(_ text: String) -> some View {
        GroupBox("Your reflection") {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }

    private var shareCardSection: some View {
        GroupBox("Share card") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Generate a beautiful 1080×1080 card of this milestone. Perfect for sharing or saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        copyCardToClipboard()
                    } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        saveCardToFile()
                    } label: {
                        Label("Save as PNG…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
            }
            .padding(8)
        }
    }

    private func shareBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
            Text(text)
                .font(.callout)
            Spacer()
        }
        .padding(10)
        .background(Theme.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actionsRow: some View {
        HStack {
            Button("Later") { dismiss() }
            Spacer()
            Button {
                generateReflection()
            } label: {
                if isAnalyzing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Generate Reflection", systemImage: "sparkles")
                }
            }
            .disabled(isAnalyzing || weightText.isEmpty)
            .buttonStyle(.bordered)

            Button("Save Milestone") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(weightText.isEmpty)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func photoColumn(
        label: String,
        data: Data?,
        pickerItem: Binding<PhotosPickerItem?>?,
        pickerData: Binding<Data?>?
    ) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 150, height: 200)
                if let data, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("No photo").foregroundStyle(.secondary)
                }
            }
            if let pickerItem, let pickerData {
                PhotosPicker(selection: pickerItem, matching: .images) {
                    Text("Choose photo").font(.caption)
                }
                .onChange(of: pickerItem.wrappedValue) { _, newValue in
                    Task {
                        if let newValue {
                            pickerData.wrappedValue = try? await newValue.loadTransferable(type: Data.self)
                        }
                    }
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Share Card Actions

    private func copyCardToClipboard() {
        let ok = MilestoneCardRenderer.copyToClipboard(
            profile: profile,
            milestone: milestone,
            unitSystem: unitSystem
        )
        shareStatus = ok
            ? "Card copied to clipboard."
            : "Could not render the share card."
    }

    private func saveCardToFile() {
        switch MilestoneCardRenderer.save(
            profile: profile,
            milestone: milestone,
            unitSystem: unitSystem
        ) {
        case .saved(let url):
            shareStatus = "Saved to \(url.lastPathComponent)"
        case .cancelled:
            break
        case .failed(let message):
            shareStatus = "Save failed: \(message)"
        }
    }

    // MARK: - Actions

    private func generateReflection() {
        guard let currentValue = Double(weightText), currentValue > 0 else { return }
        let currentKg = UnitConversion.displayToKg(currentValue, unit: unitSystem)

        isAnalyzing = true
        aiError = nil
        aiSummary = nil

        Task {
            let delta = currentKg - profile.initialWeightKg
            let deltaText = String(format: "%.1f kg", abs(delta))
            let direction = delta < 0 ? "lost" : (delta > 0 ? "gained" : "maintained")

            let prompt = """
            You are a supportive fitness coach. In 3-4 sentences, write an encouraging reflection for someone who just completed a \(milestone.day)-day workout streak.

            Facts:
            - Starting weight: \(String(format: "%.1f", profile.initialWeightKg)) kg
            - Goal weight: \(String(format: "%.1f", profile.goalWeightKg)) kg
            - Current weight: \(String(format: "%.1f", currentKg)) kg
            - They have \(direction) \(deltaText) since starting.
            - Their personal notes: "\(notes)"

            Keep the tone warm, honest, and non-clinical. Do not invent details not listed above. Do not give medical advice.
            """

            do {
                let summary = try await generateWithAppleIntelligence(prompt: prompt)
                await MainActor.run {
                    self.aiSummary = summary
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.aiError = "Apple Intelligence isn't available right now. Your milestone can still be saved."
                    self.isAnalyzing = false
                }
            }
        }
    }

    private func save() {
        guard let value = Double(weightText), value > 0 else {
            errorMessage = "Please enter a valid weight."
            return
        }
        let kg = UnitConversion.displayToKg(value, unit: unitSystem)

        guard UnitConversion.weightRangeKg.contains(kg) else {
            let r = UnitConversion.displayedWeightRange(unit: unitSystem)
            errorMessage = "Weight must be between \(r.min) and \(r.max) \(unitSystem.weightUnitLabel)."
            return
        }

        errorMessage = nil
        milestone.currentWeightKg = kg
        milestone.userNotes = notes
        milestone.currentFrontPhoto = frontData ?? milestone.currentFrontPhoto
        milestone.currentSidePhoto = sideData ?? milestone.currentSidePhoto
        milestone.aiSummary = aiSummary
        milestone.completedAt = Date()
        try? context.save()
        dismiss()
    }
}
