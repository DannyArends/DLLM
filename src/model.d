/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.string : toStringz;

import utils : checkNotNull;

struct LlamaBase {
  llama_model* model = null;
  llama_context* ctx = null;
  llama_vocab* vocab = null;
  alias ctx this;
}

struct LlamaModel {
  LlamaBase base;
  llama_sampler* sampler = null;
  mtmd_context* vision = null;
  alias base this;
}

enum M { agent = 0, summary = 1, embed = 2 }

immutable string[][] MODEL_PATHS = [
  M.agent:   ["../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf", "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf"],
  M.summary: ["../LLMs/Qwen3-0.6B.Q4_K_M.gguf"],
  M.embed:   ["../LLMs/nomic-embed-text-v1.5.Q4_K_M.gguf"],
];

enum int nModels = __traits(allMembers, M).length;

void free(ref LlamaModel m) {
  if (m.vision) { mtmd_free(m.vision); m.vision = null; }
  if (m.sampler) { llama_sampler_free(m.sampler);  m.sampler = null; }
  if (m.ctx) { llama_free(m.ctx); m.ctx = null; }
  if (m.model) { llama_model_free(m.model); m.model = null; }
}

// Create context
llama_context_params createCtxParams(llama_model* model, size_t n_ctx = 4096, 
                                     size_t n_batch = 1024, size_t n_ubatch = 1024, 
                                     size_t n_threads = 8, bool embeddings = false) {
  llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = cast(uint)n_ctx;
  ctx_params.n_batch = cast(uint)n_batch;
  ctx_params.n_ubatch = cast(uint)n_ubatch;
  ctx_params.n_threads = cast(uint)n_threads;
  ctx_params.embeddings = embeddings;
  if (embeddings) ctx_params.pooling_type = LLAMA_POOLING_TYPE_MEAN;
  ctx_params.type_k = GGML_TYPE_Q8_0;
  ctx_params.type_v = GGML_TYPE_Q8_0;
  ctx_params.offload_kqv = true;
  ctx_params.no_perf = true;
  ctx_params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;
  return(ctx_params);
}

// Load a LMM
LlamaModel loadModel(immutable(string[]) paths, size_t n_ctx = 4096, 
                     size_t n_batch = 1024, size_t n_ubatch = 1024, 
                     size_t n_threads = 8, bool embeddings = false) {
  LlamaModel m;
  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = -1;
  m.model = llama_model_load_from_file(toStringz(paths[0]), model_params).checkNotNull("Failed to load model");
  m.vocab = llama_model_get_vocab(m.model);
  llama_context_params p = m.model.createCtxParams(n_ctx, n_batch, n_ubatch, n_threads, embeddings);
  m.ctx = llama_init_from_model(m.model, p).checkNotNull("Failed to create context");
  if (paths.length > 1) {
    mtmd_context_params mparams = mtmd_context_params_default();
    mparams.use_gpu   = true;
    mparams.n_threads = 4;
    m.vision = mtmd_init_from_file(toStringz(paths[1]), m.model, mparams).checkNotNull("Failed to load vision model");
  }
  return m;
}

