 //
 //  Driver.swift
 //  illama
 //
 //  Created by Jack Youstra on 8/3/23.
 //

 import Foundation
 import llama

let path_model = Bundle.main.path(forResource: "ggml-model-q6k", ofType: "bin")!

 struct GptParams {
     let seed: UInt32 = .max
     let n_threads: Int32 = Int32(max(ProcessInfo.processInfo.activeProcessorCount - 1, 1))
     let n_predict: Int32 = -1
     var n_ctx: Int32 = 512
     let n_batch: Int32 = 512
     let n_gqa: Int32 = 1
     var n_keep: Int32 = 0
     let n_chunks: Int32 = -1
     var n_gpu_layers: Int32 = 0
     let main_gpu: Int32 = 0
     let tensor_split: [Float] = [0]
     let n_probs: Int32 = 0
     let rms_norm_eps: Float = LLAMA_DEFAULT_RMS_EPS
     let rope_freq_base: Float = 10000.0
     let rope_freq_scale: Float = 1.0

     let logit_bias: [llama_token: Float] = [:]
     let top_k: Int32 = 40
     let top_p: Float = 0.95
     let tfs_z: Float = 1
     let typical_p: Float = 1
     let temp: Float = 0.8
     let repeat_penalty: Float = 1.10
     let repeat_last_n: Int32 = 64
     let frequency_penalty: Float = 0
     let presence_penalty: Float = 0
     let mirostat: Int32 = 0
     let mirostat_tau: Float = 5.0
     let mirostat_eta: Float = 0.1
     
     let cfg_scale: Float = 1.0
     var model: String = ""
     var model_alias: String = "unknown"
     var prompt = ""
     let path_prompt_cache = ""
     let input_prefix = ""
     let input_suffix = ""
     let antiprompt: [String] = []
     let lora_adapter = ""
     let lora_base = ""
     let hellaswag = false
     let hellaswag_tasks = 400
     let low_vram = false
     let mul_mat_q = false
     let memory_f16 = true
     let random_prompt = false
     let use_color = false
     let interactive = false
     let prompt_cache_all = false
     let prompt_cache_ro = false
     let embedding = false
     let interactive_first = false
     let multiline_input = false
     let input_prefix_bos = false
     let instruct = false
     let penalize_nl = true
     let perplexity = false
     let use_mmap = true
     let use_mlock = false
     let mem_test = false
     let numa = false
     let export_cgraph = false
     let verbose_prompt = false
     
     static var defaultParams: Self {
         var thing = Self()
         thing.model = path_model
         thing.n_gpu_layers = 1
         thing.n_ctx = 2048
         return thing
     }
     
     var llamaContext: llama_context_params {
         var lparams = llama_context_default_params()
         let params = self
         lparams.n_ctx           = params.n_ctx;
         lparams.n_batch         = params.n_batch;
         lparams.n_gqa           = params.n_gqa;
         lparams.rms_norm_eps    = params.rms_norm_eps;
         lparams.n_gpu_layers    = params.n_gpu_layers;
         lparams.main_gpu        = params.main_gpu;
         params.tensor_split.withUnsafeBufferPointer { p in
             lparams.tensor_split    = p.baseAddress;
         }
         lparams.low_vram        = params.low_vram;
         lparams.mul_mat_q       = params.mul_mat_q;
         lparams.seed            = params.seed;
         lparams.f16_kv          = params.memory_f16;
         lparams.use_mmap        = params.use_mmap;
         lparams.use_mlock       = params.use_mlock;
         lparams.logits_all      = params.perplexity;
         lparams.embedding       = params.embedding;
         lparams.rope_freq_base  = params.rope_freq_base;
         lparams.rope_freq_scale = params.rope_freq_scale;
         return lparams
     }
 }

 struct CompletionTokenOutput {
     struct TokenProb: Hashable {
         let tok: llama_token
         let prob: Float
     }
    
     var probs: [TokenProb] = []
     var tok: llama_token = -1
 }

 // lock via ServerContext actor
 actor ServerContext {
     var stream = false
     var has_next_token = false
     var generated_text: String? = nil
     var generated_token_probs: [CompletionTokenOutput] = []
    
     var num_prompt_tokens: size_t = 0
     var num_tokens_predicted: size_t = 0
     var n_past: size_t = 0
     var n_remain: size_t = 0
    
     var embd: [llama_token] = []
     var last_n_tokens: [llama_token] = []

     // llama model
     var model: OpaquePointer! = nil
     // llama context
     var ctx: OpaquePointer! = nil
     var params: GptParams = GptParams.defaultParams

     var truncated: Bool = false
     var stopped_eos: Bool = false
     var stopped_word: Bool = false
     var stopped_limit: Bool = false
     var stopping_word: String? = nil
     var multibyte_pending: Int32 = 0
     
     func loadModel(params: GptParams) throws {
         (self.model, self.ctx) = try llama_init_from_gpt_params(params: params)
         last_n_tokens = .init(repeating: 0, count: Int(params.n_ctx))
     }
     
     func loadPrompt() throws {
         params.prompt.insert(" ", at: params.prompt.startIndex)
         var prompt_tokens = llama_tokenize(ctx, params.prompt, true)
         num_prompt_tokens = prompt_tokens.count
         
         if params.n_keep < 0 {
             params.n_keep = Int32(num_prompt_tokens)
         }
         params.n_keep = min(params.n_ctx - 4, params.n_keep)
         
         if num_prompt_tokens >= params.n_ctx {
             let n_left = (params.n_ctx - params.n_keep) / 2
             var new_tokens = prompt_tokens.prefix(Int(params.n_keep))
             let erased_blocks = Int32(num_prompt_tokens) - params.n_keep - n_left - 1
             new_tokens.append(contentsOf: prompt_tokens.dropFirst(Int(params.n_keep + erased_blocks * n_left)))
             last_n_tokens.replaceSubrange(0..<Int(params.n_ctx), with: prompt_tokens.suffix(Int(params.n_ctx)))
             truncated = true
             prompt_tokens = Array(new_tokens)
         } else {
             let ps = num_prompt_tokens
             let partitioned = last_n_tokens.count - ps
             last_n_tokens.replaceSubrange(0 ..< partitioned, with: repeatElement(1, count: ps))
             last_n_tokens.replaceSubrange(partitioned..<last_n_tokens.count, with: prompt_tokens)
         }
         
        n_past = common_part(a: embd, b: prompt_tokens)
         embd = prompt_tokens
         if n_past == num_prompt_tokens {
             n_past -= 1
         }
         
         has_next_token = true
     }
     
     func beginCompletion() {
         n_remain = size_t(params.n_predict)
         llama_set_rng_seed(ctx, params.seed)
     }
     
     func nextToken() throws -> CompletionTokenOutput {
         var result = CompletionTokenOutput()
         
         if embd.count >= params.n_ctx {
             // reset context
             let n_left = (params.n_ctx - params.n_keep) / 2
             var new_tokens: [llama_token] = []
             new_tokens.append(contentsOf: embd.prefix(Int(params.n_keep)))
             new_tokens.append(contentsOf: embd.suffix(Int(n_left)))
             embd = new_tokens
             n_past = size_t(params.n_keep)
             truncated = true
         }
         
         while n_past < embd.count {
             var n_eval = embd.count - n_past
             if n_eval > params.n_batch {
                 n_eval = Int(params.n_batch)
             }
             let result = embd.withUnsafeBufferPointer {
                 llama_eval(ctx, $0.baseAddress!.advanced(by: n_past), Int32(n_eval), Int32(n_past), params.n_threads)
             }
             if result != 0 {
                 has_next_token = false
                 throw ServerError.eval
             }
             n_past += n_eval
         }
         
         if params.n_predict == 0 {
             has_next_token = false
             return CompletionTokenOutput(probs: [], tok: llama_token_eos())
         }
         
         // out of user input, sample next token
         let temp = params.temp
         let top_k = params.top_k <= 0 ? llama_n_vocab(ctx) : params.top_k;
         let top_p = params.top_p;
         let tfs_z = params.tfs_z;
         let typical_p = params.typical_p;
         let repeat_last_n = params.repeat_last_n < 0 ? params.n_ctx : params.repeat_last_n;
         let repeat_penalty = params.repeat_penalty;
         let alpha_presence = params.presence_penalty;
         let alpha_frequency = params.frequency_penalty;
         let mirostat = params.mirostat;
         let mirostat_tau = params.mirostat_tau;
         let mirostat_eta = params.mirostat_eta;
         let penalize_nl = params.penalize_nl;
         let n_probs = params.n_probs;
         
         do {
             let logits = llama_get_logits(ctx)!
             let n_vocab = llama_n_vocab(ctx)
             
             for (first, second) in params.logit_bias {
                 logits[Int(first)] += second
             }
             
             var candidates: [llama_token_data] = []
             candidates.reserveCapacity(Int(n_vocab))
             for token_id in 0..<n_vocab {
                 candidates.append(llama_token_data(id: token_id, logit: logits[Int(token_id)], p: 0.0))
             }
             
             let candidate_count = candidates.count
             var candidates_p: llama_token_data_array = candidates.withUnsafeMutableBufferPointer {
                 llama_token_data_array(data: $0.baseAddress!, size: candidate_count, sorted: false)
             }
             
             let nl_logit = logits[Int(llama_token_nl())]
             let last_n_repeat = min(min(Int32(last_n_tokens.count), repeat_last_n), params.n_ctx)
             let lastNTokenCount = last_n_tokens.count
             last_n_tokens.withUnsafeBufferPointer {
                 llama_sample_repetition_penalty(ctx, &candidates_p, $0.baseAddress! + lastNTokenCount - UnsafePointer<llama_token>.Stride(last_n_repeat), Int(last_n_repeat), repeat_penalty)
                 llama_sample_frequency_and_presence_penalties(ctx, &candidates_p, $0.baseAddress! + lastNTokenCount - UnsafePointer<llama_token>.Stride(last_n_repeat), Int(last_n_repeat), alpha_frequency, alpha_presence)
             }
             
             if !penalize_nl {
                 logits[Int(llama_token_nl())] = nl_logit
             }
             
             if temp <= 0 {
                 result.tok = withUnsafeMutablePointer(to: &candidates_p) {
                     let thing = llama_sample_token_greedy(ctx, $0)
                     if n_probs > 0 {
                        llama_sample_softmax(ctx, $0)
                     }
                     return thing
                 }
             } else {
                 if mirostat == 1 {
                     Self.mirostat_mu = 2.0 * mirostat_tau
                     result.tok = withUnsafeMutablePointer(to: &candidates_p) { cp in
                         let mirostat_m: Int32 = 100
                         llama_sample_temperature(ctx, cp, temp)
                         return withUnsafeMutablePointer(to: &Self.mirostat_mu) { mm in
                             llama_sample_token_mirostat(ctx, cp, mirostat_tau, mirostat_eta, mirostat_m, mm)
                         }
                     }
                 } else if mirostat == 2 {
                     Self.mirostat_mu = 2 * mirostat_tau
                     result.tok = withUnsafeMutablePointer(to: &candidates_p) { cp in
                         llama_sample_temperature(ctx, cp, temp)
                         return withUnsafeMutablePointer(to: &Self.mirostat_mu) { mm in
                             llama_sample_token_mirostat_v2(ctx, cp, mirostat_tau, mirostat_eta, mm)
                         }
                     }
                 } else {
                     // temperature sampling
                     result.tok = withUnsafeMutablePointer(to: &candidates_p) { cp in
                         let min_keep = max(1, n_probs)
                         llama_sample_top_k(ctx, cp, top_k, Int(min_keep))
                         llama_sample_tail_free(ctx, cp, tfs_z, Int(min_keep))
                         llama_sample_typical(ctx, cp, typical_p, Int(min_keep))
                         llama_sample_top_p(ctx, cp, top_p, Int(min_keep))
                         llama_sample_temperature(ctx, cp, temp)
                         return llama_sample_token(ctx, cp)
                     }
                 }
             }
             
             result.probs.append(contentsOf: (0 ..< min(candidates_p.size, Int(n_probs))).map { index in
                 let item = candidates_p.data.advanced(by: index).pointee
                 return CompletionTokenOutput.TokenProb(tok: item.id, prob: item.p)
             })
             
             last_n_tokens.removeFirst()
             last_n_tokens.append(result.tok)
             num_tokens_predicted += 1
         }
         
         embd.append(result.tok)
         
         n_remain -= 1
         
         if !embd.isEmpty, embd.last == llama_token_eos() {
             has_next_token = false
             stopped_eos = true
             return result
         }
         
         has_next_token = params.n_predict == -1 || n_remain != 0
         return result
     }
     
     func doCompletion() throws -> CompletionTokenOutput {
         let token_with_probs = try nextToken()
         
         let token_text: String = token_with_probs.tok == -1 ? "" : String(utf8String: llama_token_to_str(ctx, token_with_probs.tok)!)!
         
         generated_text! += token_text
         
         if params.n_probs > 0 {
             generated_token_probs.append(token_with_probs)
         }
         
         if multibyte_pending > 0 {
             multibyte_pending -= Int32(token_text.count)
         } else if token_text.count == 1 {
             // 2-byte characters: 110xxxxx 10xxxxxx
             token_text.utf8CString.withUnsafeBufferPointer { b in
                 b.withMemoryRebound(to: UInt8.self) {
                     let pt = $0.baseAddress!.pointee
                     if (pt & 0xE0) == 0xC0 {
                         multibyte_pending = 1
                         // 3-byte characters: 1110xxxx 10xxxxxx 10xxxxxx
                     } else if (pt & 0xF0) == 0xE0 {
                         multibyte_pending = 2
                         // 4-byte characters: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                     } else if (pt & 0xF8) == 0xF0 {
                         multibyte_pending = 3
                     } else {
                         multibyte_pending = 0
                     }
                 }
             }
         }
         
         if multibyte_pending > 0, !has_next_token {
             has_next_token = true
             n_remain += 1
         }
         
         if !has_next_token, n_remain == 0 {
             stopped_limit = true
         }
         
         return token_with_probs
     }
     
     static var mirostat_mu: Float! = nil
     
     enum ServerError: Error {
         case eval
     }
     
     func run() throws {
         if params.model_alias == "unknown" {
             params.model_alias = params.model
         }
         llama_backend_init(params.numa)
         defer {
             llama_backend_free()
         }
         
         try loadModel(params: params)
     }
 }

