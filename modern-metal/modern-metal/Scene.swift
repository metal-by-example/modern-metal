
import MetalKit
import simd

struct Light {
    var worldPosition = float3(0, 0, 0)
    var color = float3(0, 0, 0)
}

class Material {
    var specularColor = float3(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
}

class Node {
    var name: String
    weak var parent: Node?
    var children = [Node]()
    var modelMatrix = matrix_identity_float4x4
    var mesh: MTKMesh?
    var material = Material()
    
    init(name: String) {
        self.name = name
    }

    func nodeNamedRecursive(_ name: String) -> Node? {
        for node in children {
            if node.name == name {
                return node
            } else if let matchingGrandchild = node.nodeNamedRecursive(name) {
                return matchingGrandchild
            }
        }
        return nil
    }
}

class Scene {
    var rootNode = Node(name: "Root")
    var ambientLightColor = float3(0, 0, 0)
    var lights = [Light]()

    func nodeNamed(_ name: String) -> Node? {
        if rootNode.name == name {
            return rootNode
        } else {
            return rootNode.nodeNamedRecursive(name)
        }
    }
}
