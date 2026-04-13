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
            }
        }
    }
}
