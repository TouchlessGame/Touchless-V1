import CoreGraphics
import SwiftUI

// 1. Defines which half of the screen the game is rendering
enum PlayerZone {
    case solo, leftPlayer, rightPlayer
}

// 2. The Universal Lens
struct CoordinateMapper {
    
    // FILTERS: Tells the scene if it should ignore a hand
    static func belongsToZone(rawX: CGFloat, zone: PlayerZone) -> Bool {
        let mirroredX = 1.0 - rawX // Automatically handles camera mirroring
        
        switch zone {
        case .solo: return true
        case .leftPlayer: return mirroredX < 0.5  // Left half of physical room
        case .rightPlayer: return mirroredX >= 0.5 // Right half of physical room
        }
    }
    
    // MATH: Converts the raw camera data into perfect local pixel coordinates
    static func localPoint(rawPoint: CGPoint, zone: PlayerZone, screenSize: CGSize) -> CGPoint {
        let mirroredX = 1.0 - rawPoint.x
        var zonedX = mirroredX
        
        // Stretches their half of the room to feel like a full screen
        if zone == .leftPlayer {
            zonedX = mirroredX * 2.0
        } else if zone == .rightPlayer {
            zonedX = (mirroredX - 0.5) * 2.0
        }
        
        // Vision origin is lower-left (0 at bottom, 1 at top)
        // SwiftUI origin is top-left (0 at top, height at bottom)
        let invertedY = 1.0 - rawPoint.y
        
        return CGPoint(
            x: zonedX * screenSize.width,
            y: invertedY * screenSize.height
        )
    }
}
