# SphereAnimation

A SwiftUI library for rendering animated 3D spheres using Metal. Features smooth color transitions, physics-based collisions, and customizable appearance.

## Features

- GPU-accelerated rendering with Metal
- Multiple animated spheres with collision physics
- Smooth color cycling with Phong lighting
- Customizable sphere properties (size, speed, glow, colors)
- Supports iOS and macOS

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SphereAnimation.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Basic Usage

```swift
import SwiftUI
import SphereAnimation

struct ContentView: View {
    var body: some View {
        SphereAnimationView(colors: [.blue, .purple, .pink])
    }
}
```

### Multiple Spheres with Custom Configuration

```swift
SphereAnimationView(spheres: [
    .small(colors: [.blue, .cyan]),
    .large(colors: [.purple, .pink]),
    .glowing(colors: [.orange, .red])
])
```

### Random Spheres

```swift
SphereAnimationView(randomSpheres: 5, colors: [.blue, .purple, .pink, .orange])
```

### Custom Configuration

```swift
let customSphere = SphereConfig(
    colors: [.red, .orange, .yellow],
    glowIntensity: 2.0,    // 0.0-3.0
    radius: 30.0,          // 10-100 points
    speed: 50.0,           // 10-200 points/second
    mass: 1.5,             // affects collision momentum
    elasticity: 0.9        // 0.0-1.0 (bounciness)
)

SphereAnimationView(spheres: [customSphere])
```

## Configuration Options

### SphereConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `colors` | `[Color]` | Required | Colors for cycling animation |
| `glowIntensity` | `Float` | 1.0 | Glow/emission intensity (0.0-3.0) |
| `radius` | `Float` | 25.0 | Sphere radius in points (10-100) |
| `speed` | `Float` | 40.0 | Movement speed in points/second (10-200) |
| `mass` | `Float` | 1.0 | Mass for collision physics |
| `elasticity` | `Float` | 0.8 | Bounciness coefficient (0.0-1.0) |

### Preset Configurations

- `.default` — Blue/purple medium sphere
- `.small(colors:)` — Small, fast-moving sphere
- `.large(colors:)` — Large, slow-moving sphere
- `.glowing(colors:)` — Medium sphere with high glow

## License

MIT License
