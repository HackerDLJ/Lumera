import SwiftUI
import AVFoundation
import UIKit

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var showCaptured = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial).clipShape(Circle())
                    }
                    Spacer()
                    Text("SCAN").font(.caption.weight(.bold)).tracking(2)
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }
                .foregroundStyle(.white)
                .padding()

                Spacer()

                VStack(spacing: 14) {
                    Text(camera.authorizationMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Place the lower eyelid inside the guide and keep the phone steady.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)

                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.92), lineWidth: 2)
                        .frame(height: 150)
                        .padding(.horizontal, 35)

                    if camera.permissionDenied {
                        Button("Open Settings") { openSettings() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button { camera.capturePhoto() } label: {
                            Circle().fill(.white).frame(width: 74, height: 74).overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 2))
                        }
                        .disabled(!camera.isReady)
                        .opacity(camera.isReady ? 1 : 0.45)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                .padding(.bottom, 18)
                .background(.black.opacity(0.45))
            }

            if let capturedImage, showCaptured {
                Color.black.opacity(0.84).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(uiImage: capturedImage)
                        .resizable().scaledToFit().frame(maxHeight: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)
                    Text("Image captured")
                        .font(.title2.bold()).foregroundStyle(.white)
                    Text("The image is ready for Lumera's quality, calibration and validated inference pipeline. This build will not invent an Hb result.")
                        .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.82)).padding(.horizontal, 28)
                    HStack {
                        Button("Retake") { showCaptured = false }
                            .buttonStyle(.borderedProminent)
                        Button("Done") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onReceive(camera.$capturedImage) { image in
            guard let image else { return }
            capturedImage = image
            showCaptured = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published private(set) var isReady = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var authorizationMessage = "Checking camera access…"
    @Published var capturedImage: UIImage?

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "lumera.camera.session")
    private var configured = false
    private var isStarting = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            authorizationMessage = "Camera access is required for a scan."
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.configureAndStart() }
                    else { self.permissionDenied = true; self.authorizationMessage = "Camera access is disabled. Enable it in Settings." }
                }
            }
        case .denied, .restricted:
            permissionDenied = true
            authorizationMessage = "Camera access is disabled. Enable it in Settings."
        @unknown default:
            permissionDenied = true
            authorizationMessage = "Camera access is unavailable on this device."
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isStarting else { return }
            self.isStarting = true
            defer { self.isStarting = false }

            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.authorizationMessage = "This device camera is unavailable."
                        self.permissionDenied = true
                    }
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(input)

                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
                self.configured = true
            }

            guard !self.session.isRunning else {
                DispatchQueue.main.async { self.isReady = true; self.authorizationMessage = "Camera ready" }
                return
            }

            self.session.startRunning()
            DispatchQueue.main.async {
                self.isReady = self.session.isRunning
                self.authorizationMessage = self.session.isRunning ? "Camera ready" : "Camera could not start."
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
            if self.output.availablePhotoCodecTypes.contains(.jpeg) {
                settings.flashMode = .off
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.capturedImage = image }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.updateOrientation() }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    func updateOrientation() {
        guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
        if let orientation = window?.windowScene?.interfaceOrientation {
            connection.videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: orientation)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private extension AVCaptureVideoOrientation {
    init(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        case .portraitUpsideDown: self = .portraitUpsideDown
        default: self = .portrait
        }
    }
}
