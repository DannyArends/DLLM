/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : appender, join;
import std.stdio : writefln, writeln, write;
import std.string : fromStringz;

import context : generateTokens, processTokens;
import tools : ToolCall, toolsToJSON, clean, parseToolCalls, executeToolCalls;
import vocab : ChatTemplate, tokenize;
import summary : summarize;
import rag : RAG;

struct Agent {
  /// Several model paths that are used by the Agent (Embeddings, Agent, MTMD, and Summary)
  const(char)* LLM_EMBED_MODEL    = "../LLMs/nomic-embed-text-v1.5.Q4_K_M.gguf";
  const(char)* LLM_AGENT_MODEL    = "../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf";
  const(char)* LLM_MTMD_MODEL     = "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf";
  const(char)* LLM_SUMMARY_MODEL  = "../LLMs/Qwen3-0.6B.Q4_K_M.gguf";

  bool verbose = false;                   /// Verbosity
  mtmd_context* vision;                   /// Vision context
  RAG rag = void;                         /// RAG
  mtmd_bitmap*[] pendingBitmaps = [];     /// Images to upload in KV
}

__gshared Agent agent = Agent();          /// Global agent

// A single step in the agent: token generation for thinking and response
bool agentStep(llama_context* ctx, ref ChatTemplate tmpl, llama_sampler* sampler,
               ref llama_batch batch, size_t i, ref llama_pos cPos, size_t thinkBudget) {
  int nLeft = cast(int)(ctx.llama_n_ctx() - cPos);
  if (nLeft <= 0) {
    if (!compressHistory(ctx, tmpl, cPos, thinkBudget)) return(false);
    nLeft = cast(int)(ctx.llama_n_ctx() - cPos);
  }
  if (agent.verbose) writefln("\n=== I[%d], cPos %d, n_ctx left: %d ===", i + 1, cPos, nLeft);
  int nGen;
  auto response = ctx.generateTokens(tmpl, sampler, batch, cPos, nGen, nLeft, thinkBudget);
  writeln(); // Should we a memory compacting trigger here ?

  ToolCall[] toolCalls = response.parseToolCalls();
  if (toolCalls.length == 0) return false;

  llama_memory_seq_rm(ctx.llama_get_memory(), 0, cPos - nGen, cPos);
  cPos -= nGen;

  size_t prevLen = tmpl.render(false).length;
  auto cleaned = response.clean();
  tmpl.add("assistant", cleaned);

  int remainingCtx;
  auto vocab = llama_model_get_vocab(llama_get_model(ctx));

  foreach (result; toolCalls.executeToolCalls()) {
    remainingCtx = cast(int)(ctx.llama_n_ctx() - cPos);
    llama_token[] resultTokens = tokenize(vocab, result, false);
    if (cast(int)resultTokens.length > remainingCtx) {
        string shortened = summarize(result);
        tmpl.add("tool", shortened.length > 0 ? shortened : "[Tool output too large, summarization failed]");
    } else {
        tmpl.add("tool", result);
    }
  }
  auto result = tmpl.delta(prevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
  if (agent.verbose) writefln("=== Result ===\n%s===", result);

  if (!ctx.processTokens(agent.vision, result, agent.pendingBitmaps, cPos)) {
   writefln("[WARN] Continuation tokens overflow — compressing and retrying...");
    if (!compressHistory(ctx, tmpl, cPos, thinkBudget)) return false;

    // Retry with fresh context
    auto retryResult = tmpl.delta(tmpl.render(false).length, true) ~ tmpl.thinkBootstrap(thinkBudget);
    if (!ctx.processTokens(agent.vision, retryResult, agent.pendingBitmaps, cPos)) {
      writefln("[ERROR] Failed even after compression");
      return(false);
    }
  }
  agent.pendingBitmaps = [];
  return(true);
}

// Summarize conversation history down to system + summary, rebuild KV cache
bool compressHistory(llama_context* ctx, ref ChatTemplate tmpl, ref llama_pos cPos, size_t thinkBudget) {
  writefln("[WARN] Context overflow — compressing conversation history...");

  // Collect all non-system messages into one text blob
  auto blob = appender!string;
  foreach (msg; tmpl.messages[1..$]) {  // skip system
    blob ~= fromStringz(msg.role) ~ ": " ~ fromStringz(msg.content) ~ "\n";
  }

  string summary = summarize(blob.data); // Summarize the blob
  if (summary.length == 0) { writefln("[ERROR] compressHistory: summarize() returned empty"); return false; }

  // Rebuild tmpl: keep system, replace rest with summary
  tmpl.messages = tmpl.messages[0..1];
  tmpl.add("user", "[Previous conversation has been summarized]");
  tmpl.add("assistant", summary);

  // Rebuild KV cache from scratch
  llama_memory_clear(llama_get_memory(ctx), true);
  cPos = 0;
  auto prompt = tmpl.render(true) ~ tmpl.thinkBootstrap(thinkBudget);
  if (!ctx.processTokens(agent.vision, prompt, [], cPos, true)) {
    writefln("[ERROR] Failed to process compressed history");
    return(false);
  }
  writefln("[INFO] History compressed, cPos now %d", cPos);
  return(true);
}
