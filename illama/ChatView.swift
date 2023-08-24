//
//  ChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/14/23.
//

import SwiftUI
import Dependencies

struct ChatViewAdapter: View {
    @Bindable var chat: Chat
    @State var shouldUseSwiftyChat = true
    @ScaledMetric var loadingSize = 25.0
    
    var body: some View {
        Group {
            if shouldUseSwiftyChat {
                SwiftyChatView(chat: chat)
            } else {
                ExyteChatView(chat: chat)
            }
        }.toolbar {
            Toggle(isOn: $shouldUseSwiftyChat) {
                Text("Use stable chat")
            }
        }
    }
}

struct ChatView: View {
    @Bindable var chat: Chat
    
    var body: some View {
        ChatViewAdapter(chat: chat)
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

                if case let .unanswered(_) = chat.conversation?.current {
                    let prompt = chat.gptPrompt!
                    print("prompt is \(prompt)")
                    for try await string in try! await llamaClient.query(prompt) {
                        // TODO: Need an effective cancellation facility
//                        try Task.checkCancellation()
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
