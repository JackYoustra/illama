//
//  OldContentView.swift
//  illama
//
//  Created by Jack Youstra on 8/26/23.
//

import SwiftUI

struct OldContentView: View {
    @State private var items: [FileChat]? = nil
    @AppStorage("selectedChatID") private var selectedItem: UUID? = nil

    var body: some View {
        NavigationSplitView {
            NavigationSplitView {
                List(selection: $selectedItem) {
                    ForEach(items ?? [], id: \.id) { item in
                        OldNavigationMenuItem(item: item) {
                            items?.append($0)
                        } delete: {
                            guard let index = items?.firstIndex(where: { $0.id == item.id }) else { return }
                            guard let toBeDeleted = items?.remove(at: index) else { return }
                            try? toBeDeleted.deleteFromFS()
                        }.onTapGesture {
                            
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                VStack {
                    Text("🦙")
                    Button("Start a conversation") {
                        addItem()
                    }
                }
                .font(.system(size: 144.0))
                .minimumScaleFactor(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task {
                if items == nil {
                    // get all files in the documents directory
                    let fileURLs = try! FileManager.default.contentsOfDirectory(at: .documentsDirectory, includingPropertiesForKeys: nil)
                    let decoder = JSONDecoder()
                    items = fileURLs.compactMap {
                        // decode FileChat from file
                        guard let data = try? Data(contentsOf: $0) else { return nil }
                        guard let fileChat = try? decoder.decode(FileChat.self, from: data) else { return nil }
                        return fileChat
                    }
                }
            }
        } detail: {
            if let selectedItem, let item = items?.first(where: { $0.id == selectedItem }) {
                OldChatView(chat: item)
            } else {
                VStack {
                    Text("🦙")
                        .modifier(InfiniteRotation())
                    if items == nil {
                        Text("Loading previous conversations")
                    } else {
                        Button("Start a conversation") {
                            addItem()
                        }
                    }
                }
                .font(.system(size: 144.0))
                .minimumScaleFactor(0.1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                
        }
    }
        
    private func addItem() {
        withAnimation {
            items?.append(FileChat(timestamp: .now))
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                try? items?[index].deleteFromFS()
            }
            items?.remove(atOffsets: offsets)
        }
    }
}

#Preview {
    OldContentView()
}
