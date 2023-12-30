//
//  ModelDownloadView.swift
//  iLlama
//
//  Created by Jack Youstra on 12/29/23.
//

import Collections
import SwiftUI
import Perception

enum ModelType: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case smallLlama
    
    var memoryRequirement: Double {
        0
    }
    
    var spaceRequirement: Double {
        0
    }
    
    var folderName: String {
        rawValue
    }
    
    var id: String {
        rawValue
    }
    
    var tagPrefix: String {
        "3b_q4_"
    }
    
    var chunkCount: UInt {
        4
    }
    
    var bundleTags: [String] {
        assert(chunkCount < 26)
        return (0..<chunkCount).map {
            tagPrefix + String(Character(UnicodeScalar(UInt32(UInt8($0) + ("a" as Character).asciiValue!))!))
        }
    }
}

@Perceptible
class ModelsRegistry {
    var models: OrderedDictionary<ModelType, Models> = OrderedDictionary.init(
        uniqueKeysWithValues: ModelType.allCases.map { model in
            (model, Models(model))
        }
    )
}

struct ModelDownloadView: View {
    @SceneStorage("unsafeMode") var unsafeMode = false
    let registry: ModelsRegistry
    
    var body: some View {
        WithPerceptionTracking {
            contents
        }
    }
    
    var contents: some View {
        VStack {
            Text("We have many different models for you to choose from! Which do you want to check out?")
            ForEach(registry.models.values) { model in
                ModelDownloadButton(model: model)
            }
            
            VStack {
                Toggle("Unsafe Mode", isOn: $unsafeMode)
                Text("By turning on unsafe mode, you agree that your app will probably crash when running any of the yellow-colored models.")
                    .font(.caption)
            }
        }
    }
}

@Perceptible
class Models: Identifiable {
    let type: ModelType
    var downloading: DownloadingStatus = .unknown {
        didSet {
            if downloading == .completed {
                // cleanup
                resourceRequest.endAccessingResources()
            }
        }
    }
    
    enum DownloadingStatus: Sendable, Equatable {
        /// Haven't queried or determined yet
        case unknown
        /// Haven't completed ODR download
        case incomplete(Double)
        /// In-progress for ODR download
        case progressing(Double)
        /// Only resident - need to reconstruct full model via copying
        case residentOnlyPending
        case consolidating(Double)
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
            case .progressing(let status), .consolidating(let status):
                return status
            default:
                return nil
            }
        }
    }
    
    let resourceRequest: NSBundleResourceRequest
    
    init(_ type: ModelType) {
        self.type = type
        // Check if the set is on the device first!
        // TODO: Handle migration too plz thx
        resourceRequest = NSBundleResourceRequest(tags: Set(type.bundleTags))
        resourceRequest.conditionallyBeginAccessingResources { [weak self] isResident in
            fatalError("Handle pinning + migration stuffs")
            self?.downloading = isResident ? .completed : .incomplete
        }
    }

    func download() {
        if downloading.isIncomplete {
            downloading = .progressing(0)
            let directory = URL.documentsDirectory.appending(path: type.folderName, directoryHint: .isDirectory)
            // TODO: make all this async probably
            let cancellation = resourceRequest.progress.publisher(for: \.fractionCompleted, options: .new)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] progress in
                    self?.downloading = .progressing(progress)
                }
            resourceRequest.beginAccessingResources { [weak self] error in
                DispatchQueue.main.async {
                    cancellation.cancel()
                    guard let self else { return }
                    if let error {
                        self.downloading = .failed
                    } else {
                        self.downloading = .residentOnlyPending
                        self.consolidate()
                    }
                }
            }
        }
    }
    
    func consolidate() {
        if self.downloading == .residentOnlyPending {
            self.downloading = .consolidating(0)
            let resources = resourceRequest.bundle.resourceURL   
        }
    }

    var id: ModelType.ID {
        type.id
    }
}

struct ModelDownloadButton: View {
    let model: Models
    
    var body: some View {
        WithPerceptionTracking {
            contents
        }
    }
    
    var contents: some View {
        HStack {
            Button {
                model.download()
            } label: {
                VStack {
                    Text("Small Llama")
                    Text("3 GB")
                        .font(.caption)
                }
            }
            Spacer()
            
        }
    }
}
