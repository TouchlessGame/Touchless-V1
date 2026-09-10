import Foundation
import CoreGraphics

struct HandData: Equatable {
    var indexTip: CGPoint = .zero
    var thumbTip: CGPoint = .zero
    var wrist: CGPoint = .zero
    var allPoints: [CGPoint] = []
    var isDetected: Bool = false
    
    // Helper to calculate the center of the hand (for the "Stomp" and "Punch" logic)
    var center: CGPoint {
        guard !allPoints.isEmpty else { return .zero }
        let sumX = allPoints.map { $0.x }.reduce(0, +)
        let sumY = allPoints.map { $0.y }.reduce(0, +)
        return CGPoint(x: sumX / CGFloat(allPoints.count), y: sumY / CGFloat(allPoints.count))
    }
}
