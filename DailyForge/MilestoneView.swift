import SwiftUI
import SwiftData
import PhotosUI

struct MilestoneView: View {
    let profile: UserProfile
    @Bindable var milestone: Milestone

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var notes = ""
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?
    @State private var aiSummary: String?
    @State private var isAnalyzing = false
    @State private var aiError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(milestone.day)-Day Milestone").font(.largeTitle.bold())
                    Text("You've been consistent. Time to reflect.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Weight") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Started at").foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f kg", profile.initialWeightKg))
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Goal").foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f kg", profile.goalWeightKg))
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Today").foregroundStyle(.secondary)
                            Spacer()
                            TextField("kg", text: $weightText)
                                .frame(width: 100)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Photos") {
                    HStack(spacing: 20) {
                        photoColumn(
                            label: "Day 1",
                            data: profile.initialFrontPhoto,
                            pickerItem: nil,
                            pickerData: nil
                        )
                        photoColumn(
                            label: "Today",
                            data: frontData,
                            pickerItem: $frontItem,
                            pickerData: $frontData
                        )
                        Spacer()
                    }
                    .padding(8)
                }

                GroupBox("How do you feel?") {
                    TextField("Notes about your progress…", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                        .padding(8)
                }

                if let aiSummary {
                    GroupBox("Your reflection") {
                        Text(aiSummary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }

                if let aiError {
                    Text(aiError).foregroundStyle(.red).font(.callout)
                }

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
            .padding(28)
        }
        .frame(width: 620, height: 720)
        .onAppear {
            notes = milestone.userNotes
            if let w = milestone.currentWeightKg { weightText = String(format: "%.1f", w) }
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

    private func generateReflection() {
        guard let current = Double(weightText) else { return }
        isAnalyzing = true
        aiError = nil
        aiSummary = nil

        Task {
            let delta = current - profile.initialWeightKg
            let deltaText = String(format: "%.1f kg", abs(delta))
            let direction = delta < 0 ? "lost" : (delta > 0 ? "gained" : "maintained")

            let prompt = """
            You are a supportive fitness coach. In 3-4 sentences, write an encouraging reflection for someone who just completed a \(milestone.day)-day workout streak.

            Facts:
            - Starting weight: \(String(format: "%.1f", profile.initialWeightKg)) kg
            - Goal weight: \(String(format: "%.1f", profile.goalWeightKg)) kg
            - Current weight: \(String(format: "%.1f", current)) kg
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
        guard let current = Double(weightText) else { return }
        milestone.currentWeightKg = current
        milestone.userNotes = notes
        milestone.currentFrontPhoto = frontData ?? milestone.currentFrontPhoto
        milestone.currentSidePhoto = sideData ?? milestone.currentSidePhoto
        milestone.aiSummary = aiSummary
        milestone.completedAt = Date()
        try? context.save()
        dismiss()
    }
}
