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

let llamaUser = AnyChatUser(userName: "llama")
let userUser = AnyChatUser(userName: "user")

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
            AnyChatMessage(user: userUser, messageKind: .text(me), isSender: true),
            AnyChatMessage(user: llamaUser, messageKind: .text(llama), isSender: false),
        ]
    }
}

extension Terminal {
    var anyChatMessage: [AnyChatMessage] {
        switch self {
        case let .complete(completed), let .progressing(completed):
            return completed.anyChatMessage
        case let .unanswered(prompt):
            return [AnyChatMessage(user: userUser, messageKind: .text(prompt), isSender: true)]
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
        let _ = print("Chat is \(chat)")
        let _ = print("Convo is \(chat.conversation)")
        let _ = print("Messages is \(chat.messages)")
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
        .task(id: chat.conversation.promptLeftUnanswered) {
            // finally
            defer {
                if case let .progressing(c) = chat.conversation.asConversation?.current {
                    chat.conversation.asConversation!.current = .complete(c)
                }
            }
            do {
                if case let .unanswered(prompt) = chat.conversation.asConversation?.current {
                    let decoder = JSONDecoder()
                    for await string in try! await LlamaInstance.shared.run_llama(prompt: prompt).compactMap({ try? decoder.decode(DataString.self, from: $0.data(using: .utf8)!) }) {
                        try Task.checkCancellation()
                        print("string is \(string)")
                        if let c = chat.conversation.asConversation {
                            let oldString = c.current.llama
                            let completedConversation = CompletedConversation(me: c.current.user, llama: (oldString ?? "") + string.content)
                            if string.stop {
                                chat.conversation.asConversation!.current = .complete(completedConversation)
                                break
                            } else {
                                chat.conversation.asConversation!.current = .progressing(completedConversation)
                            }
                        }
                    }
                }
            } catch {
            }
            print("Done listening")
        }
        // only do on macOS or catalyst
        #if targetEnvironment(macCatalyst)
        .navigationSubtitle(Text("Item at \(chat.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"))
        #endif
    }
}

#Preview {
    ChatView(chat: Chat.preview)
}
