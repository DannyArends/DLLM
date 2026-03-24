/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module model;

import includes;
import utils;

struct LlamaModel {
  llama_model* model = null;      /// Model pointer
  llama_context* ctx = null;      /// Context pointer
  llama_vocab* vocab = null;      /// Vocabulary pointer
  llama_sampler* sampler = null;  /// Sampler pointer
  llama_sampler* json = null;  /// Sampler pointer
  mtmd_context* vision = null;    /// Vision context pointer
  alias model this;
}

// Free LlamaModel resources
void free(ref LlamaModel model) {
  if (model.vision) { mtmd_free(model.vision); model.vision = null; }
  if (model.sampler) { llama_sampler_free(model.sampler);  model.sampler = null; }
  if (model.json) { llama_sampler_free(model.json);  model.json = null; }
  if (model.ctx) { llama_free(model.ctx); model.ctx = null; }
  if (model.model) { llama_model_free(model.model); model.model = null; }
}

// Cpu or Gpu model ?
llama_model_params mCpu() { llama_model_params mp = llama_model_default_params(); mp.n_gpu_layers =  0; return(mp); }
llama_model_params mGpu() { llama_model_params mp = llama_model_default_params(); mp.n_gpu_layers = -1; return(mp); }

// Model context paramters
llama_context_params context(uint32_t n_ctx = 16384, uint32_t n_batch = 512, ggml_type type = GGML_TYPE_Q8_0, bool KQVonGpu = true) {
  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = n_ctx; cp.n_batch = n_batch; cp.n_ubatch = n_batch; 
  cp.n_threads = totalCPUs; cp.n_threads_batch = totalCPUs;
  cp.type_k = type; cp.type_v = type;
  cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED; cp.offload_kqv = KQVonGpu; cp.no_perf = true;
  return(cp);
}

// Model embeddings parameters
llama_context_params embedding(uint32_t n_batch = 512) {
  llama_context_params cp = context(n_batch, n_batch, GGML_TYPE_Q8_0, false);
  cp.embeddings = true; cp.pooling_type = LLAMA_POOLING_TYPE_CLS;
  return(cp);
}

// Does the model think ?
bool isThinking(LlamaModel model) { return(model.tokenize("<think>", false)[0] != LLAMA_TOKEN_NULL); }

// Tokenize a string prompt into tokens
llama_token[] tokenize(LlamaModel model, string txt, bool add = true, bool parse = true) {
  llama_token[] tokens;
  tokens.length = (-llama_tokenize(model.vocab, txt.ptr, cast(int)txt.length, null, 0, add, parse));
  llama_tokenize(model.vocab, txt.ptr, cast(int)txt.length, tokens.ptr, cast(int)(tokens.length), add, parse);
  return(tokens);
}

// De-tokenize a list of tokens tokens into a string
string detokenize(LlamaModel model, llama_token[] tokens) {
  auto txt = appender!string;
  char[256] buf = 0;
  for (size_t i = 0; i < tokens.length; i++) {
    int n = llama_token_to_piece(model.vocab, tokens[i], buf.ptr, buf.sizeof, 0, true);
    if (n > 0) { txt ~= cast(string)buf[0..n]; }
  }
  return(txt.data);
}

// Clean a text string by removing thinking
string clean(string txt) {
  auto x = txt.lastIndexOf("</think>\n"); return(strip(x >= 0?txt[x + "</think>\n".length .. $]: txt)); 
}

// Try to find the start token of a model
llama_token tokenOf(LlamaModel model, string token = "<|im_start|>") {
  llama_token[] im_start_tokens = model.tokenize(token, false, true);
  return((im_start_tokens.length == 1) ? im_start_tokens[0] : LLAMA_TOKEN_NULL);
}

// Load a model
LlamaModel load(const(char)*[] paths,
                llama_model_params mp = llama_model_default_params(),
                llama_context_params cp = llama_context_default_params(),
                llama_sampler_chain_params sp = llama_sampler_chain_default_params(),
                mtmd_context_params mcp = mtmd_context_params_default(),
                bool verbose = false) {
  if (verbose) writefln("Loading: '%s'", paths.map!fromStringz.join("', '"));
  LlamaModel model = {
    model: check(llama_model_load_from_file(paths[0], mp), "Failed to load model")
  };
  model.ctx = check(llama_init_from_model(model, cp), "Failed to create context");
  model.vocab = check(llama_model_get_vocab(model), "Failed to get vocabulary");
  model.sampler = check(llama_sampler_chain_init(sp), "Failed to initialize sampler");
  model.json = check(llama_sampler_chain_init(sp), "Failed to initialize json sampler");
  if (paths.length > 1) {
    model.vision = check(mtmd_init_from_file(paths[1], model, mcp), "Failed to load vision model");
  }
  return(model);
}

unittest {
  import utils : check;
  check(clean("<think>\nsome thoughts\n</think>\nhello"), "hello", "clean: strips think block");
  check(clean("no think block"), "no think block","clean: passthrough");
  check(clean("<think>\n</think>\n"), "", "clean: empty after think");
  check(clean("before<think>\n</think>\nafter"), "after", "clean: uses lastIndexOf");
}

