//
//  HashUtility.swift
//
//
//  Created by Jack on 5/17/19.
//

import CommonCrypto
import UIKit

// Inspired by https://stackoverflow.com/questions/38023838/round-trip-swift-number-types-to-from-data

/// Marks any object that's convertible to a primitive data object
public protocol DataConvertible: MD5Hashable {
    /// The raw underlying data of the object.
    /// Different data = different fundamental object, not just a different representation
    var data: Data { get }
}

public extension DataConvertible {
    var data: Data {
        withUnsafeBytes(of: self) { Data($0) }
    }
}

// List "Convertible" types
extension Data: DataConvertible {
    public var data: Data { self }
}

extension Int: DataConvertible {}
extension Int64: DataConvertible {}
extension Float: DataConvertible {}
extension Double: DataConvertible {}
extension UInt32: DataConvertible {}
extension CGSize: DataConvertible {}
extension CGPoint: DataConvertible {}
extension CGRect: DataConvertible {}
extension UIImage: DataConvertible {
    public var data: Data {
        (cgImage?.dataProvider?.data as Data?) ?? Data(capacity: 0)
    }
}

extension String: DataConvertible {
    public var data: Data {
        // Note: a conversion to UTF-8 cannot fail.
        Data(utf8)
    }
}

extension URL: DataConvertible {
    public var data: Data {
        Data(absoluteString.utf8)
    }
}

/// Datasource-less MD5 hashing protocol
public protocol MD5Hashable {
    /// Hash the rendered properties
    ///
    /// - Parameter context: The context to hash the rendered properties with
    func continueHashRenderedProperties(context: inout MD5Hasher)
    /// The properties that are directly hashable and whose data can be loaded directly into memory
    var hashRenderedProperties: [MD5Hashable] { get }
    /// Files that must be hashed in a buffered manner for want of memory
    var hashFileRenderedProperties: [URL] { get }
}

public struct FileHashing: MD5Hashable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var hashFileRenderedProperties: [URL] { [url] }
}

// Datasource specializations

public extension MD5Hashable {
    func continueHashRenderedProperties(context: inout MD5Hasher) {
        // context.continueHashableHash(hashables: hashRenderedProperties)
        for hashable in hashRenderedProperties {
            hashable.continueHashRenderedProperties(context: &context)
        }

        for url in hashFileRenderedProperties {
            try? context.continueFileHash(url: url)
        }
    }

    var hashRenderedProperties: [MD5Hashable] { [] }
    var hashFileRenderedProperties: [URL] { [] }

    /// Calculate the MD5 Hash of the hashable object.
    ///
    /// - Returns: The MD5 hash associated with the object.
    func MD5Hash() -> Data {
        var hasher = MD5Hasher()
        continueHashRenderedProperties(context: &hasher)
        return hasher.finalizeContext()
    }
}

public extension MD5Hashable where Self: DataConvertible {
    func continueHashRenderedProperties(context: inout MD5Hasher) {
        context.continueConvertibleHash(convertible: self)
    }
}

extension Array: MD5Hashable where Iterator.Element: MD5Hashable {
    public func continueHashRenderedProperties(context: inout MD5Hasher) {
        for element in self {
            element.continueHashRenderedProperties(context: &context)
        }
    }
}

//extension Dictionary: MD5Hashable where Self.Key: MD5Hashable & Comparable, Self.Value: MD5Hashable {
//    public func continueHashRenderedProperties(context: inout MD5Hasher) {
//        let sorted = self.sorted(using: SortDescriptor(\.key)).flatMap { [$0.key, $0.value] as [any MD5Hashable] }
//        for element in sorted {
//            element.continueHashRenderedProperties(context: &context)
//        }
//    }
//}

struct MD5HashableArray: MD5Hashable {
    let hashables: [MD5Hashable]

    var hashRenderedProperties: [MD5Hashable] {
        hashables
    }
}

public class MD5Hasher {
    var context: CC_MD5_CTX

    /// Creates an initialized MD5 context
    init() {
        context = CC_MD5_CTX()
        resetContext()
    }

    /// Resets the MD5 hash context to its original / natural state
    func resetContext() {
        // Create and initialize MD5 context:
        // context = CC_MD5_CTX() Don't think we need this
        CC_MD5_Init(&context)
    }

    /// Returns a hash of all relevant movie properties. May be computed by hashing individual files.
    /// Two hashes should be the same iff their rendered output is the same with high probability
    /// and different with probability 1 if their rendered output is different.
    ///
    /// - Returns: A hash of all upload / file-relevant movie properties
    func finalizeContext() -> Data {
        // Compute the MD5 digest:
        var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes {
            _ = CC_MD5_Final($0, &context)
        }

        return digest
    }

    /// Hash child hashables
    ///
    /// - Parameter hashables: The hashable object to hash
    func continueHashableHash(hashables: [MD5Hashable]) {
        var selfMut = self
        for hashable in hashables {
            hashable.continueHashRenderedProperties(context: &selfMut)
        }
    }

    /// Hash data convertibles (basically primitives as far as the hasher is concerned)
    ///
    /// - Parameter convertible: The data convertible to be hashed
    func continueConvertibleHash(convertible: DataConvertible) {
        let data = convertible.data
        if data.count > 0 {
            data.withUnsafeBytes {
                _ = CC_MD5_Update(&context, $0, numericCast(data.count))
            }
        }
    }

    // Inspired by https://stackoverflow.com/a/42935601/998335

    /// Hash a file
    ///
    /// - Parameter url: The URL to get the data to hash
    /// - Throws: If the file can't be open or some other error reading occurs
    func continueFileHash(url: URL) throws {
        let bufferSize = 4096 * 4096 // I think HFS+ sector size?
        // Open file for reading:
        let file = try FileHandle(forReadingFrom: url)
        defer {
            file.closeFile()
        }

        // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                data.withUnsafeBytes {
                    _ = CC_MD5_Update(&context, $0, numericCast(data.count))
                }
                return true // Continue
            } else {
                return false // End of file
            }
        }) {}
    }
}
