import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

enum AppRoute: Hashable {
    case screening
    case guidance
    case history
    case settings
}

struct ContentView: View {
    @StateObject private var history = ScreeningHistoryStore()
    @AppStorage("appearance") private var appearanceRawValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lumera")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Non-invasive anemia screening")
                            .font(.title3)
                            .foregroundStyle(LumeraTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Research screening, with safeguards")
                            .font(.title2.bold())
                        Text("Capture or choose an image, review its suitability, and continue only when a validated screening model is available.")
                            .font(.body)
                            .foregroundStyle(LumeraTheme.secondaryText)

                        NavigationLink(value: AppRoute.screening) {
                            Label("Start Screening", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LumeraTheme.accent)
                        .accessibilityIdentifier("startScreening")
                    }
                    .padding()
                    .background(LumeraTheme.surface, in: RoundedRectangle(cornerRadius: 20))

                    VStack(spacing: 0) {
                        NavigationLink(value: AppRoute.guidance) {
                            SettingsRow(title: "Health Guidance", detail: "Screening and confirmation testing", icon: "heart.text.square")
                        }
                        Divider()
                        NavigationLink(value: AppRoute.history) {
                            SettingsRow(title: "Screening History", detail: "Local, minimal records", icon: "clock.arrow.circlepath")
                        }
                        Divider()
                        NavigationLink(value: AppRoute.settings) {
                            SettingsRow(title: "Settings", detail: appearance.title, icon: "gearshape")
                        }
                    }
                    .background(LumeraTheme.surface, in: RoundedRectangle(cornerRadius: 20))

                    Text("Lumera is a screening research application and does not replace laboratory testing or professional medical evaluation.")
                        .font(.footnote)
                        .foregroundStyle(LumeraTheme.secondaryText)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
            .background(LumeraTheme.background)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .screening:
                    ScreeningView(history: history)
                case .guidance:
                    HealthGuidanceView()
                case .history:
                    ScreeningHistoryView(history: history)
                case .settings:
                    SettingsView(appearanceRawValue: $appearanceRawValue)
                }
            }
        }
        .tint(LumeraTheme.accent)
        .preferredColorScheme(appearance.colorScheme)
    }
}

struct SettingsRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(LumeraTheme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LumeraTheme.primaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(LumeraTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LumeraTheme.secondaryText)
                .accessibilityHidden(true)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

private enum ScreeningStep {
    case acquire
    case review
    case analyzing
    case result
}

struct ScreeningView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var history: ScreeningHistoryStore

    @State private var step: ScreeningStep = .acquire
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var assessment = ImageQualityAssessment(state: .checking, detail: "")
    @State private var result: ScreeningResult?
    @State private var importError: String?
    @State private var showCamera = false

    private let pipeline = ScreeningPipeline()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch step {
                case .acquire:
                    acquisitionContent
                case .review:
                    reviewContent
                case .analyzing:
                    analyzingContent
                case .result:
                    if let result {
                        resultContent(result)
                    }
                }
            }
            .padding()
        }
        .background(LumeraTheme.background)
        .navigationTitle("Screening")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            ScannerView { image in
                receive(image: image)
                showCamera = false
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let selectedImage = UIImage(data: data),
                          let preparedImage = downsampledImage(from: selectedImage) else {
                        importError = ImagePreparationError.invalidImage.localizedDescription
                        return
                    }
                    receive(image: preparedImage)
                } catch {
                    importError = ImagePreparationError.invalidImage.localizedDescription
                }
            }
        }
        .alert("Image unavailable", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private var acquisitionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Capture an image")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Use even lighting. Include the intended region and a reference card when your research protocol requires one.")
                .font(.body)
                .foregroundStyle(LumeraTheme.secondaryText)

            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(LumeraTheme.accent)
            .accessibilityIdentifier("takePhotoEntry")

            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(LumeraTheme.disabled)
                Text("or")
                    .font(.footnote)
                    .foregroundStyle(LumeraTheme.secondaryText)
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(LumeraTheme.disabled)
            }
            .accessibilityHidden(true)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(LumeraTheme.accent)
            .accessibilityIdentifier("choosePhoto")

            Text("Selected images are downsampled for processing and are not kept as part of history.")
                .font(.footnote)
                .foregroundStyle(LumeraTheme.secondaryText)
        }
    }

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Selected screening image")
            }

            Text(assessment.state.title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(assessment.detail)
                .font(.body)
                .foregroundStyle(LumeraTheme.secondaryText)

            if assessment.state == .acceptable {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Calibration", systemImage: "circle.lefthalf.filled")
                        .font(.headline)
                    Text("Reference-card detection and colour-patch transformation are pending a physical card specification. Calibration has not been performed.")
                        .font(.footnote)
                        .foregroundStyle(LumeraTheme.secondaryText)
                }
                .padding()
                .background(LumeraTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    analyze()
                } label: {
                    Label("Continue to Analysis", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(LumeraTheme.accent)
            } else {
                Button("Choose Another Image") {
                    reset()
                }
                .buttonStyle(.borderedProminent)
                .tint(LumeraTheme.accent)
            }

            Button("Replace Image") {
                reset()
            }
            .buttonStyle(.bordered)
        }
    }

    private var analyzingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing screening result")
                .font(.title3.bold())
            Text("The image is being prepared locally. A validated screening model will not be substituted with a fabricated result.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LumeraTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func resultContent(_ result: ScreeningResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: result.classification == .modelUnavailable ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(result.classification == .modelUnavailable ? LumeraTheme.warning : LumeraTheme.danger)
                .accessibilityHidden(true)

            Text(result.classification == .modelUnavailable ? "Validated screening model unavailable" : "Image not suitable for screening")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            Text(result.classification == .modelUnavailable
                 ? "No validated medical ML model is installed, so Lumera has not produced a haemoglobin value or screening classification."
                 : "The image was not suitable for screening. Please retake it with better lighting and framing.")
                .font(.body)
                .foregroundStyle(LumeraTheme.secondaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("What to do next")
                    .font(.headline)
                Text(result.classification == .modelUnavailable
                     ? "Use laboratory testing and professional evaluation for any health concern."
                     : "Choose a clearer image before continuing.")
                    .font(.body)
                    .foregroundStyle(LumeraTheme.secondaryText)
            }
            .padding()
            .background(LumeraTheme.surface, in: RoundedRectangle(cornerRadius: 16))

            NavigationLink(value: AppRoute.guidance) {
                Label("Read Health Guidance", systemImage: "heart.text.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button("New Screening") {
                reset()
            }
            .buttonStyle(.borderedProminent)
            .tint(LumeraTheme.accent)
            .accessibilityIdentifier("newScreening")
        }
    }

    private func receive(image: UIImage) {
        self.image = image
        assessment = pipeline.assess(image: image)
        step = .review
    }

    private func analyze() {
        guard let image else { return }
        step = .analyzing
        Task {
            let analysisResult = await pipeline.analyze(image: image, quality: assessment)
            result = analysisResult
            history.store(analysisResult)
            step = .result
        }
    }

    private func reset() {
        pickerItem = nil
        image = nil
        result = nil
        assessment = ImageQualityAssessment(state: .checking, detail: "")
        step = .acquire
    }
}

