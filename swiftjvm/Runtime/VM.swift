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

    /// JDK class stubs: name → superclass name.
    /// When these classes cannot be found on the classpath we synthesise a minimal
    /// stub so that object creation and exception-table lookup still work.
    private static let jdkStubs: [String: String] = [
        "java/lang/Object":                      "",
        "java/lang/Throwable":                   "java/lang/Object",
        "java/lang/Error":                       "java/lang/Throwable",
        "java/lang/Exception":                   "java/lang/Throwable",
        "java/lang/RuntimeException":            "java/lang/Exception",
        "java/lang/NullPointerException":        "java/lang/RuntimeException",
        "java/lang/IllegalArgumentException":    "java/lang/RuntimeException",
        "java/lang/IllegalStateException":       "java/lang/RuntimeException",
        "java/lang/UnsupportedOperationException": "java/lang/RuntimeException",
        "java/lang/IndexOutOfBoundsException":   "java/lang/RuntimeException",
        "java/lang/ArrayIndexOutOfBoundsException": "java/lang/IndexOutOfBoundsException",
        "java/lang/ClassCastException":          "java/lang/RuntimeException",
        "java/lang/ArithmeticException":         "java/lang/RuntimeException",
        "java/lang/NumberFormatException":       "java/lang/IllegalArgumentException",
        "java/lang/StackOverflowError":          "java/lang/Error",
        "java/lang/OutOfMemoryError":            "java/lang/Error",
    ]

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
            } catch ClassLoadError.classNotFound {
                // Fall back to a synthetic stub for known JDK classes.
                if let superName = VM.jdkStubs[name] {
                    let stubFile = ClassFile(stubName: name, superclassName: superName)
                    let stubClass = classLoader.preload(stubFile)
                    classes[stubClass] = bootstrapLoader
                    return .success(stubClass)
                }
                return .failure(.classNotFound(name))
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
