//
//  Item.swift
//  illama
//
//  Created by Jack Youstra on 8/2/23.
//

import Foundation
import SwiftData

typealias SHC = Sendable & Hashable & Codable
typealias SHCI = SHC & Identifiable

struct CompletedConversation : SHC {
    var me: String
    var llama: String
}

enum Terminal : SHC {
    case complete(CompletedConversation)
    case progressing(CompletedConversation)
    case unanswered(String)
    
    var llama: String? {
        switch self {
        case let .complete(c):
            return c.llama
        case let .progressing(c):
            return c.llama
        case .unanswered(_):
            return nil
        }
    }
    
    var user: String {
        switch self {
        case let .complete(c):
            return c.me
        case let .progressing(c):
            return c.me
        case let .unanswered(s):
            return s
        }
    }
}

@Model
final class Conversation {
    var prior: [CompletedConversation]
    var current: Terminal
    @Relationship(inverse: \Chat.conversation)
    
    init(prompt: String) {
        prior = []
        current = .unanswered(prompt)
    }
    
    init(prior: [CompletedConversation], current: Terminal) {
        self.prior = prior
        self.current = current
    }
}

enum ChatEntry {
    case conversation(Conversation)
    case potential
    
    // getters, setters
    var asConversation: Conversation? {
        get {
            if case let .conversation(conversation) = self {
                return conversation
            }
            return nil
        } set {
            if let newValue = newValue {
                self = .conversation(newValue)
            } else {
                self = .potential
            }
        }
    }
}

extension Optional where Wrapped == Conversation {
    var promptLeftUnanswered: String? {
        (self.map(ChatEntry.conversation) ?? .potential).promptLeftUnanswered
    }
}

extension ChatEntry {
    var promptLeftUnanswered: String? {
        if case let .conversation(conversation) = self {
            switch conversation.current {
            case let .unanswered(prompt):
                return prompt
            case let .progressing(c):
                return c.me
            case .complete(_):
                break
            }
        }
        return nil
    }
}

@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var conversation: Conversation?
    
    init(timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = nil
    }
    
    init(timestamp: Date, prompt: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = Conversation(prompt: prompt)
    }
    
    static var preview: Self {
        Self(
            timestamp: .now,
            prompt: "This is a conversation between user and llama, a friendly chatbot. respond in simple markdown.\n\nUser: Tell me a fun fact\nllama:"
        )
    }
}
