import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Configuration for individual sphere in BackgroundView
public struct SphereConfig: Hashable, Codable {
    // MARK: - Visual Properties

    /// Colors for cycling animation (at least 1 required)
    var colors: [CodableColor]

    /// Glow/emission intensity (0.0-3.0)
    var glowIntensity: Float

    /// Sphere radius in points (10-100)
    var radius: Float

    // MARK: - Physics Properties

    /// Movement speed in points per second (10-200)
    var speed: Float

    /// Mass for collision physics (affects momentum)
    var mass: Float

    /// Bounciness coefficient (0.0-1.0, where 1.0 = perfectly elastic)
    var elasticity: Float

    // MARK: - Internal State (not part of public API)

    /// Current position (managed by coordinator)
    var position: SIMD2<Float>?

    /// Current velocity (managed by coordinator)
    var velocity: SIMD2<Float>?

    // MARK: - Initialization

    public init(
        colors: [Color],
        glowIntensity: Float = 1.0,
        radius: Float = 25.0,
        speed: Float = 40.0,
        mass: Float = 1.0,
        elasticity: Float = 0.8
    ) {
        precondition(!colors.isEmpty, "At least one color is required")

        self.colors = colors.map { CodableColor($0) }
        self.glowIntensity = max(0.0, min(3.0, glowIntensity))
        self.radius = max(10.0, min(100.0, radius))
        self.speed = max(10.0, min(200.0, speed))
        self.mass = max(0.1, mass)
        self.elasticity = max(0.0, min(1.0, elasticity))
        self.position = nil
        self.velocity = nil
    }

    // MARK: - Convenience Constructors

    /// Default sphere configuration
    public static var `default`: SphereConfig {
        SphereConfig(colors: [.blue, .purple])
    }

    /// Small, fast-moving sphere
    public static func small(colors: [Color]) -> SphereConfig {
        SphereConfig(
            colors: colors,
            glowIntensity: 0.8,
            radius: 15.0,
            speed: 60.0,
            mass: 0.5,
            elasticity: 0.9
        )
    }

    /// Large, slow-moving sphere
    public static func large(colors: [Color]) -> SphereConfig {
        SphereConfig(
            colors: colors,
            glowIntensity: 1.5,
            radius: 40.0,
            speed: 25.0,
            mass: 2.0,
            elasticity: 0.7
        )
    }

    /// Medium sphere with high glow
    public static func glowing(colors: [Color]) -> SphereConfig {
        SphereConfig(
            colors: colors,
            glowIntensity: 2.5,
            radius: 30.0,
            speed: 35.0,
            mass: 1.2,
            elasticity: 0.8
        )
    }
}

// MARK: - CodableColor

/// Wrapper to make Color Codable for persistence
struct CodableColor: Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(_ color: Color) {
        // Convert Color to platform color to extract components
        #if canImport(UIKit)
        let platformColor = UIColor(color)
        #elseif canImport(AppKit)
        let platformColor = NSColor(color)
        #endif

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        platformColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    /// Convert back to SwiftUI Color
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
