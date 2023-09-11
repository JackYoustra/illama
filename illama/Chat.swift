//
//  Item.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import Foundation
import Algorithms

typealias SHC = Sendable & Hashable & Codable
typealias SHCI = SHC & Identifiable

struct CompletedConversation : SHCI {
    var me: SingleMessage
    var llama: SingleMessage
    
    var id: Self {
        self
    }
}

enum Terminal : SHC {
    case complete(CompletedConversation)
    case progressing(CompletedConversation)
    case unanswered(SingleMessage)
    
    var llama: SingleMessage? {
        switch self {
        case let .complete(c):
            return c.llama
        case let .progressing(c):
            return c.llama
        case .unanswered(_):
            return nil
        }
    }
    
    var user: SingleMessage {
        switch self {
        case let .complete(c):
            return c.me
        case let .progressing(c):
            return c.me
        case let .unanswered(s):
            return s
        }
    }
    
    var isAnswering: Bool {
        switch self {
        case .complete(_):
            return false
        case .progressing(_):
            return true
        case .unanswered(_):
            return true
        }
    }
    
    var completed: CompletedConversation? {
        switch self {
        case let .complete(c):
            return c
        case let .progressing(c):
            return nil
        case .unanswered(_):
            return nil
        }
    }
}

struct Conversation: SHC {
    var prior: [CompletedConversation]
    var current: Terminal
    
    init(prompt: String) {
        prior = []
        current = .unanswered(SingleMessage(text: prompt, timestamp: .now))
    }
    
    init(prior: [CompletedConversation], current: Terminal) {
        self.prior = prior
        self.current = current
    }
    
    mutating func add(query: String) {
        prior.append(current.completed!)
        current = .unanswered(SingleMessage(text: query, timestamp: .now))
    }
}

#if swift(>=5.9)

@available(iOS 17.0, *)
extension Chat {
    func add(query: String) {
        assert(!isAnswering)
        if messages.isEmpty {
            conversation = .init(prompt: query)
        } else {
            conversation?.add(query: query)
        }
    }
}

#endif

extension Optional where Wrapped == Conversation {
    var promptLeftUnanswered: SingleMessage? {
        if let self {
            switch self.current {
            case let .unanswered(prompt):
                return prompt
            case let .progressing(c):
                return c.me
            case .complete(_):
                return nil
            }
        } else {
            return nil
        }
    }
}

struct SingleMessage: SHC {
    let text: String
    var timestamp: Date
}
