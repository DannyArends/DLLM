/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

// Create context
llama_context_params createContextParams(llama_model* model, uint n_ctx = 16384, uint n_batch = 2048, uint n_threads = 8) {
  llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = n_ctx;
  ctx_params.n_batch = n_batch;
  ctx_params.n_threads = n_threads;
  ctx_params.type_k = GGML_TYPE_Q8_0;
  ctx_params.type_v = GGML_TYPE_Q8_0;
  ctx_params.offload_kqv = true;
  ctx_params.no_perf = true;
  ctx_params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;
  return(ctx_params);
}
