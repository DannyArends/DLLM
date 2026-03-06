/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import agent : Agent, clear;
import model : clean, LlamaModel, tokenize, detokenize;

struct Summary {
  LlamaModel model;               /// Model pointer
  const(char)* chat;              /// Chat template for this model
  llama_pos kvPos = 0;            /// KV cache position
  alias model this;
}

// Summarize a slice of chat history into a single condensed string.
// Uses the summary model's own chat template and context.
// Clears the summary model KV before and after to avoid state leakage.
string summarize(ref Summary summary, llama_chat_message[] history) {
  summary.clear();
  scope(exit) summary.clear();

  // Flatten history into plain text for the summarization prompt
  auto msgs = appender!string;
  foreach (msg; history) {
    if (fromStringz(msg.role) == "tool") continue;  // skip tool results
    msgs ~= format("[%s]: %s\n", fromStringz(msg.role), fromStringz(msg.content));
  }

  llama_chat_message[] msgHistory = [
    llama_chat_message(toStringz("system"), toStringz(readText("templates/summary.txt"))),
    llama_chat_message(toStringz("user"), toStringz(msgs.data))
  ];

  // Apply the summary model's own chat template
  int n = llama_chat_apply_template(summary.chat, msgHistory.ptr, msgHistory.length, true, null, 0);
  char[] buf = new char[n];
  llama_chat_apply_template(summary.chat, msgHistory.ptr, msgHistory.length, true, buf.ptr, n);

  summary.process(buf.idup, false, false);
  return summary.detokenize(summary.generate()).clean();
}

// Tokenize and eval text into the summary model KV cache
bool process(ref Summary summary, string text, bool add = true, bool parse = true) {
  auto tokens = summary.tokenize(text, add, parse);
  if (tokens.length == 0) return true;

  int n_batch = llama_n_batch(summary.ctx);
  llama_batch batch = llama_batch_init(n_batch, 0, 1);
  scope(exit) llama_batch_free(batch);

  int offset = 0;
  while (offset < cast(int)tokens.length) {
    int chunk = cast(int)tokens.length - offset;
    if (chunk > n_batch) chunk = n_batch;

    for (int i = 0; i < chunk; i++) {
      batch.token[i]      = tokens[offset + i];
      batch.pos[i]        = summary.kvPos + offset + i;
      batch.n_seq_id[i]   = 1;
      batch.seq_id[i][0]  = 0;
      batch.logits[i]     = (offset + i == cast(int)tokens.length - 1) ? 1 : 0;
    }
    batch.n_tokens = chunk;
    if (llama_decode(summary.ctx, batch) != 0) return false;
    offset += chunk;
  }
  summary.kvPos += cast(llama_pos)tokens.length;
  return true;
}

// Generate tokens from the summary model
llama_token[] generate(ref Summary summary) {
  llama_batch batch = llama_batch_init(1, 0, 1);
  scope(exit) llama_batch_free(batch);

  llama_token[] response;
  for (size_t i = 0; i < (llama_n_ctx(summary.ctx) - summary.kvPos); i++) {
    auto token = llama_sampler_sample(summary.sampler, summary.ctx, -1);
    if (llama_vocab_is_eog(summary.vocab, token)) break;
    response ~= token;

    batch.token[0]     = token;
    batch.pos[0]       = summary.kvPos + cast(int)response.length;
    batch.logits[0]    = 1;
    batch.n_tokens     = 1;
    batch.n_seq_id[0]  = 1;
    batch.seq_id[0][0] = 0;
    if (llama_decode(summary.ctx, batch) != 0) break;
  }
  summary.kvPos += cast(llama_pos)response.length;
  return response;
}

