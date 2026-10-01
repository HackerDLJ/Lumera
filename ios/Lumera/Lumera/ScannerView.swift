
import SwiftUI
@preconcurrency import AVFoundation
import UIKit
import Combine

// MARK: - Camera State

enum CameraState: Equatable {
    case idle
    case requestingPermission
    case ready
    case capturing
    case unavailable(String)
}

// MARK: - Camera Manager

@MainActor
final class CameraManager: NSObject, ObservableObject {

    @Published private(set) var state: CameraState = .idle
    @Published private(set) var isUsingFrontCamera = false

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(
        label: "com.lumera.camera-session",
        qos: .userInitiated
    )

    private var activeInput: AVCaptureDeviceInput?
    private var photoProcessor: PhotoProcessor?

    private var configured = false
    private var shouldResumeAfterInterruption = false

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            configureAndStart()

        case .notDetermined:
            state = .requestingPermission

            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }

                    if granted {
                        self.configureAndStart()
                    } else {
                        self.state = .unavailable(
                            "Camera access is disabled. Enable camera access in Settings."
                        )
                    }
                }
            }

        case .denied, .restricted:
            state = .unavailable(
                "Camera access is disabled. Enable camera access in Settings."
            )

        @unknown default:
            state = .unavailable(
                "This device camera is unavailable."
            )
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        Task { @MainActor in
            if self.state != .capturing {
                self.state = .idle
            }
        }
    }

    // MARK: Capture

    func capturePhoto(
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        guard state == .ready else {
            completion(.failure(CameraError.unavailable))
            return
        }

        state = .capturing

        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard self.session.isRunning else {
                Task { @MainActor in
                    self.state = .unavailable(
                        "The camera is not currently running."
                    )
                    completion(.failure(CameraError.unavailable))
                }
                return
            }

            let settings = AVCapturePhotoSettings()

            let processor = PhotoProcessor { [weak self] result in
                Task { @MainActor in
                    self?.state = .ready
                    completion(result)
                }
            }

            self.photoProcessor = processor

            self.photoOutput.capturePhoto(
                with: settings,
                delegate: processor
            )
        }
    }

    // MARK: Camera Switching

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self,
                  let currentInput = self.activeInput
            else {
                return
            }

            let targetPosition: AVCaptureDevice.Position =
                currentInput.device.position == .back ? .front : .back

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: targetPosition
                ),
                let newInput = try? AVCaptureDeviceInput(device: device)
            else {
                return
            }

            self.session.beginConfiguration()

            defer {
                self.session.commitConfiguration()
            }

            self.session.removeInput(currentInput)

            guard self.session.canAddInput(newInput) else {
                self.session.addInput(currentInput)
                return
            }

            self.session.addInput(newInput)
            self.activeInput = newInput

            Task { @MainActor in
                self.isUsingFrontCamera =
                    targetPosition == .front
            }
        }
    }

    // MARK: Configuration

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.configured {
                    try self.configureSession()
                    self.configured = true
                }

                guard !self.session.isRunning else {
                    Task { @MainActor in
                        self.state = .ready
                    }
                    return
                }

                self.session.startRunning()

                Task { @MainActor in
                    self.state = self.session.isRunning
                        ? .ready
                        : .unavailable(
                            "We couldn't start the camera. Please try again."
                        )
                }

            } catch {
                Task { @MainActor in
                    self.state = .unavailable(
                        "We couldn't start the camera. Please try again."
                    )
                }
            }
        }
    }

    private func configureSession() throws {

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()

        defer {
            session.commitConfiguration()
        }

        session.sessionPreset = .photo

        guard session.canAddInput(input) else {
            throw CameraError.configurationFailed
        }

        session.addInput(input)
        activeInput = input

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.configurationFailed
        }

        session.addOutput(photoOutput)

        if let connection = photoOutput.connection(with: .video),
           connection.isVideoMirroringSupported {
            connection.isVideoMirrored = false
        }
    }

    // MARK: Notifications

    @objc private func sessionInterrupted(
        _ notification: Notification
    ) {
        Task { @MainActor in
            shouldResumeAfterInterruption = session.isRunning
        }
    }

    @objc private func sessionInterruptionEnded(
        _ notification: Notification
    ) {
        Task { @MainActor in
            if shouldResumeAfterInterruption {
                shouldResumeAfterInterruption = false
                configureAndStart()
            }
        }
    }

    @objc private func sessionRuntimeError(
        _ notification: Notification
    ) {
        Task { @MainActor in
            state = .unavailable(
                "The camera encountered an error. Please try again."
            )
        }
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {

    case unavailable
    case configurationFailed

    var errorDescription: String? {
        switch self {

        case .unavailable:
            "This device camera is unavailable."

        case .configurationFailed:
            "We couldn't start the camera. Please try again."
        }
    }
}

// MARK: - Photo Processor

private final class PhotoProcessor:
    NSObject,
    AVCapturePhotoCaptureDelegate {

    private let completion:
        (Result<UIImage, Error>) -> Void

    init(
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {

        if let error {
            completion(.failure(error))
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data),
            let preparedImage = downsampledImage(from: image)
        else {
            completion(
                .failure(
                    ImagePreparationError.invalidImage
                )
            )
            return
        }

        completion(.success(preparedImage))
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(
        context: Context
    ) -> PreviewView {

        PreviewView(session: session)
    }

    func updateUIView(
        _ previewView: PreviewView,
        context: Context
    ) {

        previewView.previewLayer.session = session
    }
}

final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer:
        AVCaptureVideoPreviewLayer {

        guard
            let layer =
                layer as? AVCaptureVideoPreviewLayer
        else {
            fatalError(
                "PreviewView must use AVCaptureVideoPreviewLayer."
            )
        }

        return layer
    }

    init(session: AVCaptureSession) {

        super.init(frame: .zero)

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        nil
    }
}

// MARK: - Scanner View

struct ScannerView: View {

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var camera = CameraManager()

    let onImage: (UIImage) -> Void

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            CameraPreview(
                session: camera.session
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                topBar

                Spacer()

                scannerGuide

                Spacer()

                captureControls
            }
        }
        .statusBarHidden(true)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .alert(
            "Camera unavailable",
            isPresented: unavailableBinding
        ) {

            Button("Open Settings") {

                guard
                    let url = URL(
                        string:
                            UIApplication.openSettingsURLString
                    )
                else {
                    return
                }

                UIApplication.shared.open(url)
            }

            Button("Cancel", role: .cancel) {
                dismiss()
            }

        } message: {

            Text(unavailableMessage)
        }
    }

    // MARK: Top Bar

    private var topBar: some View {

        HStack {

            Button {
                dismiss()
            } label: {
                Label(
                    "Close",
                    systemImage: "xmark"
                )
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .accessibilityIdentifier(
                "closeScanner"
            )

            Spacer()

            Button {
                camera.switchCamera()
            } label: {

                Image(
                    systemName:
                        "camera.rotate"
                )
                .font(.headline)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .accessibilityLabel(
                "Switch camera"
            )
        }
        .padding()
    }

    // MARK: Guide

    private var scannerGuide: some View {

        VStack(spacing: 14) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 28
                )
                .stroke(
                    .white.opacity(0.9),
                    lineWidth: 2
                )
                .frame(
                    maxWidth: 310
                )
                .frame(height: 170)

                RoundedRectangle(
                    cornerRadius: 22
                )
                .stroke(
                    .white.opacity(0.25),
                    lineWidth: 1
                )
                .frame(
                    maxWidth: 280
                )
                .frame(height: 140)
            }
            .accessibilityHidden(true)

            Text(
                "Position the intended region inside the guide."
            )
            .font(.callout.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            Text(
                "Use even lighting and avoid glare."
            )
            .font(.caption)
            .foregroundStyle(
                .white.opacity(0.75)
            )
        }
    }

    // MARK: Capture

    @ViewBuilder
    private var captureControls: some View {

        VStack(spacing: 16) {

            switch camera.state {

            case .capturing:

                ProgressView(
                    "Capturing image"
                )
                .tint(.white)
                .foregroundStyle(.white)

            case .unavailable(let message):

                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

            case .requestingPermission:

                ProgressView(
                    "Requesting camera access"
                )
                .tint(.white)

            case .idle:

                ProgressView()
                    .tint(.white)

            case .ready:

                Button {

                    camera.capturePhoto { result in

                        switch result {

                        case .success(let image):
                            onImage(image)

                        case .failure:
                            break
                        }
                    }

                } label: {

                    ZStack {

                        Circle()
                            .fill(.white)
                            .frame(
                                width: 76,
                                height: 76
                            )

                        Circle()
                            .stroke(
                                .white.opacity(0.6),
                                lineWidth: 3
                            )
                            .frame(
                                width: 88,
                                height: 88
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Capture screening image"
                )
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: Alert

    private var unavailableBinding:
        Binding<Bool> {

        Binding(
            get: {
                if case .unavailable = camera.state {
                    return true
                }

                return false
            },
            set: { _ in }
        )
    }

    private var unavailableMessage: String {

        if case .unavailable(let message) =
            camera.state {

            return message
        }

        return "Camera unavailable."
    }
}


