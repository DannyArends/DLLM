/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : appender;
import std.format : format;
import std.stdio : writefln, writef, writeln, write;

import files : listDirectory;

import console : setupConsole;
import context : processTokens;
import model : createContextParams;
import sampler : createSampler;
import tools : ToolCall, toolsToJSON, parseToolCalls, executeToolCalls;
import vocab : tokenize, assistantFmt, toolResponseFmt;

const(char)* LLM_SUMMARY_MODEL = "../LLMs/Qwen3-0.6B.Q4_K_M.gguf";
const(char)* LLM_AGENT_MODEL = "../LLMs/Qwen3-4B-Thinking.Q4_K_M.gguf";
bool verbose = true;

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
  llama_sampler* sampler = createSampler();

  // Construct and tokenize prompt
  string prompt = format(assistantFmt, toolsToJSON(), "What is your name?");
  if (args[].length > 1) prompt = format(assistantFmt, toolsToJSON(), args[($-1)]);
  if (verbose) writefln("=== Prompt ===\n%s\n===", prompt);
  llama_token[] tokens = vocab.tokenize(prompt);

  // Create a batch and process prompt
  llama_batch batch = llama_batch_init(ctx_params.n_batch, 0, 1);
  if (!ctx.processTokens(batch, tokens, cast(int)ctx_params.n_batch)) { writefln("Failed to decode"); return 1; }

  // Agent loop
  int maxIterations = 10;
  int cPos = cast(int)tokens.length;
  for (int iteration = 0; iteration < maxIterations; iteration++) {
    int nLeft = cast(int)(ctx_params.n_ctx - cPos);
    writefln("\n=== I[%d], n_ctx left: %d ===", iteration + 1, nLeft);
    auto response = appender!string;

    // Generate tokens
    char[256] buf = 0;
    int tGen = 0;
    for (int i = 0; i < nLeft; i++) {
      llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

      // End of generation token & other control tokens
      if (llama_vocab_is_eog(vocab, new_token)) break;
      if (llama_vocab_get_attr(vocab, new_token) & LLAMA_TOKEN_ATTR_CONTROL) continue;

      // Decode the generated tokenid to text
      int n = llama_token_to_piece(vocab, new_token, buf.ptr, buf.sizeof, 0, true);
      if (n > 0) { 
        string tokenText = format("%s", cast(string)buf[0..n]);
        write(tokenText);
        response ~= tokenText;
      }

      // Prepare next batch
      batch.token[0] = new_token;
      batch.pos[0] = cPos + i;
      batch.logits[0] = 1;
      batch.n_tokens = 1;

      if (llama_decode(ctx, batch) != 0) break;
      tGen++;
    }
    cPos += tGen;
    writeln();
    // Process tool calls, stop when no tools need to be called anymore
    ToolCall[] toolCalls = parseToolCalls(response.data);
    if (toolCalls.length == 0) break;

    // Remove model's output (thinking + tool_call) from memory
    llama_memory_t mem = llama_get_memory(ctx);
    llama_memory_seq_rm(mem, 0, cPos - tGen, cPos);
    cPos -= tGen;

    // Execute tools, Format for LLM, and Tokenize continuation
    auto result = toolResponseFmt.format(toolCalls.executeToolCalls());
    llama_token[] contTokens = vocab.tokenize(result);

    auto left = cast(int)(ctx_params.n_ctx - cPos + contTokens.length);
    if (verbose) writefln("=== I[%d], removed %d, generated %d, n_ctx left: %d ===", iteration + 1, tGen, contTokens.length, left);
    if (left <= 0) { writeln("Error: Out Of Context"); break; }

    // Process continuation
    if (!ctx.processTokens(batch, contTokens, cast(int)ctx_params.n_batch, cPos)) {
      writefln("Error: Failed to process continuation");
      break;
    }
    cPos += cast(int)contTokens.length; // Update current position
  }
  // Cleanup
  llama_batch_free(batch);
  llama_sampler_free(sampler);
  llama_free(ctx);
  llama_model_free(model);
  llama_backend_free();
  return(0);
}
