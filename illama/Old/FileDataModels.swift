//
//  FileDataModels.swift
//  illama
//
//  Created by Jack Youstra on 8/27/23.
//

import Foundation
import Combine

final class FileChat: Codable, ObservableObject {
    @Published var id: UUID
    @Published var timestamp: Date
    @Published var conversation: Conversation?
    @Published var isAnswering: Bool
    @Published var chatTitle: String
    @Published var modelType: ModelType
    
    func add(query: String) {
        assert(!isAnswering)
        if conversation == nil {
            conversation = .init(prompt: query)
        } else {
            conversation?.add(query: query)
        }
    }
    
    var cancellation: AnyCancellable? = nil
    
    static let saveQueue = DispatchQueue.global()
    
    func setupAutosave() {
        cancellation = objectWillChange
            .receive(on: Self.saveQueue)
            .debounce(for: .seconds(1), scheduler: Self.saveQueue).sink { [weak self] in
            try? self?.saveToFS()
        }
    }
    
    init(timestamp: Date, modelType: ModelType) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = nil
        self.isAnswering = false
        self.chatTitle = ""
        self.modelType = modelType
        setupAutosave()
    }
    
    init(timestamp: Date = .now, conversation: Conversation? = nil, isAnswering: Bool = false, chatTitle: String = "", modelType: ModelType = .smallLlama) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversation = conversation
        self.isAnswering = isAnswering
        self.chatTitle = chatTitle
        self.modelType = modelType
        setupAutosave()
    }
    
    var saveLocation: URL {
        URL.documentsDirectory.appending(path: "\(id.uuidString).txt")
    }
    
    func deleteFromFS() throws {
        try FileManager.default.removeItem(at: saveLocation)
    }

    // encode file
    func saveToFS() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        try data.write(to: saveLocation)
    }
    
    // Manual CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case conversation
        case isAnswering
        case chatTitle
        case modelType
    }

    // Manual encode / decode
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.conversation = try container.decode(Conversation.self, forKey: .conversation)
        self.isAnswering = try container.decode(Bool.self, forKey: .isAnswering)
        self.chatTitle = try container.decode(String.self, forKey: .chatTitle)
        self.modelType = try container.decodeIfPresent(ModelType.self, forKey: .modelType) ?? .smallLlama
        setupAutosave()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(conversation, forKey: .conversation)
        try container.encode(isAnswering, forKey: .isAnswering)
        try container.encode(chatTitle, forKey: .chatTitle)
        try container.encode(modelType, forKey: .modelType)
    }
}
