//
//  ChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/14/23.
//

import SwiftUI
import SwiftyChat
import Algorithms
import Dependencies
import CustomDump

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

struct ChatView: View {
    @Bindable var chat: Chat
    @State private var message: String = ""
    @State private var isEditing: Bool = false
    @StateObject private var styling = ChatMessageCellStyle()
    
    var body: some View {
        SwiftyChat.ChatView<AnyChatMessage, AnyChatUser>(messages: $chat.anyChatMessages, dateHeaderTimeInterval: 1.0) {
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
        }
        .environmentObject(styling)
        // We can't really handle interruption rn, disable button until we're done
        .disabled(chat.isAnswering)
        .task(id: chat.conversation.promptLeftUnanswered) {
            // finally
            defer {
                if case let .progressing(c) = chat.conversation?.current {
                    chat.conversation!.current = .complete(c)
                }
            }
            do {
                @Dependency(\.llama) var llamaClient;

                if case let .unanswered(prompt) = chat.conversation?.current {
                    for try await string in try! await llamaClient.query(prompt.text) {
                        try Task.checkCancellation()
                        print("string is \(string)")
                        if let c = chat.conversation {
                            let oldString = c.current.llama?.text
                            let newText = (oldString ?? "") + string.content
                            // TODO: If we enable resume after interruption, maybe clobber timestamp?
                            let completedConversation = CompletedConversation(me: c.current.user, llama: SingleMessage(text: newText, timestamp: c.current.llama?.timestamp ?? Date.now))
                            if string.stop {
                                chat.conversation!.current = .complete(completedConversation)
                                break
                            } else {
                                chat.conversation!.current = .progressing(completedConversation)
                            }
                        }
                    }
                }
            } catch {
                let thing = error
                fatalError(thing.localizedDescription)
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
        .modelContainer(for: Chat.self, inMemory: true)
}
