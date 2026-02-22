/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.algorithm : min;
import std.array : appender, join;
import std.stdio : writefln;

import agent : agent;
import context : generateTokens, processTokens;
import model : createContextParams, loadLlamaModel;
import sampler : createSampler;
import tools : clean;
import utils : checkNotNull;
import vocab : ChatTemplate, tokenize, detokenize;

// Main summary function, loads model, creates context and call the recursive summarize function
string summarize(string text, size_t n_ctx = 2048) {
  llama_model* model = loadLlamaModel(agent.LLM_SUMMARY_MODEL).checkNotNull("Failed to load summary model");
  scope(exit){ llama_model_free(model); }

  llama_context_params ctx_params = model.createContextParams(n_ctx);
  llama_context* ctx = llama_init_from_model(model, ctx_params).checkNotNull("Failed to create summary context");
  scope(exit){ llama_free(ctx); }

  llama_sampler* sampler = createSampler(0.3f);   // Lower temperature for more factual summaries
  scope(exit) llama_sampler_free(sampler);

  auto vocab = llama_model_get_vocab(model);
  auto tmplStr = llama_model_chat_template(model, null);
  return(summarize(ctx, sampler, vocab, tmplStr, text, n_ctx));
}

// Summarize a sliding window 'chunk'
string summarizeChunk(llama_context* ctx, llama_sampler* sampler, llama_vocab* vocab, const(char)* tmplStr, string chunk, int responseBudget) {
  auto tmpl = ChatTemplate(vocab, tmplStr);
  tmpl.add("system", "You are a precise information extractor. Extract and preserve all facts, entities, names, numbers, relationships, and key details. Do not omit specifics.");
  tmpl.add("user", "Extract all key information from:\n" ~ chunk);
  llama_memory_clear(llama_get_memory(ctx), true);
  llama_pos cPos;
  if (!ctx.processTokens(tmpl.render(true) ~ tmpl.noThinkBootstrap(), cPos, true)) return "";
  llama_batch batch = llama_batch_init(ctx.llama_n_batch(), 0, 1);
  scope(exit) llama_batch_free(batch);
  int nGen;
  return(clean(ctx.generateTokens(tmpl, sampler, batch, cPos, nGen, responseBudget, 0, false)));
}

// Recursive summarize function
string summarize(llama_context* ctx, llama_sampler* sampler, llama_vocab* vocab, const(char)* tmplStr, string text, size_t n_ctx) {
  llama_token[] allTokens = tokenize(vocab, text, false);
  size_t PROMPT_OVERHEAD = 256;
  size_t RESPONSE_BUDGET = cast(int)min(allTokens.length / 4, 1024);
  size_t windowTokens = n_ctx - PROMPT_OVERHEAD - RESPONSE_BUDGET;

  if (allTokens.length <= windowTokens)
    return summarizeChunk(ctx, sampler, vocab, tmplStr, text, cast(int)RESPONSE_BUDGET);

  size_t overlap = windowTokens / 10;
  size_t step    = windowTokens - overlap;
  string[] partials;
  for (size_t i = 0; i < allTokens.length; i += step) {
    size_t end = (i + windowTokens < allTokens.length) ? i + windowTokens : allTokens.length;
    auto partial = summarizeChunk(ctx, sampler, vocab, tmplStr, detokenize(vocab, allTokens[i..end]), cast(int)RESPONSE_BUDGET);
    if (partial.length > 0) partials ~= partial;
  }

  string joined = partials.join("\n");
  llama_token[] joinedTokens = tokenize(vocab, joined, false);
  if (joinedTokens.length >= allTokens.length) {
    writefln("[WARN] Summarize: no progress, truncating to fit context");
    return detokenize(vocab, joinedTokens[$-min(joinedTokens.length, windowTokens)..$]);
  }
  return summarize(ctx, sampler, vocab, tmplStr, joined, n_ctx);
}
