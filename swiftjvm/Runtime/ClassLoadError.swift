//
//  ClassLoadError.swift
//  swiftjvm
//

enum ClassLoadError: Error {
    case classNotFound(String)
    case invalidClassFile(String)
}
