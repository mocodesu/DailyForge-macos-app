import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var displayName = ""
    @State private var weightText = ""
    @State private var goalText = ""
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to DailyForge")
                        .font(.largeTitle.bold())
                    Text("One set of exercises. Every day. No edits, no excuses.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("About you") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Your name", text: $displayName)
                        TextField("Starting weight (kg)", text: $weightText)
                        TextField("Goal weight (kg)", text: $goalText)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(6)
                }

                GroupBox("Baseline photos (optional, used at your 30-day milestone)") {
                    HStack(spacing: 20) {
                        photoPicker(label: "Front", item: $frontItem, data: $frontData)
                        photoPicker(label: "Side", item: $sideItem, data: $sideData)
                    }
                    .padding(6)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }

                HStack {
                    Spacer()
                    Button("Begin") { createProfile() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(32)
            .frame(minWidth: 520, minHeight: 520)
        }
    }

    private func photoPicker(label: String, item: Binding<PhotosPickerItem?>, data: Binding<Data?>) -> some View {
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

    private func createProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard let weight = Double(weightText), weight > 0 else {
            errorMessage = "Please enter a valid starting weight."
            return
        }
        guard let goal = Double(goalText), goal > 0 else {
            errorMessage = "Please enter a valid goal weight."
            return
        }

        let profile = UserProfile(displayName: trimmedName, initialWeightKg: weight, goalWeightKg: goal)
        profile.initialFrontPhoto = frontData
        profile.initialSidePhoto = sideData
        context.insert(profile)
        try? context.save()
    }
}
