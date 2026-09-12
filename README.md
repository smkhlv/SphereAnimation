# SphereAnimation

A SwiftUI library for rendering animated 3D spheres using Metal. Features smooth color transitions, physics-based collisions, and customizable appearance.

Current stable version: **1.0.0**.

<p align="center">
  <img src="Simulator%20Screen%20Recording%20-%20iPhone%2017%20-%202026-02-04%20at%2015.00.45.gif" width="300" alt="SphereAnimation Demo">
</p>

## Features

- GPU-accelerated rendering with Metal
- Multiple animated spheres with collision physics
- Smooth color cycling with Phong lighting
- Customizable sphere properties (size, speed, glow, colors)
- Optional zero-copy Metal frame delivery with GPU readiness and exactly-once lifetime ownership
- Supports iOS and macOS

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/smkhlv/SphereAnimation.git", from: "1.0.0")
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

### Metal Frame Output

Use `onFrame` when another Metal pipeline needs the rendered texture. The callback
receives a `SphereRenderedFrame` containing the texture and the shared-event value
that marks it ready. Encode a GPU-side wait on `readinessEvent`/`readinessValue`,
then call `release()` only after the final consumer command buffer has completed.

```swift
SphereAnimationView(spheres: spheres) { frame in
    commandBuffer.encodeWaitForEvent(
        frame.readinessEvent,
        value: frame.readinessValue
    )

    // Encode work that samples frame.texture, then return the producer lease
    // only after that GPU work is complete.
    commandBuffer.addCompletedHandler { _ in
        frame.release()
    }
}
```

Copies of a frame share one lease, so `release()` is safe to call more than once.
When `onFrame` is omitted, SphereAnimation releases frames automatically.

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
