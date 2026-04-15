//
//  Thread.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

class Thread {
    var stackFrames: [Frame] = []

    var currentFrame: Frame? { stackFrames.last }

    func execute() {
        while !stackFrames.isEmpty {
            let result = stackFrames.last!.executeNextInstruction()
            switch result {
            case .continue:
                break
            case .returned(let value):
                stackFrames.removeLast()
                if let value, !stackFrames.isEmpty {
                    stackFrames.last!.push(value)
                }
            case .invoke(let calleeFrame):
                stackFrames.append(calleeFrame)
            case .thrown(let exception):
                guard case .reference(let objOpt) = exception, let obj = objOpt else {
                    fatalError("Thread: thrown value is not a reference")
                }
                stackFrames.removeLast()   // pop the frame that couldn't handle it
                var handled = false
                while !stackFrames.isEmpty {
                    let callerFrame = stackFrames.last!
                    if let handlerPC = callerFrame.findExceptionHandler(
                            at: callerFrame.lastInstructionStart, for: obj) {
                        callerFrame.pc = handlerPC
                        callerFrame.push(exception)
                        handled = true
                        break
                    }
                    stackFrames.removeLast()
                }
                if !handled {
                    fputs("Exception in thread \"main\" \(obj.clazz.name)\n", stderr)
                    exit(1)
                }
            }
        }
    }
}
