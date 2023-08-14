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
    case unanswered(String)
}

struct Conversation : SHC {
    var prior: [CompletedConversation]
    var current: Terminal
    
    init(prompt: String) {
        prior = []
        current = .unanswered(prompt)
    }
    
    init(prior: [CompletedConversation], current: Terminal) {
        self.prior = prior
        self.current = current
    }
}

enum ChatEntry : SHC {
    case conversation(Conversation)
    case potential
}

@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var conversation: ChatEntry
    
    init(timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = .potential
    }
    
    init(timestamp: Date, prompt: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = .conversation(.init(prompt: prompt))
    }
    
    static var preview: Self {
        Self(
            timestamp: .now,
            prompt: "This is a conversation between user and llama, a friendly chatbot. respond in simple markdown.\n\nUser: Tell me a fun fact\nllama:"
        )
    }
}
