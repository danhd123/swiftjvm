//
//  VM.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

class VM {
    var threads: [Thread] = []
    var classLoader: ClassLoader
    var classes: [Class: any Loader] = [:]
    var bootstrapLoader: BootstrapLoader = BootstrapLoader()
    var mainMethod: MethodInfo? = nil
    var mainClass: Class?

    enum Error: Swift.Error {
        case classNotFound(String)
        case linkageError(String)
        case classFormatError(String)
        case unsupportedClassVersionError(UInt16)
        case noClassDefFound(String)
    }

    init(classpath: [URL]) {
        self.classLoader = ClassLoader(classpath: classpath)
    }

    func loadClass(_ classFile: ClassFile) {
        let cls = classLoader.preload(classFile)
        // Resolve superclass from already-loaded classes only — no VM mutation,
        // so no exclusive-access conflict with the current loadClass mutation.
        cls.superclass = classLoader.loadedClasses[classFile.superclassName]
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

    func findOrCreateClass(named name: String) -> Result<Class?, VM.Error> {
        if let loadedClass = classes.keys.first(where: { $0.name == name }) {
            return .success(loadedClass)
        } else if name.hasPrefix("[") {
            // TODO: create array class dynamically
            return .success(nil)
        } else {
            do {
                let cls = try classLoader.load(name: name)
                classes[cls] = bootstrapLoader
                return .success(cls)
            } catch ClassLoadError.classNotFound(let n) {
                return .failure(.classNotFound(n))
            } catch ClassLoadError.invalidClassFile(let n) {
                return .failure(.classFormatError(n))
            } catch {
                return .failure(.classNotFound(name))
            }
        }
    }

    func createClass(_ name: String, classFile: ClassFile, loader: any Loader) -> Result<Class, VM.Error> {
        if classes.keys.map({ $0.name }).contains(where: { $0 == name }) {
            return .failure(.linkageError(name))
        }
        if !classFile.classFormatValid {
            return .failure(.classFormatError(classFile.className))
        }
        if classFile.majorVersion < 45 || classFile.majorVersion > 64 {
            return .failure(.unsupportedClassVersionError(classFile.majorVersion))
        }
        if classFile.className != name || classFile.accessFlags.rawValue & ClassFile.AccessFlags.Module.rawValue != 0 {
            return .failure(.noClassDefFound(classFile.className))
        }
        fatalError("createClass: not yet implemented")
    }

    // Not mutating — holding an exclusive write lock on Runtime.vm across the
    // entire execution would conflict with findOrCreateClass calls made by the
    // interpreter during invokestatic resolution.
    func start() -> Never {
        guard let mainMethod, let mainClass else {
            fatalError("No main method found")
        }
        let mainThread = Thread()
        let mainFrame = Frame(owningClass: mainClass, method: mainMethod)
        mainThread.stackFrames.append(mainFrame)
        mainThread.execute()
        exit(0)
    }
}
