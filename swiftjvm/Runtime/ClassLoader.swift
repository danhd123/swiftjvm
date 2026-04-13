//
//  ClassLoader.swift
//  swiftjvm
//

import Foundation

class ClassLoader {
    var classpath: [URL]
    private(set) var loadedClasses: [String: Class] = [:]

    init(classpath: [URL]) {
        self.classpath = classpath
    }

    // Pre-load an already-parsed class file (e.g. passed directly on the command line)
    @discardableResult
    func preload(_ classFile: ClassFile) -> Class {
        let cls = Class(classFile: classFile)
        loadedClasses[cls.name] = cls
        return cls
    }

    // Resolve a class by internal JVM name (e.g. "java/lang/String")
    func load(name: String) throws -> Class {
        if let cached = loadedClasses[name] { return cached }
        for directory in classpath {
            let url = directory.appendingPathComponent(name + ".class")
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                guard let classFile = try ClassFile(withData: data) else {
                    throw ClassLoadError.invalidClassFile(name)
                }
                let cls = Class(classFile: classFile)
                loadedClasses[name] = cls
                return cls
            } catch let e as ClassLoadError {
                throw e
            } catch {
                throw ClassLoadError.invalidClassFile(name)
            }
        }
        throw ClassLoadError.classNotFound(name)
    }
}
