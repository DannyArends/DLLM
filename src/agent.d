/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import model : clean, detokenize, LlamaModel, startToken, tokenize;
import tools : ToolCall, executeTool;
import rag : RAG;

struct Agent {
  LlamaModel model;
  const(char)* chat;
  llama_chat_message[] history;
  mtmd_bitmap*[] bitmaps;
  string[] tmp;
  llama_pos kvPos = 0;
  llama_pos promptPos = 0;
  RAG rag;
  bool running = true;
  bool verbose = false;
  alias model this;
}

__gshared Agent agent = Agent(); /// Global agent (Should only be used by tools)

void free(ref Agent agent) { foreach(file; agent.tmp) { if(file.exists()){ file.remove(); } } }

// Generate a full prompt addition
string prompt(ref Agent agent, bool addAssistant = true) {
  int n0 = llama_chat_apply_template(agent.chat, agent.history.ptr, agent.history.length, false, null, 0);
  int n1 = llama_chat_apply_template(agent.chat, agent.history.ptr, agent.history.length, true, null, 0);
  int n = addAssistant? n1 : n0;
  char[] buf = new char[n];
  llama_chat_apply_template(agent.chat, agent.history.ptr, agent.history.length, addAssistant, buf.ptr, n);
  string prompt = buf.idup;
  if(agent.verbose) writefln("===\n%s===", prompt);
//  prompt = format("%s\n%s", prompt[agent.promptPos .. n], "<think>\nBudget: 512 tokens. Be concise.\n");
  prompt = format("%s", prompt[agent.promptPos .. n]);
  agent.promptPos = n0;
  return(prompt);
}

// Process text (with optional images) and eval into KV cache, updating kvPos
bool process(ref Agent agent, string text, bool add = true, bool parse = true) {
  mtmd_input_chunks* chunks = mtmd_input_chunks_init();
  scope(exit) mtmd_input_chunks_free(chunks);

  if(agent.verbose) writefln("[DEBUG] %d bmps, text contains %d markers", agent.bitmaps.length, text.count("<__media__>"));

  // Tokenize text & Images
  mtmd_input_text input = { text: text.toStringz(), add_special: add, parse_special: parse };
  mtmd_tokenize(agent.vision, chunks, &input, agent.bitmaps.ptr, agent.bitmaps.length);

  // Evaluate into KV cache
  auto r = mtmd_helper_eval_chunks(agent.vision, agent.ctx, chunks, agent.kvPos, 0, llama_n_batch(agent.ctx), true, &agent.kvPos);
  if(agent.verbose) writefln("Number of tokens: %d / %d, kvPos: %d", chunks.nTokens, llama_n_ctx(agent.ctx), agent.kvPos);

  agent.bitmaps = [];
  return(r == 0);
}

// Add non-thinking part of the response to history and clean KV cache by removing all generated output
string clean(ref Agent agent, llama_token[] tokens) {
  auto noThink = agent.detokenize(tokens).clean();
  agent.history ~= llama_chat_message(toStringz("assistant"), toStringz(noThink));

  llama_memory_seq_rm(llama_get_memory(agent.ctx), 0, cast(int)(agent.kvPos - tokens.length), agent.kvPos);
  agent.kvPos =  cast(int)(agent.kvPos - tokens.length);
  if(agent.verbose) writefln("Removed %d tokens, kvPos: %d", tokens.length, agent.kvPos);

  return(noThink);
}

// Execute all tool calls and format responses
string execute(ref Agent agent, const ToolCall[] calls) {
  auto txt = appender!string;
  foreach(i, call; calls) {
    string toolResult = executeTool(call.name, call.arguments);
    auto response = JSONValue(["tool": JSONValue(call.name), "args": JSONValue(call.arguments), "result": JSONValue(toolResult)]);
    txt ~= response.toString();
  }
  return(txt.data);
}

// Generate a reponse
llama_token[] generate(ref Agent agent, bool verbose = true) {
  llama_batch batch = llama_batch_init(llama_n_batch(agent.ctx), 0, 1);
  scope(exit) llama_batch_free(batch);

  llama_token im_start = agent.startToken();

  llama_token[] response;
  char[256] buf = 0;
  size_t i = 0;

  for (i = 0; i < (llama_n_ctx(agent.ctx) - agent.kvPos); i++) {
    auto token = llama_sampler_sample(agent.sampler, agent.ctx, -1);
    if (llama_vocab_is_eog(agent.vocab, token)){ break; }
    if (im_start != LLAMA_TOKEN_NULL && token == im_start){ continue; }
    response ~= token;

    if (verbose) {
      int n = llama_token_to_piece(agent.vocab, token, buf.ptr, buf.sizeof, 0, true);
      if (n > 0) { write(cast(string)buf[0..n]); stdout.fflush(); }
    }

    batch.token[0] = token;  batch.pos[0] = agent.kvPos + cast(int)i;
    batch.logits[0] = 1;     batch.n_tokens = 1;
    batch.n_seq_id[0] = 1;   batch.seq_id[0][0] = 0;
    if (llama_decode(agent.ctx, batch) != 0) break;
  }
  if (verbose) { write('\n'); stdout.fflush(); }
  agent.kvPos += i;
  return(response);
}
