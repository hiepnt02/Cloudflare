//
//  MetalCommandBuiler.swift
//  Quick3D
//
//  Created by HaNST on 6/11/25.
//

import Foundation
import Metal


class MetalCommandBuilder {
    
    let manager: MetalManager
    
    var commands: [MetalCommand] = []
    var complition: (() -> Void)? = nil
    
    init(manager: MetalManager) {
        self.manager = manager
    }
    
    func add(_ command: MetalCommand) {
        commands.append(command)
    }
    
    func compute(name: String, count: Int, preparation: ((MetalComputeCommandContext) throws -> Void)? = nil) throws {
        add(try MetalComputeCommand(name: name, count: count, preparation: preparation))
    }
    
    func blit(preparation: @escaping (MetalBlitCommandContext) throws -> Void) throws {
        add(try MetalBlitCommand(preparation: preparation))
    }
    
    func render(vertex: String, fragment: String, descriptor: MTLRenderPassDescriptor, preparation: ((MTLRenderCommandEncoder) -> Void)? = nil) {
        add(MetalRenderCommand(vertex: vertex, fragment: fragment, descriptor: descriptor, preparation: preparation))
    }
    
    func onCompleted(_ complition: @escaping () -> Void) {
        self.complition = complition
    }
    
    func commit() {
        if !commands.isEmpty, let commandBuffer = manager.makeCommandBuffer() {
            for command in commands {
                command.commit(manager: manager, commandBuffer: commandBuffer)
            }
            commandBuffer.addCompletedHandler { _ in
                self.complition?()
                for command in self.commands {
                    command.release()
                }
                self.manager.count.value -= 1
            }
            manager.count.value += 1
            commandBuffer.commit()
        }
    }
}

extension MetalManager {
    func makeCommandBuilder() -> MetalCommandBuilder? {
        return MetalCommandBuilder(manager: self)
    }
}
