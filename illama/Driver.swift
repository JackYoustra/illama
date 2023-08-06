 //
 //  Driver.swift
 //  illama
 //
 //  Created by Jack Youstra on 8/3/23.
 //

 import Foundation

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
     let result = runServer(Int32(args.count), &cargs)
     assert(result == 0)
     // free dups
     for ptr in cargs { free(ptr) }
 }
