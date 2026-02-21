/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.stdio : writefln, writef, writeln, write;

import context : generateTokens, processTokens;
import tools : ToolCall, toolsToJSON, clean, parseToolCalls, executeToolCalls;
import vocab : ChatTemplate;

struct Agent {
  bool verbose = false;
  mtmd_context* ctx_vision;
  mtmd_bitmap*[] pendingBitmaps = [];
}

__gshared Agent agent = Agent();

bool agentStep(llama_context* ctx, ref ChatTemplate tmpl, llama_sampler* sampler,
               ref llama_batch batch, size_t i, ref llama_pos cPos, llama_context_params ctx_params,
               size_t thinkBudget) {
  int nLeft = cast(int)(ctx_params.n_ctx - cPos);
  writefln("\n=== I[%d], cPos %d, n_ctx left: %d ===", i + 1, cPos, nLeft);
  int nGen;
  auto response = generateTokens(ctx, tmpl, sampler, batch, cPos, nGen, nLeft, thinkBudget);
  writeln();

  ToolCall[] toolCalls = response.parseToolCalls();
  if (toolCalls.length == 0) return false;

  llama_memory_seq_rm(llama_get_memory(ctx), 0, cPos - nGen, cPos);
  cPos -= nGen;

  size_t prevLen = tmpl.render(false).length;
  tmpl.add("assistant", response.clean());
  foreach(result; toolCalls.executeToolCalls()) { tmpl.add("tool", result); }
  auto result = tmpl.delta(prevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
  if (agent.verbose) writefln("=== Result ===\n%s===", result);

  if (!processTokens(agent.ctx_vision, ctx, result, agent.pendingBitmaps, cPos, ctx_params.n_batch)) {
    writefln("Error: Failed to process continuation");
    return false;
  }
  agent.pendingBitmaps = [];
  return true;
}