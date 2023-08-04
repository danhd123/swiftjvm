//
//  Thread.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

struct Thread {
    var pc: UInt64 = 0
    var stackFrames: [Frame] = []
    var currentFrame: Frame? { stackFrames.first }
    var currentClass: ClassOrModuleOrPackageConstant? { currentFrame?.currentClass } // aim to remove these optionals
    // TODO: current method, current class (once Frame is filled out)
    // TODO: figure out native methods
}
