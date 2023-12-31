//
//  ModelType.swift
//  iLlama
//
//  Created by Jack Youstra on 12/30/23.
//

import Foundation

enum ModelType: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case smallLlama
    case mediumLlama
    
    var memoryRequirement: UInt64 {
        switch self {
        case .smallLlama: return 4 * 1024 * 1024 * 1024
        case .mediumLlama: return 8 * 1024 * 1024 * 1024
        }
    }
    
    var shouldMlock: Bool {
        // Only mlock on big for rn
        return ModelType.mediumLlama.memoryRequirementMet
    }
    
    var contextSize: UInt {
        switch self {
        case .smallLlama:
            if ProcessInfo.processInfo.physicalMemory > UInt64(4.1 * 1024 * 1024 * 1024) {
                return 1024
            } else {
                return 512
            }
        case .mediumLlama:
            return 2048
        }
    }
    
    var spaceRequirement: UInt64 {
        // (chunk count  + 1) * chunk size, for intermediate chunk, to be able to install
        (UInt64(chunkCount) + 1) * Self.blockSize
    }
    
    var finalizedSpace: UInt64 {
        switch self {
        case .smallLlama:
            return 1928446208
        case .mediumLlama:
            return 3282248320
        }
    }
    
    var memoryRequirementMet: Bool {
        ProcessInfo.processInfo.physicalMemory >= UInt64(Double(memoryRequirement) * 0.98)
    }
    
    var folderName: String {
        rawValue
    }
    
    var id: String {
        rawValue
    }
    
    var tagPrefix: String {
        "3b_q4_"
    }
    
    var chunkCount: UInt {
        4
    }
    
    static let blockSize: UInt64 = 500 * 1024 * 1024
    
    var bundleTags: [String] {
        assert(chunkCount < 26)
        return (0..<chunkCount).map {
            tagPrefix + String(Character(UnicodeScalar(UInt32(UInt8($0) + ("a" as Character).asciiValue!))!))
        }
    }
    
    var itemTitle: String {
        switch self {
        case .smallLlama:
            return "Small Llama"
        case .mediumLlama:
            return "Medium Llama"
        }
    }
}

extension ModelType {
    var targetFolder: URL {
        URL.documentsDirectory.appending(path: self.folderName, directoryHint: .isDirectory)
    }
    
    var finalizedLocation: URL {
        targetFolder.appending(path: "combined.bin")
    }
    
    var processingIsDone: Bool {
        if let possibleTargetSize = finalizedLocation.size(),
           possibleTargetSize == self.spaceRequirement {
            return true
        }
        return false
    }
}

extension URL {
    func size() -> UInt64? {
        try? (FileManager.default.attributesOfItem(atPath: self.path)[.size] as! UInt64)
    }
}
