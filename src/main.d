import std.stdio : writefln, writef;
import std.format;

import includes;
import console : setupConsole;
import context : processTokens;
import model : createContextParams;
import vocab : tokenizePrompt, assistantFmt;

const(char)* LLM_SUMMARY_MODEL = "C:/Github/LLMs/Qwen3-0.6B.Q4_K_M.gguf";
const(char)* LLM_AGENT_MODEL = "C:/Github/LLMs/Qwen3-4B-Thinking.Q4_K_M.gguf";

int main(string[] args) {
  llama_backend_init();
  setupConsole();

  // Load model
  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = -1;
  llama_model* model = llama_model_load_from_file(LLM_AGENT_MODEL, model_params);

  // Get vocab from model
  llama_vocab* vocab = llama_model_get_vocab(model);

  // Create context
  llama_context_params ctx_params = model.createContextParams();
  llama_context* ctx = llama_init_from_model(model, ctx_params);

   // Create sampler
  llama_sampler* sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.1));
  llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95, 1));
  llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05, 1));
  llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40));
  llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  // Tokenize prompt
  string prompt = format(assistantFmt, "What is your name?");
  if(args[].length > 1) prompt = format(assistantFmt, args[($-1)]);
  llama_token[] tokens = vocab.tokenizePrompt(prompt);

  // Process prompt
  llama_batch batch = llama_batch_init(ctx_params.n_batch, 0, 1);
  if (!ctx.processTokens(batch, tokens, cast(int)ctx_params.n_batch)) { writefln("Failed to decode"); return 1; }

  int n_gen = cast(int)(ctx_params.n_ctx - tokens.length);

  // Generate tokens
  char[256] buf = 0;
  for (int g = 0; g < n_gen; g++) {
    llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

    // End of generation token & other control tokens
    if (llama_vocab_is_eog(vocab, new_token)) break;
    if (llama_vocab_get_attr(vocab, new_token) & LLAMA_TOKEN_ATTR_CONTROL) continue;

    // Decode the generated tokenid to text
    int n = llama_token_to_piece(vocab, new_token, buf.ptr, buf.sizeof, 0, true);
    if (n > 0) { writef("%s", buf[0..n]); }

    // Prepare next batch
    batch.token[0] = new_token;
    batch.pos[0] = cast(int)(tokens.length) + g;
    batch.logits[0] = 1;
    batch.n_tokens = 1;

    if (llama_decode(ctx, batch) != 0) break;
  }

  // Cleanup
  llama_batch_free(batch);
  llama_sampler_free(sampler);
  llama_free(ctx);
  llama_model_free(model);
  llama_backend_free();
  return(0);
}
