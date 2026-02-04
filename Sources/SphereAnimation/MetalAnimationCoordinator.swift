import Foundation
import simd
import CoreGraphics

// MARK: - SphereState

/// Internal state for a single animated sphere
struct SphereState {
    var config: SphereConfig
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var currentTime: Float  // Independent color cycling per sphere
}

// MARK: - MetalAnimationCoordinator

class MetalAnimationCoordinator {
    // Animation state
    private(set) var spheres: [SphereState] = []
    private var viewBounds: CGSize

    // Animation properties
    let colorCycleDuration: Float = 8.0  // 8 seconds for one full color cycle (slow and smooth)

    init(viewBounds: CGSize, sphereConfigs: [SphereConfig]) {
        self.viewBounds = viewBounds
        self.initializeSpheres(configs: sphereConfigs, bounds: viewBounds)
    }

    // MARK: - Sphere Initialization

    private func initializeSpheres(configs: [SphereConfig], bounds: CGSize) {
        let width = Float(bounds.width)
        let height = Float(bounds.height)

        // Handle invalid bounds
        guard width > 50 && height > 50 else {
            // Just create spheres in center, will be repositioned when bounds update
            for config in configs {
                let position = SIMD2<Float>(width / 2, height / 2)
                let angle = Float.random(in: 0...(2 * .pi))
                let velocity = SIMD2(cos(angle), sin(angle)) * config.speed

                spheres.append(SphereState(
                    config: config,
                    position: position,
                    velocity: velocity,
                    currentTime: 0
                ))
            }
            return
        }

        // Initialize each sphere with overlap prevention
        for config in configs {
            var position: SIMD2<Float>?
            var attempts = 0
            let maxAttempts = 20

            // Try to find non-overlapping position
            while attempts < maxAttempts {
                let candidateX = Float.random(in: config.radius...(width - config.radius))
                let candidateY = Float.random(in: config.radius...(height - config.radius))
                let candidate = SIMD2<Float>(candidateX, candidateY)

                // Check if this position overlaps with existing spheres
                let overlaps = spheres.contains { existingSphere in
                    let distance = length(candidate - existingSphere.position)
                    let minDistance = config.radius + existingSphere.config.radius
                    return distance < minDistance
                }

                if !overlaps {
                    position = candidate
                    break
                }

                attempts += 1
            }

            // Fallback: use any position if we couldn't find a non-overlapping one
            // (they will separate on first collision)
            if position == nil {
                position = SIMD2<Float>(
                    Float.random(in: config.radius...(width - config.radius)),
                    Float.random(in: config.radius...(height - config.radius))
                )
            }

            // Set initial velocity
            let angle = Float.random(in: 0...(2 * .pi))
            let velocity = SIMD2(cos(angle), sin(angle)) * config.speed

            spheres.append(SphereState(
                config: config,
                position: position!,
                velocity: velocity,
                currentTime: Float.random(in: 0...colorCycleDuration)  // Random start time for variety
            ))
        }
    }

    // MARK: - Physics Update

    func update(deltaTime: Float) {
        // Clamp deltaTime to prevent huge jumps (e.g., when app was paused)
        let clampedDelta = min(deltaTime, 1.0 / 30.0)  // Max 30 FPS equivalent

        // Get current bounds
        let width = Float(viewBounds.width)
        let height = Float(viewBounds.height)

        // Skip physics if bounds are invalid
        guard width > 0 && height > 0 else { return }

        // Update all sphere positions and animation times
        for i in 0..<spheres.count {
            spheres[i].currentTime += clampedDelta
            spheres[i].position += spheres[i].velocity * clampedDelta
        }

        // Handle boundary collisions for each sphere
        for i in 0..<spheres.count {
            handleBoundaryCollision(index: i, width: width, height: height)
        }

        // Handle sphere-to-sphere collisions (Phase 3)
        handleSphereCollisions()

        // Maintain sphere velocities to prevent gradual slowdown
        maintainVelocities(deltaTime: clampedDelta)
    }

