//
//  NavigationMenuItem.swift
//  illama
//
//  Created by Jack Youstra on 8/26/23.
//

import SwiftUI

extension Conversation: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

struct NavigationMenuItem: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Chat
    @State private var showRename = false
    @State private var showDelete = false
    @State private var hasDeleteError = false
    
    var body: some View {
        NavigationLink {
            ChatView(chat: item)
        } label: {
            Text(item.longTime)
        }.contextMenu {
            Button {
                showRename = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            // duplicate, share, delete
            Button {
                // create new chat
                let newItem = Chat(timestamp: .now, messages: item.messages, isAnswering: item.isAnswering)
                modelContext.insert(newItem)
                try! modelContext.save()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            if let conversation = item.conversation {
                ShareLink(item: conversation, preview: SharePreview("🦙 at \(item.longTime)"))
            } else {
                Button {
                } label: {
                    Label("Can't share - no content", systemImage: "square.and.arrow.up")
                }.disabled(true)
            }

            Divider()

            Button(role: .destructive) {
                showDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }.alert("Delete", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                do {
                    modelContext.delete(item)
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    hasDeleteError = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if !item.chatTitle.isEmpty {
                Text("Are you sure you want to delete your chat \"\(item.chatTitle)\"?")
            } else {
                Text("Are you sure you want to delete your chat?")
            }
        }.alert("Error deleting", isPresented: $hasDeleteError) {
            Button("OK") {}
        } message: {
            Text("That's all Apple told us! Perhaps try again later?")
        }.alert("Rename", isPresented: $showRename) {
            TextField(item.longTime, text: $item.chatTitle)
            Button("OK") {}
        }
    }
}

#Preview {
    NavigationStack {
        NavigationMenuItem(item: Chat.preview)
    }
}
