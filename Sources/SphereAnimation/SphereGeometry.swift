import Metal
import simd
import CSphereAnimationTypes

struct SphereGeometry {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    // Generate icosphere with specified subdivision level
    // Level 0 = 20 triangles, Level 1 = 80 triangles, Level 2 = 320 triangles
    static func createIcosphere(device: MTLDevice, radius: Float = 1.0, subdivisions: Int = 2) -> SphereGeometry? {
        var indices: [UInt16] = []

        // Golden ratio for icosahedron
        let phi = (1.0 + sqrt(5.0)) / 2.0
        let a: Float = 1.0
        let b = Float(1.0 / phi)

        // Create initial icosahedron vertices (12 vertices)
        let icosahedronVertices: [SIMD3<Float>] = [
            SIMD3(-b, a, 0), SIMD3(b, a, 0), SIMD3(-b, -a, 0), SIMD3(b, -a, 0),
            SIMD3(0, -b, a), SIMD3(0, b, a), SIMD3(0, -b, -a), SIMD3(0, b, -a),
            SIMD3(a, 0, -b), SIMD3(a, 0, b), SIMD3(-a, 0, -b), SIMD3(-a, 0, b)
        ]

        let baseVertices = icosahedronVertices.map { normalize($0) }

        // Create initial icosahedron faces (20 triangles)
        var triangles: [(UInt16, UInt16, UInt16)] = [
            // 5 faces around point 0
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            // Adjacent faces
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            // 5 faces around point 3
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            // Adjacent faces
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]

        // Start with base vertices
        var currentVertices = baseVertices

        // Subdivide triangles
        for _ in 0..<subdivisions {
            var newTriangles: [(UInt16, UInt16, UInt16)] = []
            var midpointCache: [UInt32: UInt16] = [:]

            func getMiddlePoint(_ v1: UInt16, _ v2: UInt16) -> UInt16 {
                // Ensure consistent key regardless of order
                let smallerIndex = min(v1, v2)
                let largerIndex = max(v1, v2)
                let key = (UInt32(smallerIndex) << 16) + UInt32(largerIndex)

                if let index = midpointCache[key] {
                    return index
                }

                // Calculate midpoint
                let point1 = currentVertices[Int(v1)]
                let point2 = currentVertices[Int(v2)]
                let middle = normalize((point1 + point2) / 2.0)

                // Add to vertices
                currentVertices.append(middle)
                let index = UInt16(currentVertices.count - 1)
                midpointCache[key] = index
                return index
            }

            // Subdivide each triangle into 4 triangles
            for triangle in triangles {
                let a = getMiddlePoint(triangle.0, triangle.1)
                let b = getMiddlePoint(triangle.1, triangle.2)
                let c = getMiddlePoint(triangle.2, triangle.0)

                newTriangles.append((triangle.0, a, c))
                newTriangles.append((triangle.1, b, a))
                newTriangles.append((triangle.2, c, b))
                newTriangles.append((a, b, c))
            }

            triangles = newTriangles
        }

        // Scale vertices to desired radius
        let scaledVertices = currentVertices.map { $0 * radius }

        // Build vertex buffer with positions and normals
        var vertexData: [VertexIn] = []
        for vertex in scaledVertices {
            let normal = normalize(vertex)  // For sphere, normal = normalized position
            vertexData.append(VertexIn(position: vertex, normal: normal))
        }

        // Build index buffer
        for triangle in triangles {
            indices.append(triangle.0)
            indices.append(triangle.1)
            indices.append(triangle.2)
        }

        // Create Metal buffers
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: MemoryLayout<VertexIn>.stride * vertexData.count,
            options: .storageModeShared
        ) else {
            return nil
        }

        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        ) else {
            return nil
        }

        return SphereGeometry(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: indices.count
        )
    }
}
