//
//  SwiftDataModels.swift
//  illama
//
//  Created by Jack Youstra on 8/26/23.
//

import SwiftData
import Foundation

@available(iOS 17.0, *)
@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var _timestamp: Date?
    var _messages: [SingleMessage]?
    var _isAnswering: Bool?
    var _chatTitle: String?
    
    @Transient
    var timestamp: Date {
        get { _timestamp ?? .now }
        set { _timestamp = newValue }
    }
    
    @Transient
    var messages: [SingleMessage] {
        get { _messages ?? [] }
        set { _messages = newValue }
    }
    
    @Transient
    var isAnswering: Bool {
        get { _isAnswering ?? false }
        set { _isAnswering = newValue }
    }
    
    @Transient
    var chatTitle: String {
        get { _chatTitle ?? "" }
        set {
            if newValue.isEmpty {
                _chatTitle = nil
            } else {
                _chatTitle = newValue
            }
        }
    }

    init(timestamp: Date) {
        self.id = UUID()
        self._timestamp = timestamp
        self._messages = []
        self._isAnswering = false
    }
    
    convenience init(timestamp: Date, prompt: String) {
        self.init(timestamp: timestamp)
        self.conversation = Conversation(prompt: prompt)
    }
    
    init(timestamp: Date = .now, messages: [SingleMessage] = [], isAnswering: Bool = false) {
        self.id = UUID()
        self._timestamp = timestamp
        self._messages = messages
        self._isAnswering = isAnswering
    }
    
    static var preview: Self {
        Self(
            timestamp: .now,
            prompt: "say hi"
        )
    }
    
    
    // Convenience
    @Transient
    var conversation: Conversation? {
        get {
            if messages.isEmpty {
                return nil
            } else {
                var prior = [CompletedConversation]()
                var current: Terminal? = nil
                for chunk in messages.chunks(ofCount: 2) {
                    switch chunk.count {
                    case 1:
                        assert(isAnswering)
                        current = .unanswered(chunk.first!)
                    case 2:
                        prior.append(CompletedConversation(me: chunk.first!, llama: chunk.last!))
                    default:
                        fatalError()
                    }
                }
                if current == nil {
                    if let last = prior.popLast() {
                        if isAnswering {
                            current = .progressing(last)
                        } else {
                            current = .complete(last)
                        }
                    } else {
                        // pending first ask, should be handled by checking if is empty
                        fatalError()
                    }
                }
                return Conversation(prior: prior, current: current!)
            }
        } set {
            messages = newValue?.anyChatMessages.map(\.singleMessage) ?? []
            isAnswering = newValue?.current.isAnswering ?? false
        }
    }
}
