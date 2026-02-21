/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.format : format;

import std.stdio : writefln, writef, writeln, write;

import console : setupConsole;
import context : processTokens, generateTokens;
import model : createContextParams;
import sampler : createSampler;
import tools : ToolCall, toolsToJSON, parseToolCalls, executeToolCalls;
import vocab : ChatTemplate;

import files : g_ctx_vision, pendingBitmaps, readFile;
import tools : clean;

const(char)* LLM_SUMMARY_MODEL = "../LLMs/Qwen3-0.6B.Q4_K_M.gguf";
const(char)* LLM_AGENT_MODEL   = "../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf";
const(char)* LLM_MTMD_MODEL    = "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf";

bool verbose = true;

int main(string[] args) {
  llama_backend_init();
  setupConsole();

  // Load model
  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = -1;
  llama_model* model = llama_model_load_from_file(LLM_AGENT_MODEL, model_params);

  // Load MTMD model
  mtmd_context_params mparams = mtmd_context_params_default();
  mparams.use_gpu = true;
  mparams.n_threads = 4;
  g_ctx_vision = mtmd_init_from_file(LLM_MTMD_MODEL, model, mparams);

  // Get vocab from model
  llama_vocab* vocab = llama_model_get_vocab(model);

  // Create context
  llama_context_params ctx_params = model.createContextParams();
  llama_context* ctx = llama_init_from_model(model, ctx_params);

   // Create sampler
  llama_sampler* sampler = createSampler();

  // Construct system, user, and assistant prompts and generate a full prompt
  size_t thinkBudget = 1024;
  auto system = format(readFile("templates/agent.txt"), toolsToJSON(), thinkBudget);
  auto user = (args[].length > 1)? args[($-1)] : "load the image in data/photo.png";

  auto tmpl = ChatTemplate(vocab, llama_model_chat_template(model, null));
  tmpl.add("system", system);
  tmpl.add("user", user);
  auto prompt = tmpl.render(true) ~ tmpl.thinkBootstrap(thinkBudget); // addAss=true adds assistant prefix
  if (verbose) writefln("=== Prompt ===\n%s===", prompt);

  // Initial position, process prompt to tokens and set in KV cache (add_special = true for BOS)
  llama_pos cPos;
  if (!processTokens(g_ctx_vision, ctx, prompt, [], cPos, ctx_params.n_batch, true)) { 
    writefln("Failed to eval prompt"); return 1;
  }

  // Create a batch and process prompt
  llama_batch batch = llama_batch_init(ctx_params.n_batch, 0, 1);

  // Agent loop
  int maxIterations = 10;
  for (int i = 0; i < maxIterations; i++) {
    int nLeft = cast(int)(ctx_params.n_ctx - cPos);
    writefln("\n=== I[%d], cPos %d, n_ctx left: %d ===", i + 1, cPos, nLeft);
    int nGen;
    auto response = generateTokens(ctx, tmpl, sampler, batch, cPos, nGen, nLeft, thinkBudget);
    writeln();

    // Process tool calls, stop when no tools need to be called anymore
    ToolCall[] toolCalls = response.parseToolCalls();
    if (toolCalls.length == 0) break;

    // Remove model's output (thinking + tool_call) from memory
    llama_memory_seq_rm(llama_get_memory(ctx), 0, cPos - nGen, cPos);
    cPos -= nGen;

    // Add cleaned response (tool_call), Execute tools, Format for LLM, and Tokenize continuation
    size_t prevLen = tmpl.render(false).length;
    tmpl.add("assistant", response.clean());
    foreach(result; toolCalls.executeToolCalls()){ tmpl.add("tool", result); }
    auto result = tmpl.delta(prevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
    if (verbose) writefln("=== Result ===\n%s===", result);

    if (!processTokens(g_ctx_vision, ctx, result, pendingBitmaps, cPos, ctx_params.n_batch)) {
      writefln("Error: Failed to process continuation"); break;
    }
    if (verbose) {
      writefln("=== I[%d], removed %d, generated %d, n_ctx left: %d ===", i + 1, nGen, cPos - (ctx_params.n_ctx - nLeft), ctx_params.n_ctx - cPos);
    }
    pendingBitmaps = [];
  }
  // Cleanup
  llama_batch_free(batch);
  llama_sampler_free(sampler);
  llama_free(ctx);
  llama_model_free(model);
  llama_backend_free();
  return(0);
}

