import SwiftUI
import UIKit

/// Thin wrapper over `UIImagePickerController` for camera capture. The mockup (M05) shows a
/// live AVFoundation viewfinder with an animated recognition overlay; this ships the
/// functional equivalent (capture, then identify) without the live-preview polish, which is
/// deferred — see docs/PROGRESO.md. Falls back to the photo library in the simulator, where
/// there is no camera.
///
/// IMPORTANT: never call `picker.dismiss(animated:)` here. This view is hosted inside a
/// SwiftUI `.sheet(isPresented:)`; dismissal must go ONLY through that binding (`onCapture`/
/// `onCancel` flipping the parent's `@State`). Calling UIKit's imperative dismiss alongside
/// SwiftUI's own presentation machinery is what caused a real bug found on simulator: the
/// whole sheet stack collapsed back to the root tab instead of just closing the picker.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        #if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        #endif
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) {
                onCapture(data)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
