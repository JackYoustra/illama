//
//  FileDataModels.swift
//  illama
//
//  Created by Jack Youstra on 8/27/23.
//

import Foundation

final class FileChat: ObservableObject {
    var id: UUID
    var timestamp: Date
    var conversation: Conversation?
    var isAnswering: Bool
    var chatTitle: String
    
    init(timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = nil
        self.isAnswering = false
        self.chatTitle = ""
    }
}
