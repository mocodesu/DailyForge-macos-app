import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Combine

// MARK: - Shared session flag

class SwearSessionState: ObservableObject {
    static let shared = SwearSessionState()
    @Published var isActive: Bool = false
    private init() {}
}

// MARK: - Swear View

struct SwearView: View {
    let dayKey: String
    let onSworn: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKeys.swearPhrase) private var swearPhrase: String = Preferences.defaultSwearPhrase

    @StateObject private var recognizer = VoiceSwearRecognizer()

    @State private var phase: Phase = .idle
    @State private var capturedTranscript = ""
    @State private var matchResult: SwearMatcher.Result?
    @State private var errorMessage: String?

    enum Phase {
        case idle
        case recording
        case reviewing
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            content
        }
        .frame(width: 600, height: 660)
        .interactiveDismissDisabled(phase != .idle)
        .onAppear {
            recognizer.prepare()
            // Publishing during view update is disallowed. Defer by one runloop.
            DispatchQueue.main.async {
                SwearSessionState.shared.isActive = true
            }
        }
        .onDisappear {
            recognizer.stop()
            DispatchQueue.main.async {
                SwearSessionState.shared.isActive = false
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 20) {
            header
            phraseCard
            stageView
            statusLine
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            actionsRow
        }
        .padding(28)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Seal the Day").font(.largeTitle.bold())
            }
            Text("You finished your exercises. Now swear to it — out loud.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phraseCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Say this phrase:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("“\(swearPhrase)”")
                    .font(.title3.weight(.medium))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    @ViewBuilder
    private var stageView: some View {
        switch phase {
        case .idle: idleStage
        case .recording: recordingStage
        case .reviewing: reviewingStage
        }
    }

    private var idleStage: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "mic.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
            }

            Text(idleHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var idleHint: String {
        switch recognizer.setupState {
        case .ready:
            return "Press Start. Speak the phrase. Press Stop when you're done."
        case .needMicPermission:
            return "Microphone permission is required. Click Request Access below, or enable it in System Settings → Privacy & Security → Microphone."
        case .needSpeechPermission:
            return "Speech recognition permission is required. Enable it in System Settings → Privacy & Security → Speech Recognition."
        case .denied:
            return "Microphone or speech permission is denied. Fix it in System Settings → Privacy & Security, then relaunch the app."
        case .unavailable(let reason):
            return "Speech recognizer unavailable: \(reason)"
        case .preparing:
            return "Preparing microphone…"
        }
    }

    private var recordingStage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 130, height: 130)
                    .scaleEffect(1.05)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: phase
                    )
                Circle()
                    .fill(Color.red.opacity(0.10))
                    .frame(width: 170, height: 170)
                Image(systemName: "waveform")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
            }

            Text("Speak the phrase now.")
                .font(.title3.weight(.medium))
            Text("Press Stop when you're finished. You can't cancel until then.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var reviewingStage: some View {
        VStack(spacing: 14) {
            GroupBox("This is what we heard") {
                Text(capturedTranscript.isEmpty ? "(no speech detected)" : capturedTranscript)
                    .font(.body)
                    .italic()
                    .foregroundStyle(capturedTranscript.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .lineLimit(4)
            }

            if let match = matchResult {
                HStack(spacing: 8) {
                    Image(systemName: match.matched ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(match.matched ? .green : .red)
                    Text(match.matched
                         ? "Phrase recognized (\(Int(match.score * 100))%)."
                         : "Match: \(Int(match.score * 100))%. That doesn't match. Try again.")
                        .font(.callout)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(recognizer.isRecording ? Color.red : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(recognizer.statusDetail)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsRow: some View {
        HStack(spacing: 12) {
            if phase == .idle {
                Button("Cancel") {
                    recognizer.stop()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if recognizer.setupState == .needMicPermission
                    || recognizer.setupState == .needSpeechPermission {
                    Button("Request Access") {
                        recognizer.requestAllPermissions()
                    }
                    .buttonStyle(.bordered)
                }

                if recognizer.setupState == .needMicPermission
                    || recognizer.setupState == .denied {
                    Button("Open Microphone Settings") {
                        recognizer.openMicrophoneSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            switch phase {
            case .idle:
                Button {
                    startRecording()
                } label: {
                    Label("Start", systemImage: "mic.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(recognizer.setupState != .ready)

            case .recording:
                Button {
                    stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

            case .reviewing:
                Button("Try Again") { resetForRetry() }
                    .buttonStyle(.bordered)

                Button {
                    confirmSwear()
                } label: {
                    Label("Confirm Swear", systemImage: "checkmark.seal.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!(matchResult?.matched ?? false))
            }
        }
    }

    // MARK: - Flow

    private func startRecording() {
        errorMessage = nil
        capturedTranscript = ""
        matchResult = nil
        recognizer.transcript = ""

        do {
            try recognizer.start()
            phase = .recording
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    private func stopRecording() {
        recognizer.stop()
        // Give the recognizer a beat to flush its final result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            capturedTranscript = recognizer.transcript
                .trimmingCharacters(in: .whitespacesAndNewlines)
            matchResult = SwearMatcher.evaluate(capturedTranscript, against: swearPhrase)
            phase = .reviewing
        }
    }

    private func resetForRetry() {
        capturedTranscript = ""
        matchResult = nil
        errorMessage = nil
        recognizer.transcript = ""
        phase = .idle
    }

    /// Inserts both the DailySwear and the DayLock in a single transaction
    /// so nothing downstream depends on SwiftUI's @Query refresh timing.
    private func confirmSwear() {
        guard let match = matchResult, match.matched else {
            errorMessage = "The phrase wasn't close enough. Try again."
            return
        }
        guard !capturedTranscript.isEmpty else {
            errorMessage = "No speech was captured."
            return
        }

        // One insert pass, one save.
        let swear = DailySwear(
            dayKey: dayKey,
            transcript: capturedTranscript,
            matchedPhrase: swearPhrase
        )
        context.insert(swear)

        // Insert the day lock here too. If it already exists, skip.
        let existingLockFetch = FetchDescriptor<DayLock>(
            predicate: #Predicate { $0.dayKey == dayKey }
        )
        let existingLocks = (try? context.fetch(existingLockFetch)) ?? []
        if existingLocks.isEmpty {
            context.insert(DayLock(dayKey: dayKey))
        }

        do {
            try context.save()
        } catch {
            // Roll back the in-memory changes so state stays consistent.
            context.rollback()
            errorMessage = "Could not save the swear: \(error.localizedDescription)"
            return
        }

        recognizer.stop()

        // Notify the parent, then dismiss on the next runloop so the sheet
        // teardown and the parent's state refresh don't collide.
        onSworn()
        DispatchQueue.main.async {
            dismiss()
        }
    }
}

// MARK: - Phrase Matching

enum SwearMatcher {
    struct Result {
        let matched: Bool
        let score: Double
    }

    static func evaluate(_ input: String, against phrase: String) -> Result {
        let normalizedInput = normalize(input)
        let normalizedTarget = normalize(phrase)

        guard !normalizedInput.isEmpty, !normalizedTarget.isEmpty else {
            return Result(matched: false, score: 0)
        }

        let inputWords = Set(normalizedInput.split(separator: " ").map(String.init))
        let targetWords = normalizedTarget.split(separator: " ").map(String.init)
        guard !targetWords.isEmpty else { return Result(matched: false, score: 0) }

        let presentCount = targetWords.filter { inputWords.contains($0) }.count
        let score = Double(presentCount) / Double(targetWords.count)
        return Result(matched: score >= 0.8, score: score)
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }
        return String(stripped)
            .split(separator: " ")
            .joined(separator: " ")
    }
}

// MARK: - Voice Recognizer

enum RecognizerSetupState: Equatable {
    case preparing
    case ready
    case needMicPermission
    case needSpeechPermission
    case denied
    case unavailable(String)
}

enum RecognizerError: LocalizedError {
    case noInputDevice
    case invalidFormat
    case engineFailed(String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No microphone detected. Plug one in or select an input device in System Settings → Sound → Input."
        case .invalidFormat:
            return "The microphone returned an invalid audio format."
        case .engineFailed(let reason):
            return "Could not start the audio engine: \(reason)"
        }
    }
}

class VoiceSwearRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var setupState: RecognizerSetupState = .preparing
    @Published var statusDetail: String = "Initialising…"

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false

    override init() {
        super.init()
        speechRecognizer?.delegate = self
        log("VoiceSwearRecognizer created")
    }

    // MARK: - Setup

    func prepare() {
        guard let recognizer = speechRecognizer else {
            setupState = .unavailable("locale en-US not supported")
            statusDetail = "Recognizer unavailable"
            return
        }
        if !recognizer.isAvailable {
            setupState = .unavailable("service is unavailable right now")
            statusDetail = "Recognizer unavailable"
            return
        }
        refreshPermissions()
    }

    func requestAllPermissions() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshPermissions()
                }
            }
        } else {
            refreshPermissions()
        }

        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshPermissions()
                }
            }
        }
    }

    private func refreshPermissions() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let speech = SFSpeechRecognizer.authorizationStatus()

        if mic == .denied || mic == .restricted
            || speech == .denied || speech == .restricted {
            setupState = .denied
            statusDetail = "Permission denied — open System Settings"
            return
        }
        if mic != .authorized {
            setupState = .needMicPermission
            statusDetail = "Awaiting microphone permission"
            return
        }
        if speech != .authorized {
            setupState = .needSpeechPermission
            statusDetail = "Awaiting speech recognition permission"
            return
        }
        setupState = .ready
        statusDetail = "Ready"
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Recording

    func start() throws {
        guard !isRecording else { return }
        guard setupState == .ready else {
            throw RecognizerError.engineFailed("not ready (state: \(setupState))")
        }

        removeTapIfInstalled()
        transcript = ""

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        guard format.channelCount > 0, format.sampleRate > 0 else {
            setupState = .unavailable("no input device")
            statusDetail = "No input device"
            throw RecognizerError.noInputDevice
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition ?? false {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            removeTapIfInstalled()
            setupState = .unavailable("engine start failed")
            statusDetail = "Engine failed"
            throw RecognizerError.engineFailed(error.localizedDescription)
        }

        isRecording = true
        statusDetail = "Listening (\(Int(format.sampleRate)) Hz, \(format.channelCount) ch)"

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if let error = error {
                // Only log — don't mutate state from here.
                print("[SwearRecognizer] Recognition error: \(error.localizedDescription)")
            }
        }
    }

    /// Fully synchronous. Safe to call from any thread, from deinit, or
    /// multiple times in a row. Never publishes to @Published asynchronously.
    func stop() {
        stopAudioOnly()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // Synchronous — do NOT wrap in DispatchQueue.main.async. Doing so
        // was capturing self after deallocation and crashing the app.
        if isRecording {
            isRecording = false
        }
        if setupState == .ready, statusDetail != "Ready" {
            statusDetail = "Ready"
        }
    }

    private func stopAudioOnly() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfInstalled()
    }

    private func removeTapIfInstalled() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available && self.setupState == .ready {
                self.setupState = .unavailable("service went offline")
            }
        }
    }

    private func log(_ message: String) {
        print("[SwearRecognizer] \(message)")
    }

    /// Cleanup only. Never touches @Published properties — doing so
    /// during deallocation causes a use-after-free crash.
    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
