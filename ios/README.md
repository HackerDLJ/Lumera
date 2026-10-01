# Lumera iOS

Native SwiftUI camera client for Lumera.

## Current working pieces

- Real AVFoundation camera capture
- Runtime camera permission handling
- Camera-session lifecycle management
- Photo capture delegate returning a real `UIImage`
- Gallery import using `PhotosPicker`
- Adaptive System / Light / Dark appearance
- Health Guidance screen
- Safe inference-engine boundary
- Explicit model-unavailable state instead of fabricated medical results

## Open in Xcode

1. Open Xcode on macOS.
2. Create a new **iOS App** project named `Lumera` using SwiftUI.
3. Add every Swift file in this directory to the Xcode target.
4. In the target's Info settings add:
   - `Privacy - Camera Usage Description` (`NSCameraUsageDescription`): `Lumera uses the camera to capture a guided conjunctiva image for anemia screening research.`
5. Select a physical iPhone for camera testing and Run.

## Important

The camera and gallery flows are real. The application deliberately does not display a haemoglobin estimate because a clinically validated model checkpoint has not yet been connected.

The intended next pipeline is:

`UIImage → image quality → colour calibration → conjunctiva ROI → Core ML inference → uncertainty → screening result`

The `LumeraInferenceEngine` protocol is the integration boundary for the validated model.

## Xcode note

This GitHub repository currently contains the Swift source files rather than a generated `.xcodeproj`. If you already have an Xcode project, add the files above to its target. If you create a fresh target, make sure all files are target members and add the camera permission key before running on a device.