    /// Gradually restore sphere velocities to target speed
    /// This compensates for energy loss from elasticity < 1.0
    private func maintainVelocities(deltaTime: Float) {
        let recoveryRate: Float = 0.5  // Recover 50% of lost speed per second

        for i in 0..<spheres.count {
            let currentSpeed = length(spheres[i].velocity)
            let targetSpeed = spheres[i].config.speed

            // Only restore if sphere is moving and below target speed
            guard currentSpeed > 0.001 else { continue }

            if currentSpeed < targetSpeed {
                // Calculate how much to recover this frame
                let speedDiff = targetSpeed - currentSpeed
                let recovery = speedDiff * recoveryRate * deltaTime
                let newSpeed = currentSpeed + recovery

                // Preserve direction, adjust magnitude
                let direction = spheres[i].velocity / currentSpeed
                spheres[i].velocity = direction * newSpeed
            }
        }
    }

    private func handleBoundaryCollision(index: Int, width: Float, height: Float) {
        var sphere = spheres[index]
        let radius = sphere.config.radius
        var didBounce = false

        // Left wall
        if sphere.position.x <= radius {
            sphere.position.x = radius
            if sphere.velocity.x < 0 {
                sphere.velocity.x = -sphere.velocity.x * sphere.config.elasticity
                didBounce = true
            }
        }

        // Right wall
        if sphere.position.x >= width - radius {
            sphere.position.x = width - radius
            if sphere.velocity.x > 0 {
                sphere.velocity.x = -sphere.velocity.x * sphere.config.elasticity
                didBounce = true
            }
        }

        // Top wall
        if sphere.position.y <= radius {
            sphere.position.y = radius
            if sphere.velocity.y < 0 {
                sphere.velocity.y = -sphere.velocity.y * sphere.config.elasticity
                didBounce = true
            }
        }

        // Bottom wall
        if sphere.position.y >= height - radius {
            sphere.position.y = height - radius
            if sphere.velocity.y > 0 {
                sphere.velocity.y = -sphere.velocity.y * sphere.config.elasticity
                didBounce = true
            }
        }

        // Add slight random angle variation on bounce to prevent repetitive patterns
        // Only affects direction, not speed (to avoid cumulative energy loss)
        if didBounce {
            let angleVariation: Float = 0.05  // ~3 degrees max
            let randomAngle = Float.random(in: -angleVariation...angleVariation)
            let cosA = cos(randomAngle)
            let sinA = sin(randomAngle)
            let rotatedVelocity = SIMD2<Float>(
                sphere.velocity.x * cosA - sphere.velocity.y * sinA,
                sphere.velocity.x * sinA + sphere.velocity.y * cosA
            )
            sphere.velocity = rotatedVelocity
        }

        spheres[index] = sphere
    }

    private func handleSphereCollisions() {
        // O(n²) collision detection - acceptable for 3-10 spheres
        for i in 0..<spheres.count {
            for j in (i+1)..<spheres.count {
                if detectCollision(sphere1Index: i, sphere2Index: j) {
                    resolveCollision(sphere1Index: i, sphere2Index: j)
                }
            }
        }
    }

    // MARK: - Collision Physics

    private func detectCollision(sphere1Index: Int, sphere2Index: Int) -> Bool {
        let sphere1 = spheres[sphere1Index]
        let sphere2 = spheres[sphere2Index]

        let distance = length(sphere1.position - sphere2.position)
        let minDistance = sphere1.config.radius + sphere2.config.radius

        return distance < minDistance
    }