func common_part(a: [llama_token], b: [llama_token]) -> Int {
    var i = 0
    while i < a.count && i < b.count && a[i] == b[i] {
        i += 1
    }
    return i
}

func llama_tokenize(_ ctx: OpaquePointer, _ text: String, _ add_bos: Bool) -> [llama_token] {
    // initialize to prompt numer of chars, since n_tokens <= n_prompt_chars
    var res = [llama_token](repeating: llama_token(), count: text.count + (add_bos ? 1 : 0))
    let n = llama_tokenize(ctx, text, &res, Int32(res.count), add_bos)
    assert(n >= 0)
    res.removeLast(res.count - Int(n))
    return res
}

 func loadModel() {
     // cpp is:
 //    params = params_;
 //    std::tie(model, ctx) = llama_init_from_gpt_params(params);
 //    if (model == nullptr)
 //    {
 //        LOG_ERROR("unable to load model", {{"model", params_.model}});
 //        return false;
 //    }
 //
 //    last_n_tokens.resize(params.n_ctx);
 //    std::fill(last_n_tokens.begin(), last_n_tokens.end(), 0);
 //    return true;
 }

 //std::tuple<struct llama_model *, struct llama_context *> llama_init_from_gpt_params(const gpt_params & params) {
 //    auto lparams = llama_context_params_from_gpt_params(params);
 //
 //    llama_model * model  = llama_load_model_from_file(params.model.c_str(), lparams);
 //    if (model == NULL) {
 //        fprintf(stderr, "%s: error: failed to load model '%s'\n", __func__, params.model.c_str());
 //        return std::make_tuple(nullptr, nullptr);
 //    }
 //
 //    llama_context * lctx = llama_new_context_with_model(model, lparams);
 //    if (lctx == NULL) {
 //        fprintf(stderr, "%s: error: failed to create context with model '%s'\n", __func__, params.model.c_str());
 //        llama_free_model(model);
 //        return std::make_tuple(nullptr, nullptr);
 //    }
 //
 //    if (!params.lora_adapter.empty()) {
 //        int err = llama_model_apply_lora_from_file(model,
 //                                             params.lora_adapter.c_str(),
 //                                             params.lora_base.empty() ? NULL : params.lora_base.c_str(),
 //                                             params.n_threads);
 //        if (err != 0) {
 //            fprintf(stderr, "%s: error: failed to apply lora adapter\n", __func__);
 //            llama_free(lctx);
 //            llama_free_model(model);
 //            return std::make_tuple(nullptr, nullptr);
 //        }
 //    }
 //
 //    return std::make_tuple(model, lctx);
 //}

 enum LlamaError: Error {
     case loadError
     case contextError
     case loraError
 }

func llama_init_from_gpt_params(params: GptParams) throws -> (OpaquePointer, OpaquePointer) {
    let model = try params.model.utf8CString.withUnsafeBufferPointer {
         let params = llama_context_params()
         guard let model = llama_load_model_from_file($0.baseAddress, params) else {
             throw LlamaError.loadError
         }
        return model
     }
    guard let lctx = llama_new_context_with_model(model, params.llamaContext) else {
        llama_free_model(model)
        throw LlamaError.contextError
    }
    if !params.lora_adapter.isEmpty {
        let error = params.lora_adapter.utf8CString.withUnsafeBufferPointer {
            if params.lora_base.isEmpty {
                llama_model_apply_lora_from_file(model, $0.baseAddress, nil, params.n_threads)
            } else {
                params.lora_base.utf8CString.withUnsafeBufferPointer { l in
                    llama_model_apply_lora_from_file(model, l.baseAddress, nil, params.n_threads)
                }
            }
        }
        if error != 0 {
            llama_free(lctx)
            llama_free_model(model)
            throw LlamaError.loraError
        }
    }
    
    return (model, lctx)
 }

 func run_llama() async throws {
     // run main
 //                    gpt_params.init()
     let server_context = ServerContext()
     try await server_context.run()
 }
