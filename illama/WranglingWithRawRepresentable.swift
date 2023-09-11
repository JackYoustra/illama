//
//  WranglingWithRawRepresentable.swift
//  illama
//
//  Created by Jack Youstra on 9/10/23.
//

import Foundation

extension UUID: RawRepresentable {
    public init?(rawValue: String) {
        self.init(uuidString: rawValue)
    }
    
    public var rawValue: String {
        uuidString
    }
}

extension Optional: RawRepresentable where Wrapped: Codable {
    public init?(rawValue: String) {
        if rawValue.isEmpty {
            self = nil
        } else {
            guard let data = rawValue.data(using: .utf8) else {
                return nil
            }
            do {
                self = try JSONDecoder().decode(Wrapped.self, from: data)
            } catch {
                return nil
            }
        }
    }
    
    public var rawValue: String {
        switch self {
        case let .some(wrapped):
            do {
                return try String(data: JSONEncoder().encode(wrapped), encoding: .utf8) ?? ""
            } catch {
                return ""
            }
        case .none:
            return ""
        }
    }
}

//enum NewtypeOptional<Wrapped>: ExpressibleByNilLiteral {
//    case some(Wrapped)
//    case none
//    
//    var asOptional: Wrapped? {
//        switch self {
//        case let .some(t):
//            return t
//        case .none:
//            return nil
//        }
//    }
//    
//    init(nilLiteral: ()) {
//        self = .none
//    }
//}
//
//
//extension NewtypeOptional: RawRepresentable where Wrapped: Codable {
//    init?(rawValue: String) {
//        if rawValue.isEmpty {
//            self = nil
//        } else {
//            guard let data = rawValue.data(using: .utf8) else {
//                return nil
//            }
//            do {
//                self = try .some(JSONDecoder().decode(Wrapped.self, from: data))
//            } catch {
//                return nil
//            }
//        }
//    }
//    
//    var rawValue: String {
//        switch self {
//        case let .some(wrapped):
//            do {
//                return try String(data: JSONEncoder().encode(wrapped), encoding: .utf8)!
//            } catch {
//                return ""
//            }
//        case .none:
//            return ""
//        }
//    }
//}
//
