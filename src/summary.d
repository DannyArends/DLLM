/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.algorithm : min;
import std.array : appender, join;
import std.stdio : writefln, writeln;

import agent : agent;
import context : generateTokens, processTokens;
import model : LlamaModel;
import sampler : createSampler;
import tools : clean;
import vocab : ChatTemplate, tokenize, detokenize;

// Summarize a sliding window 'chunk'
string summarizeChunk(LlamaModel m, const(char)* tmplStr, string chunk, int responseBudget) {
  auto tmpl = ChatTemplate(m, tmplStr);
  tmpl.add("system", "You are a precise information extractor. Extract and preserve all facts, entities, names, numbers, relationships, and key details. Do not omit specifics.");
  tmpl.add("user", "Extract all key information from:\n" ~ chunk);
  llama_memory_clear(llama_get_memory(m), true);
  llama_pos cPos;
  if (!m.processTokens(tmpl.render(true) ~ tmpl.noThinkBootstrap(), cPos, true)) return "";
  llama_batch batch = llama_batch_init(m.llama_n_batch(), 0, 1);
  scope(exit) llama_batch_free(batch);
  int nGen;
  return(clean(m.generateTokens(tmpl, batch, cPos, nGen, responseBudget, 0, false)));
}

// Recursive summarize function
string summarize(LlamaModel m, string text) {
  writeln("[Summarizing]");
  llama_memory_clear(llama_get_memory(m), true);
  auto tmplStr = llama_model_chat_template(m.model, null);

  llama_token[] allTokens = m.tokenize(text, false);
  size_t PROMPT_OVERHEAD = 256;
  size_t RESPONSE_BUDGET = cast(int)min(allTokens.length / 4, 1024);
  size_t windowTokens = m.llama_n_ctx() - PROMPT_OVERHEAD - RESPONSE_BUDGET;

  if (allTokens.length <= windowTokens)
    return m.summarizeChunk(tmplStr, text, cast(int)RESPONSE_BUDGET);

  size_t overlap = windowTokens / 10;
  size_t step    = windowTokens - overlap;
  string[] partials;
  for (size_t i = 0; i < allTokens.length; i += step) {
    size_t end = (i + windowTokens < allTokens.length) ? i + windowTokens : allTokens.length;
    auto partial = m.summarizeChunk(tmplStr, m.detokenize(allTokens[i..end]), cast(int)RESPONSE_BUDGET);
    if (partial.length > 0) partials ~= partial;
  }

  string joined = partials.join("\n");
  llama_token[] joinedTokens = m.tokenize(joined, false);
  if (joinedTokens.length >= allTokens.length) {
    writefln("[WARN] Summarize: no progress, truncating to fit context");
    return(m.detokenize(joinedTokens[$-min(joinedTokens.length, windowTokens)..$]));
  }
  return m.summarize(joined);
}
