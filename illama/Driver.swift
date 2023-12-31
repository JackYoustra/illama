 //
 //  Driver.swift
 //  illama
 //
 //  Created by Jack Youstra on 8/3/23.
 //

import Foundation
import CxxStdlib.string
import AsyncQueue

struct JsonInput: Codable {
    var stream = true
    var nPredict: Int
    var temperature: Double
    var stop: [String]
    var repeatLastN: Int
    var repeatPenalty: Double
    var topK: Int
    var topP: Double
    var tfsZ, typicalP, presencePenalty, frequencyPenalty: Int
    var mirostat, mirostatTau: Int
    var mirostatEta: Double
    var prompt: String
    
    enum CodingKeys: String, CodingKey {
        case stream
        case nPredict = "n_predict"
        case temperature, stop
        case repeatLastN = "repeat_last_n"
        case repeatPenalty = "repeat_penalty"
        case topK = "top_k"
        case topP = "top_p"
        case tfsZ = "tfs_z"
        case typicalP = "typical_p"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case mirostat
        case mirostatTau = "mirostat_tau"
        case mirostatEta = "mirostat_eta"
        case prompt
    }
    
    static let input: Self = {
        let json = #"{"stream":true,"n_predict":400,"temperature":0.7,"stop":["</s>","llama:","User:"],"repeat_last_n":256,"repeat_penalty":1.18,"top_k":40,"top_p":0.5,"tfs_z":1,"typical_p":1,"presence_penalty":0,"frequency_penalty":0,"mirostat":0,"mirostat_tau":5,"mirostat_eta":0.1,"prompt":"This is a conversation between user and a friendly chatbot named llama. respond in simple markdown.\n\nUser: Tell me a fun fact\nllama:"}"#
        let decoder = JSONDecoder()
        return try! decoder.decode(Self.self, from: json.data(using: .utf8)!)
    }()
}

final actor LlamaInferenceQueue {
    struct CurrentItems {
        let type: ModelType
        let instance: LlamaInstance
        
        init(type: ModelType) {
            self.type = type
            self.instance = LlamaInstance(type: type)
        }
    }

    var current: CurrentItems!
    
    init() {
        current = nil
    }
    
    func run_llama(type: ModelType, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        if current?.type != type {
            // replace current type
            current = CurrentItems(type: type)
        }
        return try current.instance.run_llama(type: type, prompt: prompt)
    }
}

final class LlamaInstance {
    private var rc: RunContext

    init(type: ModelType) {
        // run main
    //                    gpt_params.init()
    //     let server_context = ServerContext()
    //     try await server_context.run()
        let args = [
           "server",
//           "--no-mmap",
        ] + (type.shouldMlock ? ["--mlock",] : [])
            + [
            "-m", type.targetHolder.path,
           "-c", String(type.contextSize),
            "-ngl", "1",
            "-v"
        ]
        // Create [UnsafeMutablePointer<Int8>]:
        var cargs = args.map { strdup($0) }
        // Call C function:
        let result = RunContext.runServer(Int32(args.count), &cargs) //runServer(Int32(args.count), &cargs)
        let normieResult = getInt(result)
        assert(normieResult == 0)
        self.rc = getRunContext(result)
        // free dups
        for ptr in cargs { free(ptr) }
    }
    
    // implicitly locked, can just rely on engine lock (unless have to worry about cancel?)
    func run_llama(type: ModelType, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            DispatchQueue.global().async { [weak self] in
                do {
                    let coder = JSONEncoder()
                    var input = JsonInput.input
                    input.prompt = prompt
                    let jsonData = try coder.encode(input)
                    let json = String(data: jsonData, encoding: .utf8)!
                    // ??? ok so cxxstdlib doesn't do lifetimes well...
                    withExtendedLifetime(json) {
                        json.utf8CString.withUnsafeBufferPointer { p in
                            self?.rc.completion(p.baseAddress) { (s: std.string) in
                                // ugh catalyst no worky with this
#if targetEnvironment(macCatalyst)
                                let c = convertToCString(s)!
                                let stringTransfer = String(cString: c)
#else
                                let stringTransfer = String(s)
#endif
                                continuation.yield(stringTransfer)
                            }
                        }
                        continuation.yield(with: .success(""))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
