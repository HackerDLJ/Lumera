# Lumera iOS

Native SwiftUI camera client for Lumera.

## Open in Xcode

1. Open Xcode on macOS.
2. Create a new **iOS App** project named `Lumera` using SwiftUI.
3. Add the files in this directory to the Xcode target:
   - `LumeraApp.swift`
   - `ContentView.swift`
   - `ScannerView.swift`
4. In the target's **Info** settings add:
   - `Privacy - Camera Usage Description` (`NSCameraUsageDescription`): `Lumera uses the camera to capture a guided conjunctiva image for anemia screening research.`
5. Select an iPhone simulator or physical iPhone and Run.

## Important

The camera flow is real, but the repository currently runs in research mode. It deliberately does not display a haemoglobin estimate because a clinically validated model checkpoint has not yet been connected.

The next integration point is the photo delegate in `CameraModel`, where the captured image will be passed to Lumera's quality, calibration, ROI and validated inference pipeline.