    private func resolveCollision(sphere1Index: Int, sphere2Index: Int) {
        var sphere1 = spheres[sphere1Index]
        var sphere2 = spheres[sphere2Index]

        let r1 = sphere1.config.radius
        let r2 = sphere2.config.radius

        // Calculate collision normal
        let delta = sphere1.position - sphere2.position
        let distance = length(delta)

        // Prevent division by zero
        guard distance > 0.001 else { return }

        let normal = delta / distance

        // Separate overlapping spheres
        let overlap = (r1 + r2) - distance
        let epsilon: Float = 0.1  // Small separation to prevent sticking

        sphere1.position += normal * ((overlap / 2) + epsilon)
        sphere2.position -= normal * ((overlap / 2) + epsilon)

        // Calculate relative velocity
        let relVel = sphere1.velocity - sphere2.velocity
        let velAlongNormal = dot(relVel, normal)

        // Spheres are already moving apart
        if velAlongNormal > 0 { return }

        // Calculate impulse (elastic collision with mass)
        let e = min(sphere1.config.elasticity, sphere2.config.elasticity)
        let m1 = sphere1.config.mass
        let m2 = sphere2.config.mass

        let j = -(1 + e) * velAlongNormal / (1 / m1 + 1 / m2)

        // Apply impulse to velocities
        let impulse1 = (normal * j) / m1
        let impulse2 = (normal * j) / m2

        sphere1.velocity += impulse1
        sphere2.velocity -= impulse2

        // Update spheres
        spheres[sphere1Index] = sphere1
        spheres[sphere2Index] = sphere2
    }

    // MARK: - View Bounds Management

    func updateViewBounds(_ newBounds: CGSize) {
        let oldWidth = viewBounds.width
        let oldHeight = viewBounds.height

        viewBounds = newBounds

        // If bounds changed significantly (first render or rotation), adjust sphere positions
        let widthChanged = abs(newBounds.width - oldWidth) > 10
        let heightChanged = abs(newBounds.height - oldHeight) > 10
        let wasVerySmall = oldWidth < 100 || oldHeight < 100
        let isNowBig = newBounds.width > 100 && newBounds.height > 100

        if (widthChanged || heightChanged) && wasVerySmall && isNowBig {
            // Reinitialize positions in center of new bounds when view becomes valid
            let width = Float(newBounds.width)
            let height = Float(newBounds.height)

            for i in 0..<spheres.count {
                spheres[i].position = SIMD2(width / 2, height / 2)
            }
        } else if widthChanged || heightChanged {
            // Just clamp all sphere positions to new bounds
            for i in 0..<spheres.count {
                let radius = spheres[i].config.radius
                let minX = radius
                let maxX = Float(newBounds.width) - radius
                let minY = radius
                let maxY = Float(newBounds.height) - radius

                spheres[i].position.x = max(minX, min(maxX, spheres[i].position.x))
                spheres[i].position.y = max(minY, min(maxY, spheres[i].position.y))
            }
        }
    }

    // MARK: - Configuration Updates

    /// Update sphere configurations (e.g., when view props change)
    func updateSphereConfigs(_ newConfigs: [SphereConfig]) {
        // If count changed, reinitialize everything
        if newConfigs.count != spheres.count {
            initializeSpheres(configs: newConfigs, bounds: viewBounds)
            return
        }

        // Otherwise just update configs, preserving physics state
        for i in 0..<newConfigs.count {
            var sphere = spheres[i]
            let oldSpeed = sphere.config.speed
            let newSpeed = newConfigs[i].speed

            sphere.config = newConfigs[i]

            // Adjust velocity if speed changed
            if oldSpeed != newSpeed && oldSpeed > 0 {
                let currentDirection = normalize(sphere.velocity)
                sphere.velocity = currentDirection * newSpeed
            }

            spheres[i] = sphere
        }
    }

    // MARK: - Accessors for Backward Compatibility

    /// Provides first sphere position for backward compatibility with single-sphere rendering
    var spherePosition: SIMD2<Float> {
        spheres.first?.position ?? SIMD2<Float>(0, 0)
    }

    var currentTime: Float {
        spheres.first?.currentTime ?? 0
    }
}
