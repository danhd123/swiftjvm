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
/*
    var mainClass: ClassFile?
    var classes: [Class:any Loader] = [:]
    let bootstrapLoader = BootstrapLoader()
    
    enum Error: Swift.Error {
        case ClassNotFound(String)
        case LinkageError(String)
        case ClassFormatError(String)
        case UnsupportedClassVersionError(UInt16)
        case NoClassDefFound(String)
    }
    
    mutating func loadClassFile(_ classFile: ClassFile) -> [Class: any Loader].Element {
        methodArea.append(classFile)
        for method in classFile.methods {
            if method.accessFlags.rawValue & MethodInfo.AccessFlags.Static.rawValue != 0 && method.name == "main" && method.descriptor == "([Ljava/lang/String;)V" {
*/
                if mainMethod != nil {
                    fatalError("Can't have two main methods")
                }
                mainMethod = main
                mainClass = cls
            }
        }
        let newClass = bootstrapLoader.loadClassNamed(classFile.className)
        return [Class: any Loader].Element(newClass, bootstrapLoader)
    }
    
    mutating func findOrCreateClass(named name: String) -> Result<Class?,Error> {
        if let loadedClass = classes.keys.first(where: { $0.name == name }) {
            return .success(loadedClass)
        } else if name.hasPrefix("[") {
            // TODO create array class dynamically
        } else if let parsedClass = methodArea.first(where: { classFile in
            guard let classFileConstant = classFile.constantPool[classFile.thisClassIndex] as? ClassOrModuleOrPackageConstant else { return false }
            guard let nameConstant = classFile.constantPool[classFileConstant.nameIndex] as? Utf8Constant else { return false}
            if nameConstant.string == name {
                let element = loadClassFile(classFile)
                classes[element.key] = element.value
            }
        }){
            
        }
        
    }
    
    mutating func createClass(_ name: String, classFile: ClassFile, loader: any Loader) -> Result<Class, Error> {
        if classes.keys.map({ $0.name }).contains(where: { $0 == name }) {
            return .failure(.LinkageError(name))
        }
        if !classFile.classFormatValid {
            return .failure(.ClassFormatError(classFile.className))
        }
        if classFile.majorVersion < 45 || classFile.majorVersion > 64 {
            return .failure(.UnsupportedClassVersionError(classFile.majorVersion))
        }
        if classFile.className != name  || classFile.accessFlags.rawValue & ClassFile.AccessFlags.Module.rawValue != 0 {
            return .failure(.NoClassDefFound(classFile.className))
        }
        
    }
    
    mutating func start() -> Never {
        guard let mainMethod, let mainClass else {
            fatalError("No main method found")
        }
        var mainThread = Thread()
        let mainFrame = Frame(classFile: mainClass.classFile, constantPool: mainClass.classFile.constantPool, method: mainMethod)
        mainThread.stackFrames.append(mainFrame)
        threads.append(mainThread)
        mainThread.execute()
        exit(0)
    }
}
