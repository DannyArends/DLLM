/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

struct LlamaModel {
  llama_model* model = null;
  llama_context* ctx = null;
  llama_vocab* vocab = null;
  llama_sampler* sampler = null;
  mtmd_context* vision = null;
  alias model this;
}

void free(ref LlamaModel model) {
  if (model.vision) { mtmd_free(model.vision); model.vision = null; }
  if (model.sampler) { llama_sampler_free(model.sampler);  model.sampler = null; }
  if (model.ctx) { llama_free(model.ctx); model.ctx = null; }
  if (model.model) { llama_model_free(model.model); model.model = null; }
}

llama_model_params mp() { llama_model_params mp = llama_model_default_params(); mp.n_gpu_layers = -1; return(mp); }
llama_context_params cp() {
  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = 2 * 8192; cp.n_batch = 512; cp.type_k = GGML_TYPE_Q8_0; cp.type_v = GGML_TYPE_Q8_0;
  cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED; cp.offload_kqv = true; cp.no_perf = true;
  return(cp);
}

llama_context_params cpe() {
  llama_context_params cp = llama_context_default_params();
  cp.embeddings = true; cp.pooling_type = LLAMA_POOLING_TYPE_CLS;
  cp.n_ctx = 256; cp.n_batch = 256; cp.type_k = GGML_TYPE_Q8_0; cp.type_v = GGML_TYPE_Q8_0;
  cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED; cp.offload_kqv = true; cp.no_perf = true;
  return(cp);
}

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
llama_token startToken(LlamaModel model) {
  llama_token[] im_start_tokens = model.tokenize("<|im_start|>", false, true);
  return((im_start_tokens.length == 1) ? im_start_tokens[0] : LLAMA_TOKEN_NULL);
}

// Load a model
LlamaModel load(const(char)*[] paths,
                llama_model_params mp = llama_model_default_params(),
                llama_context_params cp = llama_context_default_params(),
                llama_sampler_chain_params sp = llama_sampler_chain_default_params(),
                mtmd_context_params mcp = mtmd_context_params_default()) {
  LlamaModel model = {
    model: check(llama_model_load_from_file(paths[0], mp), "Failed to load model")
  };
  model.ctx = check(llama_init_from_model(model, cp), "Failed to create context");
  model.vocab = check(llama_model_get_vocab(model), "Failed to get vocabulary");
  model.sampler = check(llama_sampler_chain_init(sp), "Failed to initialize sampler");
  if (paths.length > 1) {
    model.vision = check(mtmd_init_from_file(paths[1], model, mcp), "Failed to load vision model");
  }
  return(model);
}
