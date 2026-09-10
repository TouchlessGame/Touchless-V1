import SwiftUI
import AVFoundation
import AppKit

// 1. We create a dedicated Mac View to handle the video layer
class MacVideoPreviewView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer
    
    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.addSublayer(previewLayer)
        
        self.previewLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 2. This is the magic! It forces the video to ALWAYS match the window size.
    override func layout() {
        super.layout()
        previewLayer.frame = self.bounds
        
        // 3. The safest way to mirror the camera on Mac (avoids off-screen flipping)
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

// 4. The SwiftUI Wrapper
struct CameraView: NSViewRepresentable {
    let session: AVCaptureSession
    
    func makeNSView(context: Context) -> MacVideoPreviewView {
        return MacVideoPreviewView(session: session)
    }
    
    func updateNSView(_ nsView: MacVideoPreviewView, context: Context) {
        // We don't need to do anything here anymore! The MacVideoPreviewView handles itself.
    }
}
