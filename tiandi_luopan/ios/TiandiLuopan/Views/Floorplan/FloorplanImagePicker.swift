import SwiftUI
import UIKit
import PhotosUI

// MARK: - 户型图纸相册选取器 (Floorplan Image Picker)
//
// 用 PHPicker 而不是 UIImagePickerController：前者跑在系统进程里，用户选中哪张就只交出哪张，
// 应用既不需要相册读取授权，也不会触发出现在启动阶段的「访问所有照片」弹窗。
// 这也是隐私政策里「仅访问您明确选择的图片」能够成立的前提。

public struct FloorplanImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode

    public init(selectedImage: Binding<UIImage?>, onImagePicked: (() -> Void)? = nil) {
        self._selectedImage = selectedImage
        self.onImagePicked = onImagePicked
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        // 不做「所有照片」的隐式授权：选中即返回，由我们按需降采样。
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: FloorplanImagePicker

        init(_ parent: FloorplanImagePicker) {
            self.parent = parent
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                // Floor plans from modern cameras can exceed 10,000 px and keep
                // hundreds of MB alive while the SwiftUI canvas is displayed.
                // The canvas is only a few hundred points high and is used for
                // room placement rather than pixel-level editing. Keep enough
                // detail for alignment while bounding the decoded bitmap to a
                // much smaller memory footprint.
                let downsized = Self.downsample(image, maxDimension: 2048)
                DispatchQueue.main.async {
                    self.parent.selectedImage = downsized
                    self.parent.onImagePicked?()
                }
            }
        }

        private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            let longestPixelSide = max(pixelWidth, pixelHeight)
            guard longestPixelSide > maxDimension, longestPixelSide > 0 else { return image }
            let scale = maxDimension / longestPixelSide
            let targetSize = CGSize(width: max(1, pixelWidth * scale),
                                    height: max(1, pixelHeight * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}
