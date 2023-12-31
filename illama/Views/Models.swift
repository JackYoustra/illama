//
//  Models.swift
//  iLlama
//
//  Created by Jack Youstra on 12/30/23.
//

import Collections
import CombineExt
import Combine
import Foundation
import Perception

@Perceptible
class ModelsRegistry {
    var models: OrderedDictionary<ModelType, Models> = OrderedDictionary.init(
        uniqueKeysWithValues: ModelType.allCases.map { model in
            (model, Models(model))
        }
    )
}

@Perceptible
class Models: Identifiable {
    let type: ModelType
    var downloading: DownloadingStatus
    
    /// The following steps are taken for a download, one tag at a time
    /// 0) Do data check (reachability), memory check, etc. and necessary warnings
    /// 1) Download the tag from ODR: this is one tag at a time
    /// 2) Copy (clone if possible) tag set to persistent memory
    /// 3) Take cloned data and consolidate to one file, removing one at a time
    /// 4) Repeat for every tag
    enum DownloadingStatus: Sendable, Equatable {
        /// Haven't completed ODR download, on step 1
        case incomplete
        /// In-progress for ODR download, performing step 1-3
        case progressing(Double)
        /// Weren't able to download successfully 😢
        case failed
        /// We completed the download and the model is ready to use 😄
        case completed
        
        var isIncomplete: Bool {
            switch self {
            case .incomplete:
                return true
            default:
                return false
            }
        }
        
        var progression: Double? {
            switch self {
            case .progressing(let status):
                return status
            default:
                return nil
            }
        }
        
        var working: Bool {
            switch self {
            case .progressing:
                return true
            default:
                return false
            }
        }
    }
    
    
    init(_ type: ModelType) {
        self.type = type
        if FileManager.default.fileExists(atPath: type.finalizedLocation.path()) {
            if type.processingIsDone {
                self.downloading = .completed
            }
        }
        self.downloading = .incomplete
    }
    
    func advance() async {
        switch downloading {
        case .incomplete:
            await self.download()
        case .failed:
            await self.download()
        default:
            fatalError("Can't interact here!")
        }
    }

    private func download() async {
        let targetSize = type.finalizedLocation.size() ?? 0
        do {
            for (index, tag) in type.bundleTags.enumerated() {
                let currentCursorPosition = UInt64(index) * ModelType.blockSize
                if targetSize >= UInt64(index + 1) * ModelType.blockSize {
                    // we've already been here
                    continue
                }
                // we haven't been here!
                let resourceRequest = NSBundleResourceRequest(tags: [tag])
                let currentFraction = Double(index) / Double(type.bundleTags.count)
                // TODO: There's a set of common NSBundleResourceRequest errors in the docs
                // handle those
                let cancellation = resourceRequest.progress.publisher(for: \.fractionCompleted, options: .new)
                    .prepend(0.0)
                    .append(1.0)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] progress in
                        self?.downloading = .progressing(progress * currentFraction)
                    }
                try await resourceRequest.beginAccessingResources()
                // now copy over
                let targetFile = try FileHandle(forWritingTo: type.finalizedLocation)
                try targetFile.truncate(atOffset: currentCursorPosition)
                let resourceURL = resourceRequest.bundle.resourceURL!
                let resource = resourceURL.appendingPathComponent(tag)
                let data = try Data(contentsOf: resource)
                targetFile.seek(toFileOffset: currentCursorPosition)
                try targetFile.write(contentsOf: data)
                try targetFile.synchronize()
                let isAtExpectedSize = try targetFile.offset() == type.finalizedSpace
                assert(isAtExpectedSize)
                try targetFile.close()
                resourceRequest.endAccessingResources()
            }
        } catch {
            downloading = .failed
        }
    }

    var id: ModelType.ID {
        type.id
    }
}
