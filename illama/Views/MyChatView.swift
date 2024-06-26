//
//  MyChatView.swift
//  illama
//
//  Created by Jack Youstra on 8/25/23.
//

import SwiftUI
import MarkdownUI
import SwiftUIIntrospect

enum MarkdownType: String, CaseIterable, Hashable, Identifiable, Codable {
    case system
    case markdownUI
    case docC
    case github
    
    var markdownTheme: MarkdownUI.Theme {
        switch self {
        case .docC: return .docC
        case .github: return .gitHub
        default:
            return .basic
        }
    }
    
    var id: Self {
        self
    }
}

extension Optional where Wrapped == MarkdownType {
    var systemImage: String {
        switch self {
        case .system:
            return "applelogo"
        case .markdownUI:
            return "sparkles"
        case .docC:
            return "doc"
        case .github:
            return "terminal"
        case .none:
            return "textformat"
        }
    }
    
    var name: String {
        switch self {
        case .system:
            return "Apple"
        case .markdownUI:
            return "Enhanced"
        case .docC:
            return "DocC"
        case .github:
            return "GitHub"
        case .none:
            return "None"
        }
    }
}

private struct MarkdownSupport: EnvironmentKey {
    static let defaultValue: Binding<MarkdownType?> = .constant(.markdownUI)
}

extension EnvironmentValues {
    var markdownSupport: Binding<MarkdownType?> {
        get { self[MarkdownSupport.self] }
        set { self[MarkdownSupport.self] = newValue }
    }
}

struct InfiniteRotation: ViewModifier {
    @State private var angle: CGFloat = 0.0
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.linear(duration: 3)
                        .repeatForever(autoreverses: false)) {
                    angle = 360.0
                }
            }
            .rotationEffect(.degrees(angle))
    }
}

@available(iOS 17.0, *)
struct MyChatView: View {
    @Bindable var chat: Chat

    var body: some View {
        MyChatViewCommon(chat: chat) { thing in
            if !chat.isAnswering {
                chat.add(query: thing)
            }
        }
    }
}

struct OldChatViewAdapter: View {
    @ObservedObject var chat: FileChat
    
    var body: some View {
        MyChatViewCommon(chat: chat) { thing in
            if !chat.isAnswering {
                chat.add(query: thing)
            }
        }
    }
}

