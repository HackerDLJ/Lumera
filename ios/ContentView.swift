import SwiftUI

struct ContentView: View {
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.965, green: 0.976, blue: 0.969).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lumera")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                Text("Anemia screening")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(Color(red: 0.10, green: 0.27, blue: 0.23))
                                .frame(width: 42, height: 42)
                                .overlay(Image(systemName: "cross.case.fill").foregroundStyle(.white))
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("A simple screening check")
                                .font(.title2.bold())
                            Text("Use the camera to capture a guided image. Lumera checks image quality before any validated model can provide a screening estimate.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                showingScanner = true
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Start a scan")
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .font(.headline)
                                .padding()
                                .foregroundStyle(.white)
                                .background(Color(red: 0.10, green: 0.27, blue: 0.23))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .padding(22)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                        HStack(spacing: 12) {
                            InfoTile(icon: "camera.viewfinder", title: "Guided", detail: "Camera capture")
                            InfoTile(icon: "wand.and.stars", title: "Calibrated", detail: "Colour correction")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Research mode", systemImage: "flask")
                                .font(.headline)
                            Text("No clinical Hb estimate is shown until a validated model is installed and evaluated.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingScanner) {
                ScannerView()
            }
        }
    }
}

struct InfoTile: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
