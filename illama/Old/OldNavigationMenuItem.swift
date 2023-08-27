//
//  OldNavigationMenuItem.swift
//  illama
//
//  Created by Jack Youstra on 8/27/23.
//

import SwiftUI

struct OldNavigationMenuItem: View {
    @ObservedObject var item: FileChat
    @State private var showRename = false
    @State private var showDelete = false
    @State private var hasDeleteError = false
    let duplicateTapped: (FileChat) -> ()
    let delete: () -> ()
    
    var body: some View {
        Text(item.longTime)
        .contextMenu {
            Button {
                showRename = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            // duplicate, share, delete
            Button {
                // create new chat
                do {
                    let newItem = FileChat(timestamp: .now, conversation: item.conversation, isAnswering: item.isAnswering)
                    try newItem.saveToFS()
                    duplicateTapped(newItem)
                } catch {}
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
                delete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if !item.chatTitle.isEmpty {
                Text("Are you sure you want to delete your chat \"\(item.chatTitle)\"?")
            } else {
                Text("Are you sure you want to delete your chat?")
            }
        }.alert("Rename", isPresented: $showRename) {
            TextField(item.longTime, text: $item.chatTitle)
            Button("OK") {}
        }
    }
}

#Preview {
    OldNavigationMenuItem(item: FileChat(timestamp: .now), duplicateTapped: { _ in
        print("Duplicate")
    }, delete: {
        print("Deleting")
    })
}
