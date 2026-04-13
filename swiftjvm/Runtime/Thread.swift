//
//  Thread.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

class Thread {
    var pc: Int = 0
    var stackFrames: [Frame] = []
    var currentFrame: Frame? { stackFrames.first }
    var currentClass: ClassOrModuleOrPackageConstant? { currentFrame?.currentClass } // aim to remove these optionals
    // TODO: current method, current class (once Frame is filled out)
    // TODO: figure out native methods
    
    func execute() {
        guard let currentFrame else { return }
        let codeAttributeInfo = currentFrame.method.attributes.first { $0.isKind(of: CodeAttribute.self) }
        guard let codeAttributeInfo, let codeAttribute = codeAttributeInfo as? CodeAttribute else { return }
        let codeData = codeAttribute.code
        while true {
            currentFrame.executeNextInstruction(data: codeData, pc: &pc)
        }
        
    }

}
