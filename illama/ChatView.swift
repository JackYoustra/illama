//
//  ChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/14/23.
//

import SwiftUI
import SwiftyChat
import Algorithms

struct AnyChatUser: ChatUser {
    var userName: String
    
    var id: String {
        userName
    }
}

let llamaUser = AnyChatUser(userName: "llama")
let user = AnyChatUser(userName: "user")

struct AnyChatMessage: ChatMessage {
    var user: AnyChatUser
    
    typealias User = AnyChatUser
    
    var messageKind: SwiftyChat.ChatMessageKind
    
    var isSender: Bool
    
    var date: Date = .now
    
    var id: UUID = UUID()
}

extension ChatMessage {
    var text: String? {
        switch messageKind {
        case let .text(text):
            return text
        default:
            return nil
        }
    }
}

extension CompletedConversation {
    var anyChatMessage: [AnyChatMessage] {
        [
            AnyChatMessage(user: user, messageKind: .text(me), isSender: true),
            AnyChatMessage(user: llamaUser, messageKind: .text(llama), isSender: false),
        ]
    }
}

extension Terminal {
    var anyChatMessage: [AnyChatMessage] {
        switch self {
        case let .complete(completed):
            return completed.anyChatMessage
        case let .unanswered(prompt):
            return [AnyChatMessage(user: user, messageKind: .text(prompt), isSender: true)]
        }
    }
}

extension Chat {
    var messages: [AnyChatMessage] {
        get {
            switch conversation {
            case .potential:
                return []
            case let .conversation(conversation):
                return conversation.prior.flatMap(\.anyChatMessage)
            }
        } set {
            if newValue.isEmpty {
                conversation = .potential
            } else {
                var conversationItems = [CompletedConversation]()
                var current: Terminal? = nil
                for chunk in newValue.chunks(ofCount: 2) {
                    switch chunk.count {
                    case 1:
                        let message = chunk.first!
                        assert(message.isSender)
                        current = .unanswered(message.text!)
                    case 2:
                        assert(chunk[0].isSender)
                        assert(!chunk[1].isSender)
                        conversationItems.append(CompletedConversation(me: chunk[0].text!, llama: chunk[1].text!))
                    default:
                        fatalError()
                    }
                }
                if current == nil {
                    if let last = conversationItems.popLast() {
                        current = .complete(last)
                    } else {
                        // pending
                        conversation = .potential
                        return
                    }
                }
                conversation = .conversation(Conversation(prior: conversationItems, current: current!))
            }
        }
    }
}

struct ChatView: View {
    @Bindable var chat: Chat
    @State private var message: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        SwiftyChat.ChatView<AnyChatMessage, AnyChatUser>(messages: $chat.messages) {
            AnyView(
                BasicInputView(message: $message, isEditing: $isEditing, placeholder: "Type something here") { messageKind in
                    switch messageKind {
                    case .text(let string):
                        chat.conversation = .conversation(Conversation(prior: [], current: .unanswered(string)))
                    default:
                        break
                    }
                }
            )
        }
        .navigationSubtitle(chat.timestamp.description)
    }
}

#Preview {
    ChatView(chat: Chat.preview)
}
