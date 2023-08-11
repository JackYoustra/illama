 //
 //  Driver.swift
 //  illama
 //
 //  Created by Jack Youstra on 8/3/23.
 //

import Foundation
import CxxStdlib.string

struct JsonInput: Codable {
    var stream = true
}

let path_model = Bundle.main.path(forResource: "ggml-model-q6k", ofType: "bin")!

 func run_llama() async throws {
     // run main
 //                    gpt_params.init()
//     let server_context = ServerContext()
//     try await server_context.run()
     let args = [
        "server",
         "-m", path_model,
         "-c", "2048",
         "-ngl", "1",
         "-v"
     ]
     // Create [UnsafeMutablePointer<Int8>]:
     var cargs = args.map { strdup($0) }
     // Call C function:
     let result = RunContext.runServer(Int32(args.count), &cargs) //runServer(Int32(args.count), &cargs)
     let normieResult = getInt(result)
     assert(normieResult == 0)
     var rc = getRunContext(result)
     // free dups
     for ptr in cargs { free(ptr) }
     
     var response = httplib.Response()
     let coder = JSONEncoder()
     let jsonData = try coder.encode(JsonInput())
     let json = String(data: jsonData, encoding: .utf8)!
     let cppString = CxxStdlib.std.string(json)
     rc.completion(cppString, &response) { midThing in
         CCompletion.shared.continuation.yield(String(midThing.pointee.body))
     }
     CCompletion.shared.continuation.yield(with: .success(String(response.body)))
 }

final class CCompletion {
    static var shared: CCompletion = CCompletion()
    
    let eventStream: AsyncStream<String>
    let continuation: AsyncStream<String>.Continuation
    
    init() {
        let (eventStream, continuation) = AsyncStream<String>.makeStream()
        self.eventStream = eventStream
        self.continuation = continuation
    }
}
