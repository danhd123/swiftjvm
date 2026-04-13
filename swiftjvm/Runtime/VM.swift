//
//  VM.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

struct VM {
    var threads: [Thread] = []
    var classLoader: ClassLoader
    var mainMethod: MethodInfo? = nil
    var mainClass: Class?

    init(classpath: [URL]) {
        self.classLoader = ClassLoader(classpath: classpath)
    }

    mutating func loadClass(_ classFile: ClassFile) {
        let cls = classLoader.preload(classFile)
        if let main = cls.findMethod(named: "main", descriptor: "([Ljava/lang/String;)V") {
            if main.accessFlags.rawValue & MethodInfo.AccessFlags.Static.rawValue != 0 {
                if mainMethod != nil {
                    fatalError("Can't have two main methods")
                }
                mainMethod = main
                mainClass = cls
            }
        }
    }

    func start() -> Never {
        guard let mainMethod, let mainClass else {
            fatalError("No main method found")
        }
        var mainThread = Thread()
        let mainFrame = Frame(classFile: mainClass.classFile, constantPool: mainClass.classFile.constantPool, method: mainMethod)
        mainThread.stackFrames.append(mainFrame)
        mainFrame.execute()
        exit(0)
    }
}
