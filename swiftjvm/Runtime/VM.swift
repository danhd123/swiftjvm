//
//  VM.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

struct VM {
    var threads: [Thread] = []
    var methodArea: [ClassFile] = []
    var mainMethod: MethodInfo? = nil
    var mainClass: ClassFile?
    
    mutating func loadClass(_ classFile: ClassFile) {
        methodArea.append(classFile)
        for method in classFile.methods {
            if method.accessFlags.rawValue & MethodInfo.AccessFlags.Static.rawValue != 0 && method.name.string as String == "main" && method.descriptor.string as String == "([Ljava/lang/String;)V" {
                if mainMethod != nil {
                    fatalError("Can't have two main methods")
                }
                mainMethod = method
                mainClass = classFile
            }
        }
    }
    
    func start() -> Never {
        guard let mainMethod, let mainClass else {
            fatalError("No main method fouund")
        }
        var mainThread = Thread()
        let mainFrame = Frame(classFile: mainClass, constantPool: mainClass.constantPool, method: mainMethod)
        mainThread.stackFrames.append(mainFrame)
        mainFrame.execute()
        exit(0)
    }
}
