import Foundation
import Vision
import AVFoundation
import Combine

class TrackingEngine: NSObject, ObservableObject {
    @Published var hands: [HandData] = []
    @Published var session = AVCaptureSession()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            
            handPoseRequest.maximumHandCount = 4
        } catch {
            print(error)
        }
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
}

extension TrackingEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            
            guard let observations = handPoseRequest.results, !observations.isEmpty else {
                DispatchQueue.main.async { self.hands = [] }
                return
            }
            
            var detectedHands: [HandData] = []
            
            for observation in observations {
                do {
                    let allPointsDict = try observation.recognizedPoints(.all)
                    let allCGPoints = allPointsDict.values.filter { $0.confidence > 0.3 }.map {
                        CGPoint(x: $0.location.x, y: $0.location.y)
                    }
                    
                    let indexTip = try observation.recognizedPoint(.indexTip)
                    let thumbTip = try observation.recognizedPoint(.thumbTip)
                    let wrist = try observation.recognizedPoint(.wrist)
                    
                    let hand = HandData(
                        indexTip: CGPoint(x: indexTip.location.x, y: indexTip.location.y),
                        thumbTip: CGPoint(x: thumbTip.location.x, y: thumbTip.location.y),
                        wrist: CGPoint(x: wrist.location.x, y: wrist.location.y),
                        allPoints: allCGPoints,
                        isDetected: true
                    )
                    
                    detectedHands.append(hand)
                } catch {
                    continue
                }
            }
            
            DispatchQueue.main.async {
                self.hands = detectedHands
            }
            
        } catch {
            print(error)
        }
    }
}