struct HealthGuidanceView: View {

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 18) {

                guidanceHero

                guidanceSection(
                    title: "What is anemia?",
                    icon: "drop.fill",
                    text:
                        "Anemia is a condition in which the blood has a reduced ability to carry oxygen. It can have many different causes and requires appropriate clinical assessment."
                )

                guidanceSection(
                    title: "What does a screening result mean?",
                    icon: "waveform.path.ecg",
                    text:
                        "A screening result can indicate whether further evaluation may be useful. It does not establish a diagnosis and should not replace laboratory testing."
                )

                guidanceSection(
                    title: "Why confirmation matters",
                    icon: "checkmark.seal",
                    text:
                        "A healthcare professional can interpret symptoms, medical history, and laboratory measurements together. Confirmation is important before making treatment decisions."
                )

                guidanceSection(
                    title: "General nutrition",
                    icon: "leaf",
                    text:
                        "A varied diet containing iron, vitamin B12, folate, and vitamin C can support general nutrition. Individual dietary needs should be discussed with a qualified healthcare professional."
                )

                urgentCareSection

                Text(
                    "Lumera is a screening research application. It does not diagnose anemia or replace professional medical evaluation."
                )
                .font(.footnote)
                .foregroundStyle(
                    LumeraTheme.secondaryText
                )
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(
            LumeraTheme.background
        )
        .navigationTitle("Health Guidance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero

    private var guidanceHero: some View {

        VStack(alignment: .leading, spacing: 10) {

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34))
                .foregroundStyle(
                    LumeraTheme.accent
                )

            Text("Understanding your screening")
                .font(.title2.bold())

            Text(
                "Simple information about anemia screening, confirmation, and when to seek care."
            )
            .font(.body)
            .foregroundStyle(
                LumeraTheme.secondaryText
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LumeraTheme.surface,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    // MARK: Section

    private func guidanceSection(
        title: String,
        icon: String,
        text: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(
                    LumeraTheme.primaryText
                )

            Text(text)
                .font(.body)
                .foregroundStyle(
                    LumeraTheme.secondaryText
                )
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            LumeraTheme.surface,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: Urgent Care

    private var urgentCareSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Label(
                "When to seek urgent care",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(
                LumeraTheme.warning
            )

            Text(
                "Seek urgent medical care for severe shortness of breath, chest pain, fainting, confusion, or rapidly worsening symptoms."
            )
            .font(.body)
            .foregroundStyle(
                LumeraTheme.secondaryText
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            LumeraTheme.warning.opacity(0.10),
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }
}



struct ScreeningHistoryView: View {
    @ObservedObject var history: ScreeningHistoryStore

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No screening records",
                    systemImage: "clock",
                    description: Text("Lumera only retains minimal local records for actual validated model outputs. No images are stored here.")
                )
            } else {
                List(history.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.classification.rawValue)
                            .font(.headline)
                        Text(entry.timestamp, style: .date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Screening History")
    }
}

struct SettingsView: View {
    @Binding var appearanceRawValue: String

    private var appearance: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRawValue) ?? .system },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Camera") {
                LabeledContent("Permission", value: permissionText)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }

            Section("Privacy") {
                Text("Image preparation and the current screening pipeline run locally. Lumera does not retain selected images in screening history.")
            }

            Section("About") {
                LabeledContent("Lumera version", value: "1.0")
                LabeledContent("Model version", value: "No validated model installed")
                LabeledContent("Research status", value: "Screening research application")
            }
        }
        .navigationTitle("Settings")
    }

    private var permissionText: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: "Allowed"
        case .notDetermined: "Not requested"
        case .denied, .restricted: "Disabled"
        @unknown default: "Unavailable"
        }
    }
}

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}
