import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingScanner = false
    @State private var showingGuidance = false
    @State private var showingSettings = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importedImage: UIImage?
    @State private var showImportedImage = false
    @AppStorage("lumeraAppearance") private var appearance = "system"

    private var selectedScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    hero
                    quickActions
                    researchNotice
                }
                .padding()
            }
            .background(Color.lumeraBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingGuidance) { NavigationStack { HealthGuidanceView() } }
            .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView(appearance: $appearance) } }
            .sheet(isPresented: $showImportedImage) {
                ImportedImageView(image: importedImage) { showImportedImage = false }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                ScannerView()
            }
        }
        .preferredColorScheme(selectedScheme)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            do {
                if let data = try await selectedPhoto.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    importedImage = image
                    showImportedImage = true
                }
            } catch {
                importedImage = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lumera").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.lumeraText)
                Text("Anemia screening").foregroundStyle(Color.lumeraSecondaryText)
            }
            Spacer()
            Image(systemName: "cross.case.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.lumeraPrimary)
                .clipShape(Circle())
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A simple screening check").font(.title2.bold()).foregroundStyle(Color.lumeraText)
            Text("Capture a guided image with the camera or choose an existing photo. Lumera checks the image before any validated model can provide a screening estimate.")
                .foregroundStyle(Color.lumeraSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button { showingScanner = true } label: {
                Label("Start a scan", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(LumeraPrimaryButton())

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(LumeraSecondaryButton())
        }
        .lumeraCard()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionTile(icon: "heart.text.square", title: "Guidance") { showingGuidance = true }
            ActionTile(icon: "gearshape", title: "Settings") { showingSettings = true }
        }
    }

    private var researchNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flask").foregroundStyle(Color.lumeraPrimary)
            VStack(alignment: .leading, spacing: 5) {
                Text("Research mode").font(.headline).foregroundStyle(Color.lumeraText)
                Text("No clinical Hb estimate is shown until a validated model is installed and evaluated.")
                    .font(.subheadline).foregroundStyle(Color.lumeraSecondaryText)
            }
        }
        .lumeraCard()
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.lumeraPrimary)
                Text(title).font(.headline).foregroundStyle(Color.lumeraText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .lumeraCard()
    }
}

struct SettingsView: View {
    @Binding var appearance: String
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section("Privacy") {
                Text("Photos are selected locally. Lumera does not claim a validated medical inference model is installed in this research build.")
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: "0.1 Research")
                LabeledContent("Model", value: "Not installed")
            }
        }
        .navigationTitle("Settings")
    }
}

struct ImportedImageView: View {
    let image: UIImage?
    let close: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    ContentUnavailableView("Invalid image", systemImage: "photo.badge.exclamationmark", description: Text("Choose another photo."))
                }
                Text("Image captured. No clinical inference is performed until a validated model is installed.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Done", action: close).buttonStyle(LumeraPrimaryButton()).padding(.horizontal)
                Spacer()
            }
            .padding()
            .background(Color.lumeraBackground.ignoresSafeArea())
            .navigationTitle("Selected image")
        }
    }
}

struct LumeraPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).background(Color.lumeraPrimary).clipShape(RoundedRectangle(cornerRadius: 14)).opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct LumeraSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Color.lumeraText).background(Color.lumeraSurface).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lumeraBorder)).clipShape(RoundedRectangle(cornerRadius: 14)).opacity(configuration.isPressed ? 0.78 : 1)
    }
}
