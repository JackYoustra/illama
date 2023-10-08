//
//  server_header.h
//  illama
//
//  Created by Jack Youstra on 8/6/23.
//

#ifndef server_header_h
#define server_header_h

#include <functional>
#include <string>
#include "llama_header.h"
#include "/Users/jack/Documents/llm/llama.cpp/examples/server/httplib.h"

#define LLAMA_SUPPORTS_GPU_OFFLOAD

// completion token output with probabilities
struct completion_token_output
{
    struct token_prob
    {
        llama_token tok;
        float prob;
    };

    std::vector<token_prob> probs;
    llama_token tok;
};

enum stop_type
{
    STOP_FULL,
    STOP_PARTIAL,
};

struct llama_server_context
{
    bool stream = false;
    bool has_next_token = false;
    std::string generated_text;
    std::vector<completion_token_output> generated_token_probs;
    
    size_t num_prompt_tokens = 0;
    size_t num_tokens_predicted = 0;
    size_t n_past = 0;
    size_t n_remain = 0;
    
    std::vector<llama_token> embd;
    std::vector<llama_token> last_n_tokens;
    
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    gpt_params params;
    
    bool truncated = false;
    bool stopped_eos = false;
    bool stopped_word = false;
    bool stopped_limit = false;
    std::string stopping_word;
    int32_t multibyte_pending = 0;
    
    std::mutex mutex;
    
    std::unique_lock<std::mutex> lock();
    
    ~llama_server_context();
    
    void rewind();
    
    bool loadModel(const gpt_params&);
    
    void loadPrompt();
    
    void beginCompletion();
    
    completion_token_output nextToken();
    
    size_t findStoppingStrings(const std::string &text, const size_t last_token_size,
                                                     const stop_type type);
    
    completion_token_output doCompletion();
    
    std::vector<float> getEmbedding();

};

struct ResultRunContext;

#include<iostream>

typedef void (^CompletionCallback)(const std::string&);

class RunContext {
    RunContext();
public:
    // dumb thing: just shared ptr and do the normal ctors
    std::shared_ptr<llama_server_context> llama;
    
    // copy ctor
    RunContext(const RunContext &other) : llama(other.llama) {}
    
    // move ctor
    RunContext(RunContext &&other) : llama(std::move(other.llama)) {}
    
    void completion(const char* json_params, CompletionCallback callback);
    
    static std::variant<int, RunContext> runServer(int argc, char **argv);
};

int getInt(const std::variant<int, RunContext>& v);

RunContext getRunContext(const std::variant<int, RunContext>& v);

const char* convertToCString(const std::string& str);

size_t findOffsetInFile(const char* filename, const void* key, size_t keylen);

#endif /* server_header_h */
