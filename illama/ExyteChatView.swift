//
//  ExyteChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/23/23.
//

import SwiftUI
import ExyteChat
import SwiftyChat

fileprivate let llamaUser = ExyteChat.User(id: "llama", name: "llama", avatarURL: nil, isCurrentUser: false)
fileprivate let userUser = ExyteChat.User(id: "user", name: "user", avatarURL: nil, isCurrentUser: true)

fileprivate extension illama.CompletedConversation {
    var chatMessage: [Message] {
        [
            Message(
                id: String(me.timestamp.timeIntervalSince1970),
                user: userUser,
                createdAt: me.timestamp,
                text: me.text
            ),
            Message(
                id: String(llama.timestamp.timeIntervalSince1970),
                user: llamaUser,
                createdAt: llama.timestamp,
                text: llama.text
            ),
        ]
    }
}

fileprivate extension Terminal {
    var chatMessage: [Message] {
        switch self {
        case let .complete(completed), let .progressing(completed):
            return completed.chatMessage
        case let .unanswered(prompt):
            return [
                Message(
                    id: String(prompt.timestamp.timeIntervalSince1970),
                    user: userUser,
                    createdAt: prompt.timestamp,
                    text: prompt.text
                )
            ]
        }
    }
}

fileprivate extension illama.Conversation {
    var chatMessages: [Message] {
        prior.flatMap(\.chatMessage) + current.chatMessage
    }
}

@available(iOS 17.0, *)
struct ExyteChatView: View {
    @Bindable var chat: illama.Chat
    @State private var isEditing = false
    
    var body: some View {
        ExyteChat.ChatView(messages: chat.conversation?.chatMessages ?? []) { draft in
            chat.add(query: draft.text)
        } inputViewBuilder: { textBinding, _, _, _, actionClosure in
            BasicInputView(message: textBinding, isEditing: $isEditing, placeholder: "Type something here") { _ in
                actionClosure(.send)
            }
        }.messageUseMarkdown(messageUseMarkdown: true)
    }
}
