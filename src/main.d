import core.stdc.stdlib;
import core.stdc.string;
import std.stdio;
import std.format;
import std.string;
import includes;

extern(Windows) uint SetConsoleOutputCP(uint wCodePageID);
extern(C) void silent_log(ggml_log_level level, const char* text, void* user_data) { }

int main(){
  SetConsoleOutputCP(65001);

  llama_backend_init();
  llama_log_set(&silent_log, null);

  // Load model
  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = -1;
  llama_model* model = llama_model_load_from_file("C:/Github/LLMs/Qwen3-0.6B.Q4_K_M.gguf", model_params);

  // Get vocab from model
  llama_vocab* vocab = llama_model_get_vocab(model);
  const char* stop_str = "<|im_end|>";

  // Create context
  llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = 2048;
  ctx_params.n_batch = 512;
  ctx_params.n_threads = 8;
  ctx_params.type_k = GGML_TYPE_Q8_0;
  ctx_params.type_v = GGML_TYPE_Q8_0;
  ctx_params.offload_kqv = true;
  ctx_params.no_perf = true;
  ctx_params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;
  llama_context* ctx = llama_init_from_model(model, ctx_params);

   // Create sampler
  llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8));
  llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  // Tokenize prompt
  const char* prompt = "<|im_start|>system\nYou are a helpful assistant named Bob\n<|im_end|>\n<|im_start|>user\nWhat is your name?\n<|im_end|>\n<|im_start|>assistant\n\0";
  int n_tokens = -llama_tokenize(vocab, prompt, cast(int)strlen(prompt), null, 0, true, true);
  llama_token* tokens = cast(llama_token*)malloc(n_tokens * llama_token.sizeof);
  llama_tokenize(vocab, prompt, cast(int)strlen(prompt), tokens, n_tokens, true, true);

  // Process prompt
  llama_batch batch = llama_batch_init(512, 0, 1);

  // Fill batch with prompt tokens
  for (int i = 0; i < n_tokens; i++) {
    batch.token[i] = tokens[i];
    batch.pos[i] = i;
    batch.n_seq_id[i] = 1;
    batch.seq_id[i][0] = 0;
    batch.logits[i] = 0;
  }
  batch.n_tokens = n_tokens;
  batch.logits[n_tokens - 1] = 1;

  if (llama_decode(ctx, batch) != 0) { writeln("Failed to decode\n"); return 1; }
  int n_gen = cast(int)ctx_params.n_ctx - n_tokens;

  // Generate tokens
  char[256] buf = 0;
  for (int t = 0; t < n_gen; t++) {
    llama_token new_token = llama_sampler_sample(sampler, ctx, -1);
    if (llama_vocab_is_eog(vocab, new_token)) break;
    if (llama_vocab_get_attr(vocab, new_token) & LLAMA_TOKEN_ATTR_CONTROL) continue;

    int n = llama_token_to_piece(vocab, new_token, buf.ptr, buf.sizeof, 0, true);
    if (n > 0) { write(format("%s", buf[0..n])); }

    // Prepare next batch
    batch.token[0] = new_token;
    batch.pos[0] = n_tokens + t;
    batch.logits[0] = 1;
    batch.n_tokens = 1;

    if (llama_decode(ctx, batch) != 0) break;
  }

  // Cleanup
  llama_sampler_free(sampler);
  free(tokens);
  llama_batch_free(batch);
  llama_free(ctx);
  llama_model_free(model);
  llama_backend_free();
  return(0);
}