fileprivate struct MyChatViewCommon<ChatType: AnyChat>: View {
    let chat: ChatType
    let onSubmit: (String) -> ()
    @State private var thing: String = ""
    @AppStorage(AppStorageKey.markdownType.rawValue) private var markdownSupport: MarkdownType? = .markdownUI
    @FocusState private var textFocused: Bool
    @ScaledMetric(relativeTo: .body) var textboxSize = 36.0

    @Namespace var bottomID
    
    var body: some View {
        VStack {
            Group {
                if let conversation = chat.conversation {
                    ScrollView(.vertical) {
                        ScrollViewReader { proxy in
                            LazyVStack {
                                ForEach(conversation.prior) { completedConversation in
                                    CompletedConversationView(chat: completedConversation)
                                }
                                switch conversation.current {
                                case let .complete(exchange), let .progressing(exchange):
                                    CompletedConversationView(chat: exchange)
                                case let .unanswered(message):
                                    SingleMessageView(message: message, isSender: true)
                                    if chat.isAnswering {
                                        MessageView(timestamp: .now, isSender: false) {
                                            HStack {
                                                Text("Loading")
                                                Text("🦙")
                                                    .modifier(InfiniteRotation())
                                            }
                                        }
                                    }
                                }
                                // scrollable proxy
                                Color.clear.frame(height: 1.0)
                                    .id(bottomID)
                            }.onChange(of: conversation.current) { _ in
                                proxy.scrollTo(bottomID)
                            }
                        }
                    }
                }
                Spacer()
            }.gesture(TapGesture().onEnded {
                textFocused = false
            }, including: textFocused ? .all : .subviews)
            HStack(spacing: .zero) {
                TextEditor(text: $thing)
                    .focused($textFocused)
                    .frame(minHeight: textboxSize, maxHeight: 250.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .textFieldStyle(.roundedBorder)
                    .introspect(.textEditor, on: .iOS(.v14, .v15, .v16, .v17)) {
                        let textView = $0
                        textView.backgroundColor = .clear
                    }
                    .onSubmit {
                        submit()
                    }
                    .submitLabel(.send)
                    .overlay(alignment: Alignment.leading) {
                        if thing.isEmpty {
                            Text("Talk to 🦙")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 5)
                        }
                    }
                    .onAppear {
                        if chat.conversation == nil {
                            textFocused = true
                        }
                    }
                Group {
                    if chat.isAnswering {
                        Circle()
                            .foregroundStyle(.secondary)
                            .overlay {
                                ProgressView()
                                    .tint(Color.white)
                            }
                    } else {
                        Button {
                            submit()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
                .frame(height: textboxSize)
            }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 20).stroke(Color.secondary))
                .gesture(TapGesture().onEnded {
                    textFocused = true
                }, including: textFocused ? .subviews : .all)
        }.padding(.horizontal)
        .toolbar {
            HStack(spacing: .zero) {
                Menu {
                    MarkdownPicker()
                } label: {
                    Text("🄼↓") + Text(Image(systemName: markdownSupport.systemImage))
                }
            }
        }.environment(\.markdownSupport, $markdownSupport)
    }
    
    func submit() {
        if !chat.isAnswering {
            onSubmit(thing)
            thing = ""
        }
    }
}

struct MarkdownPicker: View {
    @AppStorage(AppStorageKey.markdownType.rawValue) private var markdownSupport: MarkdownType? = .markdownUI

    var body: some View {
        Picker("Markdown", selection: $markdownSupport) {
            ForEach(MarkdownType.allCases.map(Optional.some) + [nil], id: \.self) { type in
                Label(type.name, systemImage: type.systemImage)
                    .tag(type)
            }
        }
    }
}

struct CompletedConversationView: View {
    let chat: CompletedConversation

    var body: some View {
        Group {
            SingleMessageView(message: chat.me, isSender: true)
            SingleMessageView(message: chat.llama, isSender: false)
        }
    }
}

struct SingleMessageView: View {
    let message: SingleMessage
    let isSender: Bool
    
    var body: some View {
        MessageView(timestamp: message.timestamp, isSender: isSender) {
            MarkdownTextDisplay(text: message.text)
        }
    }
}

struct MarkdownTextDisplay: View {
    @Environment(\.markdownSupport) var markdownSupport
    let text: String
    
    var body: some View {
        let v = markdownSupport.wrappedValue
        switch v {
        case .markdownUI, .docC, .github:
            Markdown(text)
                .markdownTheme(v?.markdownTheme ?? .basic)
        case .system:
            Text(LocalizedStringKey(text))
        case .none:
            Text(text)
        }
    }
}

let timeFormatter = {
    let formatter = DateFormatter()
    
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    
    return formatter
}()

struct MessageView<Content: View>: View {
    let timestamp: Date
    let isSender: Bool
    @ViewBuilder var content: () -> Content
    
    @Namespace var ns
    
    var dateText: String {
        timeFormatter.string(from: timestamp)
    }
    
    var body: some View {
        HStack {
            if isSender {
                Spacer()
                dateTextView
                textView
            } else {
                textView
                dateTextView
                Spacer()
            }
        }
    }
    
    var dateTextView: some View {
        Text(dateText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    var textView: some View {
        content()
            .font(.body)
            .padding(8.0)
            .foregroundColor(isSender ? Color.white : Color.primary)
            .background(Color(uiColor: isSender ? .systemCyan : .systemFill), in: RoundedRectangle(cornerSize: CGSize(width: 8.0, height: 8.0)))
    }
}

import LoremSwiftum
import SwiftData

@available(iOS 17.0, *)
let previewContainer = try! ModelContainer(for: Chat.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

@available(iOS 17.0, *)
#Preview {
    _ = previewContainer
    return NavigationStack {
        MyChatView(chat:
                    Chat(
                        timestamp: .now,
                        messages:
                            (0..<4)
                            .map {
                                SingleMessage(text: Lorem.words(($0 + 1) * 4), timestamp: .now.advanced(by: TimeInterval($0 * 60)))
                            }
                    )
        ).modelContainer(previewContainer)
        .navigationTitle(Text("My chat with fred"))
    }
}
