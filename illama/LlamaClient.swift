//
//  LlamaClient.swift
//  illama
//
//  Created by Jack Youstra on 8/19/23.
//

import Dependencies
import LoremSwiftum
import AsyncAlgorithms
import Combine
import Foundation
import CombineExt

struct LlamaClient {
    var query: (String) async throws -> AsyncThrowingStream<DataString, Error>
}

extension DependencyValues {
    var llama: LlamaClient {
        get { self[LlamaClientKey.self] }
        set { self[LlamaClientKey.self] = newValue }
    }
    
    private enum LlamaClientKey: DependencyKey {
        static let liveValue: LlamaClient = LlamaClient.preview
        static let testValue: LlamaClient = LlamaClient(query: unimplemented())
        static let previewValue: LlamaClient = LlamaClient.preview
    }
}

extension LlamaClient {
    static let live: LlamaClient = {
        let decoder = JSONDecoder()
        return LlamaClient(
            query: { q in
                try await LlamaInstance.shared.run_llama(prompt: q)
                    .compactMap {
                        try? decoder.decode(
                            DataString.self,
                            from: $0.data(using: .utf8)!
                        )
                    }
                    .eraseToThrowingStream()
            }
        )
    }()
    
    static let preview: LlamaClient = LlamaClient { str in
        chain(
                zip(
                Lorem.words(3)
                    .split(separator: /\s/)
                    .async,
                SuspendingClock()
                    .timer(interval: .milliseconds(50))
            ).map { DataString(content: String($0.0), stop: false) },
            [DataString(content: "Done!", stop: true)].async
        )
        .eraseToThrowingStream()
    }
}
