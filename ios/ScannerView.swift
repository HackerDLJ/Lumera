import SwiftUI
import AVFoundation

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var captured = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("SCAN")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }
                .foregroundStyle(.white)
                .padding()

                Spacer()

                VStack(spacing: 14) {
                    Text("Position the lower eyelid inside the guide")
                        .font(.headline)
                    Text("Keep the phone steady and use even lighting.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))

                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(height: 150)
                        .padding(.horizontal, 35)

                    Button {
                        captured = true
                        camera.capturePhoto()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 74, height: 74)
                            .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 2))
                    }
                    .padding(.bottom, 12)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                .background(.black.opacity(0.42))
            }

            if captured {
                Color.black.opacity(0.72).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                    Text("Image captured")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Research mode is active. A validated clinical model is not installed, so Lumera will not invent an Hb result.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 30)
                    Button("Take another") { captured = false }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            AVCaptureDevice.requestAccess(for: .video) { _ in self.start() }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func capturePhoto() {
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) { fatalError() }
}
