import SwiftUI

public struct SphereAnimationView: View {
    private let sphereConfigs: [SphereConfig]
    @Binding private var renderer: MetalRenderer?

    // MARK: - Initializers

    /// Primary initializer: Multiple spheres with custom configurations
    /// - Parameters:
    ///   - spheres: Array of sphere configurations
    ///   - renderer: Optional binding to receive the MetalRenderer instance.
    ///              Use `renderer?.currentTexture` to access the rendered frame.
    public init(spheres: [SphereConfig], renderer: Binding<MetalRenderer?> = .constant(nil)) {
        self.sphereConfigs = spheres.isEmpty ? [.default] : spheres
        self._renderer = renderer
    }

    /// Backward compatible: Single sphere from color array
    public init(colors: [Color], renderer: Binding<MetalRenderer?> = .constant(nil)) {
        let colors = colors.isEmpty ? [.blue] : colors
        self.sphereConfigs = [SphereConfig(colors: colors)]
        self._renderer = renderer
    }

    /// Convenience: Generate random spheres with varied properties
    public init(randomSpheres count: Int, colors: [Color], renderer: Binding<MetalRenderer?> = .constant(nil)) {
        let actualCount = max(1, min(count, 10)) // Clamp to 1-10
        let colors = colors.isEmpty ? [.blue, .purple] : colors

        self.sphereConfigs = (0..<actualCount).map { index in
            let colorSubset = [colors[index % colors.count]]
            let randomRadius = Float.random(in: 15.0...40.0)
            let randomSpeed = Float.random(in: 25.0...60.0)
            let randomGlow = Float.random(in: 0.7...2.0)

            return SphereConfig(
                colors: colorSubset,
                glowIntensity: randomGlow,
                radius: randomRadius,
                speed: randomSpeed,
                mass: randomRadius / 25.0, // Mass proportional to size
                elasticity: 0.8
            )
        }
        self._renderer = renderer
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Metal-rendered animated spheres
            MetalViewRepresentable(sphereConfigs: sphereConfigs, renderer: $renderer)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

extension SphereAnimationView {
    /// Preview helper for backward compatibility testing
    public static var singleSphere: SphereAnimationView {
        SphereAnimationView(colors: [.blue, .purple, .pink, .orange])
    }

    /// Preview helper for multi-sphere
    public static var multiSphere: SphereAnimationView {
        SphereAnimationView(spheres: [
            .small(colors: [.blue, .cyan]),
            .large(colors: [.purple, .pink]),
            .glowing(colors: [.orange, .red])
        ])
    }

    /// Preview helper for random spheres
    public static var randomSpheres: SphereAnimationView {
        SphereAnimationView(randomSpheres: 5, colors: [.blue, .purple, .pink, .orange])
    }
}

#Preview("Single Sphere") {
    SphereAnimationView.singleSphere
}

#Preview("Multi Sphere") {
    SphereAnimationView.multiSphere
}

#Preview("Random Spheres") {
    SphereAnimationView.randomSpheres
}
