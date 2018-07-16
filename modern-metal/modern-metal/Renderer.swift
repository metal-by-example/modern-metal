
import Foundation
import MetalKit
import simd

struct Uniforms {
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var renderPipeline: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let samplerState: MTLSamplerState
    var vertexDescriptor: MDLVertexDescriptor
    var baseColorTexture: MTLTexture?
    var meshes: [MTKMesh] = []
    var time: Float = 0
    
    init(view: MTKView, device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        vertexDescriptor = Renderer.buildVertexDescriptor()
        renderPipeline = Renderer.buildPipeline(device: device, view: view, vertexDescriptor: vertexDescriptor)
        samplerState = Renderer.buildSamplerState(device: device)
        depthStencilState = Renderer.buildDepthStencilState(device: device)
        super.init()
        loadResources()
    }
    
    func loadResources() {
        let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj")!
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        } catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
        baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
    }
    
    static func buildVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: MemoryLayout<Float>.size * 3,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: MemoryLayout<Float>.size * 6,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        return vertexDescriptor
    }
    
    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }
    
    static func buildPipeline(device: MTLDevice, view: MTKView, vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

        let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            commandEncoder.setDepthStencilState(depthStencilState)
            
            time += 1 / Float(view.preferredFramesPerSecond)
            let angle = -time
            let modelMatrix = float4x4(rotationAbout: float3(0, 1, 0), by: angle) *  float4x4(scaleBy: 2)

            let viewMatrix = float4x4(translationBy: float3(0, 0, -2))
            let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
            let viewProjectionMatrix = projectionMatrix * viewMatrix
            
            var uniforms = Uniforms(modelMatrix: modelMatrix, viewProjectionMatrix: viewProjectionMatrix, normalMatrix: modelMatrix.normalMatrix)
            
            commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            
            commandEncoder.setFragmentTexture(baseColorTexture, index: 0)
            
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            
            commandEncoder.setRenderPipelineState(renderPipeline)
            
            for mesh in meshes {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                
                for submesh in mesh.submeshes {
                    let indexBuffer = submesh.indexBuffer
                    commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                         indexCount: submesh.indexCount,
                                                         indexType: submesh.indexType,
                                                         indexBuffer: indexBuffer.buffer,
                                                         indexBufferOffset: indexBuffer.offset)
                }
            }
            
            commandEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            
            commandBuffer.commit()
        }
    }
}
