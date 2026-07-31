import SwiftUI
import AVFoundation

/// Live camera QR scanner (AVCaptureMetadataOutput). Calls `onCode` for every decoded QR payload.
struct QRScannerView: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeUIView(context: Context) -> ScannerUIView {
        let view = ScannerUIView()
        view.onCode = onCode
        view.start()
        return view
    }

    func updateUIView(_ uiView: ScannerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: ScannerUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class ScannerUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {

    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "wakeqr.scanner")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastReport = Date.distantPast

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.sessionQueue.async { self.configureAndRun() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        guard session.inputs.isEmpty else {
            if !session.isRunning { session.startRunning() }
            return
        }
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { self.attachPreview() }
    }

    private func attachPreview() {
        guard previewLayer == nil else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        // Rate-limit so a wrong code doesn't spam the UI.
        guard Date().timeIntervalSince(lastReport) > 0.8 else { return }
        for object in metadataObjects {
            if let qr = object as? AVMetadataMachineReadableCodeObject,
               qr.type == .qr, let value = qr.stringValue {
                lastReport = Date()
                onCode?(value)
                break
            }
        }
    }
}
