
import Foundation
import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let mtkView: MTKView
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
    }
}
