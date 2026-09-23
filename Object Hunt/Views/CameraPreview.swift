import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        view.videoLayer = layer
        if layer.superlayer == nil {
            view.layer.addSublayer(layer)
        }
        layer.frame = view.bounds
        return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.videoLayer = layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = uiView.bounds
        CATransaction.commit()
    }
}

final class PreviewSurface: UIView {
    var videoLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        videoLayer?.frame = bounds
    }
}
