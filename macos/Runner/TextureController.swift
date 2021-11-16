//
//  TextureController.swift
//  Runner
//
//  Created by Pedro Tacla Yamada on 15/11/21.
//

import Foundation
import FlutterMacOS

import CoreVideo
import Metal
import AppKit

struct Vertex {
  var position: SIMD4<Float>
  var coord: SIMD2<Float>
}

struct Uniform {
  var tick: Float
}

class Texture: NSObject, FlutterTexture {
  var id: Int64 = 0
  let flutterTextureRegistry: FlutterTextureRegistry
  let metalDevice = MTLCreateSystemDefaultDevice()
  var textureCache: CVMetalTextureCache?
  var target: Unmanaged<CVPixelBuffer>?
  var metalCVTexture: CVMetalTexture?
  var metalTexture: MTLTexture?
  var ioSurfaceRef: IOSurfaceRef?
  var tick: Float = 0.0
  var running = true
  var state: MTLRenderPipelineState?
  var commandQueue: MTLCommandQueue?
  var displayLink: CVDisplayLink?

  init(_ flutterTextureRegistry: FlutterTextureRegistry) {
    self.flutterTextureRegistry = flutterTextureRegistry
    super.init()
    guard let ioSurfaceRef = IOSurfaceCreate([
      kIOSurfaceWidth: 200,
      kIOSurfaceHeight: 200,
      kIOSurfaceBytesPerElement: 4,
      kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA
    ] as CFDictionary) else {
      fatalError("Failed to create IOSurface")
    }
    self.ioSurfaceRef = ioSurfaceRef

    guard CVPixelBufferCreateWithIOSurface(
      kCFAllocatorDefault,
      ioSurfaceRef,
      [
        kCVPixelBufferMetalCompatibilityKey: true
      ] as CFDictionary,
      &target
    ) == kCVReturnSuccess else {
      fatalError("Failed to create CVPixelBuffer")
    }

    guard CVMetalTextureCacheCreate(
      kCFAllocatorDefault,
      nil,
      metalDevice!,
      nil,
      &textureCache
    ) == kCVReturnSuccess else {
      fatalError("Failed to create texture cache")
    }

    guard CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      textureCache!,
      target!.takeUnretainedValue(),
      nil,
      .bgra8Unorm,
      200,
      200,
      0,
      &metalCVTexture
    ) == kCVReturnSuccess else {
      fatalError("Failed to bind CVPixelBuffer to metal texture")
    }

    metalTexture = CVMetalTextureGetTexture(metalCVTexture!)

    DispatchQueue.global(qos: .userInitiated).async {
      let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
      renderPipelineDescriptor.fragmentFunction =  self.metalDevice?.makeDefaultLibrary()?.makeFunction(name: "fragmentShader")
      renderPipelineDescriptor.vertexFunction = self.metalDevice?.makeDefaultLibrary()?.makeFunction(name: "vertexShader")
      renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      guard let state = try! self.metalDevice?.makeRenderPipelineState(
        descriptor: renderPipelineDescriptor
      ) else {
        fatalError("Failed to create pipeline state")
      }

      guard let commandQueue = self.metalDevice?.makeCommandQueue(maxCommandBufferCount: 10) else {
        fatalError("Failed to create metal command queue")
      }

      self.renderLoop(state, commandQueue)
    }
  }

  func renderLoop(_ state: MTLRenderPipelineState, _ commandQueue: MTLCommandQueue) {
    var displayLink: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(
      &displayLink
    )
    self.state = state
    self.commandQueue = commandQueue

    let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
      let texture = Unmanaged<Texture>.fromOpaque(userInfo!).takeUnretainedValue()
      texture.renderImage(texture.state!, texture.commandQueue!)
      return kCVReturnSuccess
    }

    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    CVDisplayLinkSetOutputCallback(
      displayLink!,
      callback,
      userInfo
    )
    CVDisplayLinkStart(displayLink!)
    self.displayLink = displayLink
  }

  func renderImage(_ state: MTLRenderPipelineState, _ commandQueue: MTLCommandQueue) {
    if !running {
      return
    }

    // Create render pass descriptor & bind to the texture
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = metalTexture
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 1.0, 0.0, 1.0)

    // Create command buffer
    let commandBuffer = commandQueue.makeCommandBuffer()

    let renderEncoder = commandBuffer?.makeRenderCommandEncoder(
      descriptor: renderPassDescriptor
    )
    renderEncoder?.setCullMode(.front)
    renderEncoder?.setRenderPipelineState(state)

    // Bind vertices
    let vertices = [
      Vertex(position: [-1, 1, 0, 1], coord: [0, 0]),
      Vertex(position: [1, -1, 0, 1], coord: [1, 1]),
      Vertex(position: [1, 1, 0, 1], coord: [1, 0]),

      Vertex(position: [-1, -1, 0, 1], coord: [0, 1]),
      Vertex(position: [1, -1, 0, 1], coord: [1, 1]),
      Vertex(position: [-1, 1, 0, 1], coord: [0, 0]),
    ]
    let vertexBuffer = metalDevice?.makeBuffer(
      bytes: vertices,
      length: MemoryLayout<Vertex>.stride * vertices.count,
      options: MTLResourceOptions.storageModeShared
    )
    renderEncoder?.setVertexBuffer(
      vertexBuffer,
      offset: 0,
      index: 0
    )

    // Bind uniform
    self.tick += 0.1
    var uniform = Uniform(tick: self.tick)
    let uniformBuffer = metalDevice?.makeBuffer(
      bytes: &uniform,
      length: MemoryLayout<Uniform>.stride * 1,
      options: MTLResourceOptions.storageModeShared
    )
    renderEncoder?.setFragmentBuffer(
      uniformBuffer,
      offset: 0,
      index: 1
    )

    // Draw vertices
    renderEncoder?.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: 6
    )
    renderEncoder?.endEncoding()

    // Commit the command buffer
    commandBuffer?.commit()

    // commandBuffer?.addCompletedHandler({ _ in
    // })
    self.notifyFrame()
  }

  func notifyFrame() {
    self.flutterTextureRegistry.textureFrameAvailable(self.id)
  }

  // The gist is flutter will drop this CVPixelBuffer so we
  // need to force it to be retained somehow
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    if let pixelBuffer = target?.takeUnretainedValue() {
      return Unmanaged.passRetained(pixelBuffer)
    } else {
      return nil
    }
  }

  deinit {
    self.running = false
  }
}

class TextureController {
  let flutterTextureRegistry: FlutterTextureRegistry
  let flutterViewController: FlutterViewController
  var texture: Texture?

  init(flutterViewController: FlutterViewController) {
    self.flutterViewController = flutterViewController
    let registrar = flutterViewController.registrar(forPlugin: "opengl_texture")
    let methodChannel = FlutterMethodChannel(
      name: "opengl_texture",
      binaryMessenger: registrar.messenger
    )
    self.flutterTextureRegistry = registrar.textures

    methodChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
      guard call.method == "get_texture_id" else {
        result(FlutterMethodNotImplemented)
        return
      }

      self?.getTextureId(result: result)
    })
  }

  func getTextureId(result: FlutterResult) {
    let texture = Texture(self.flutterTextureRegistry)
    let id = self.flutterTextureRegistry.register(texture)
    texture.id = id
    self.texture = texture
    result(id)
  }
}
