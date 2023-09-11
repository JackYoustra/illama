//
//  SwiftyChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/23/23.
//

import SwiftyChat
import SwiftUI
import UIKit
import Foundation

struct AnyChatUser: ChatUser {
    var avatar: UIImage?
    
    var avatarURL: URL?
    
    var userName: String
    
    var id: String {
        userName
    }
    
    // blank default init
    init(avatar: UIImage? = nil, avatarURL: URL? = nil, userName: String = "") {
        self.avatar = avatar
        self.avatarURL = avatarURL
        self.userName = userName
    }
}

fileprivate let llamaUser = AnyChatUser(userName: "llama")
fileprivate let userUser = AnyChatUser(userName: "user")

struct AnyChatMessage: ChatMessage {
    var user: AnyChatUser
    
    typealias User = AnyChatUser
    
    var messageKind: SwiftyChat.ChatMessageKind
    
    var isSender: Bool
    
    var date: Date
    
    var id: UUID = UUID()
}

extension AnyChatMessage {
    var singleMessage: SingleMessage {
        SingleMessage(text: text!, timestamp: date)
    }
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
            AnyChatMessage(user: userUser, messageKind: .text(me.text), isSender: true, date: me.timestamp),
            AnyChatMessage(user: llamaUser, messageKind: .text(llama.text), isSender: false, date: me.timestamp),
        ]
    }
    
    var messages: [SingleMessage] {
        [
            me,
            llama
        ]
    }
}

extension Terminal {
    var anyChatMessage: [AnyChatMessage] {
        switch self {
        case let .complete(completed), let .progressing(completed):
            return completed.anyChatMessage
        case let .unanswered(prompt):
            return [AnyChatMessage(user: userUser, messageKind: .text(prompt.text), isSender: true, date: prompt.timestamp)]
        }
    }
    
    var messages: [SingleMessage] {
        switch self {
        case let .complete(completed), let .progressing(completed):
            return completed.messages
        case let .unanswered(prompt):
            return [prompt]
        }
    }
}

extension Conversation {
    var anyChatMessages: [AnyChatMessage] {
        prior.flatMap(\.anyChatMessage) + current.anyChatMessage
    }
}

#if swift(>=5.9)

@available(iOS 17.0, *)
extension Chat {
    var anyChatMessages: [AnyChatMessage] {
        get {
            conversation?.anyChatMessages ?? []
        } set {
            if newValue.isEmpty {
                conversation = nil
            } else {
                var conversationItems = [CompletedConversation]()
                var current: Terminal? = nil
                for chunk in newValue.chunks(ofCount: 2) {
                    switch chunk.count {
                    case 1:
                        let message = chunk.first!
                        assert(message.isSender)
                        current = .unanswered(message.singleMessage)
                    case 2:
                        assert(chunk[0].isSender)
                        assert(!chunk[1].isSender)
                        conversationItems.append(CompletedConversation(me: chunk[0].singleMessage, llama: chunk[1].singleMessage))
                    default:
                        fatalError()
                    }
                }
                if current == nil {
                    if let last = conversationItems.popLast() {
                        current = .complete(last)
                    } else {
                        // pending
                        conversation = nil
                        return
                    }
                }
                conversation = Conversation(prior: conversationItems, current: current!)
            }
        }
    }
}

@available(iOS 17.0, *)
struct SwiftyChatView: View {
    @Bindable var chat: Chat
    @State private var message: String = ""
    @State private var isEditing: Bool = false
    @StateObject private var styling = ChatMessageCellStyle()

    var body: some View {
        SwiftyChat.ChatView<AnyChatMessage, AnyChatUser>(messages: $chat.anyChatMessages, dateHeaderTimeInterval: 60.0) {
            AnyView(
                BasicInputView(message: $message, isEditing: $isEditing, placeholder: "Type something here") { messageKind in
                    switch messageKind {
                    case .text(let string):
                        // only update if we can!
                        if chat.isAnswering {
                            message = string
                        } else {
                            // normal order / flow
                            chat.add(query: string)
                        }
                    default:
                        break
                    }
                }
            )
        }.environmentObject(styling)
    }
}

#endif
