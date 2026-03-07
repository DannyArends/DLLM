/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import model : clean, detokenize, LlamaModel, tokenOf, tokenize;
import rag : RAG;
import summary : Summary, summarize;
import tools : ToolCall, executeTool;

struct Agent {
  LlamaModel model;               /// LlamaModel used for the Agent
  const(char)* chat;              /// Chat template
  llama_chat_message[] history;   /// Message history
  mtmd_bitmap*[] bitmaps;         /// Bitmaps loaded for the current process()
  string[] tmp;                   /// List of tmp files to be cleaned on exit
  llama_pos kvPos = 0;            /// Current Key-Value cache position (in tokens)
  RAG rag;                        /// Retrieval-Augmented Generation model
  Summary summary;                /// Summary model
  bool running = true;            /// Is the agent running (false = OneShot)
  bool verbose = false;           /// verbose output
  alias model this;
}
/// Global agent singleton — NOT thread-safe, only for use within tool callbacks
__gshared Agent agent = Agent();

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
  if(addAssistant) prompt ~= "<think>\nBudget: 2048 tokens\n";
  return(prompt);
}

// Condense history when KV pressure exceeds threshold. Returns true if condensed.
bool condense(ref Agent agent, float threshold = 0.60f, size_t keepTurns = 4) {
  if (agent.kvPos < cast(size_t)(llama_n_ctx(agent.ctx) * threshold)) return false;

  writeln("[condense] KV pressure, summarizing history...");
  auto sysMsg = agent.history[0];
  auto tail = agent.history.length > keepTurns ? agent.history[$ - keepTurns .. $] : [];
  auto head = agent.history.length > keepTurns ? agent.history[1 .. $ - keepTurns] : agent.history[1 .. $];
  auto summary = agent.summary.summarize(head);
  agent.history = [sysMsg, llama_chat_message(toStringz("assistant"), toStringz(summary))] ~ tail;
  writefln("[condense] Done. ~%d chars.", summary.length);
  return true;
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

  foreach (ref msg; agent.history) {
    msg.content = toStringz(fromStringz(msg.content).replace("<__media__>", "[media]"));
  }
  agent.bitmaps = [];
  return(r == 0);
}

// Add non-thinking part of the response to history
string clean(ref Agent agent, llama_token[] tokens) {
  auto noThink = agent.detokenize(tokens).clean();
  agent.history ~= llama_chat_message(toStringz("assistant"), toStringz(noThink));
  return(noThink);
}

// Clear the KV-cache
void clear(ref Agent agent) { 
  llama_memory_clear(llama_get_memory(agent.ctx), true); agent.kvPos = 0; 
}

// Execute all tool calls and format responses
string execute(ref Agent agent, const ToolCall[] calls) {
  return(calls.map!(call => JSONValue(["tool": JSONValue(call.name), 
                                       "args": JSONValue(call.arguments), 
                                       "result": JSONValue(executeTool(call.name, call.arguments))]).toString()).join);
}

// Generate a reponse
llama_token[] generate(ref Agent agent, bool verbose = true, bool time = true) {
  llama_batch batch = llama_batch_init(llama_n_batch(agent.ctx), 0, 1);
  scope(exit) llama_batch_free(batch);

  llama_token im_start = agent.tokenOf("<|im_start|>");
  llama_token[] response;
  string tBuf;
  enum size_t MAX_TAG = "</tool_call>".length;
  bool inToolCall = false;
  char[256] buf = 0;
  size_t i = 0;
  auto t0 = MonoTime.currTime;

  for (i = 0; i < (llama_n_ctx(agent.ctx) - agent.kvPos); i++) {
    // Figure out the sampler, and sample a token
    auto sampler = (agent.json && inToolCall)? agent.json : agent.sampler;
    auto token = llama_sampler_sample(sampler, agent.ctx, -1);

    // Break on EOG, continue on null & start tokens
    if (llama_vocab_is_eog(agent.vocab, token)){ break; }
    if (im_start != LLAMA_TOKEN_NULL && token == im_start){ break; }

    // Add the token, detokenize, and print
    response ~= token;
    string strTok = agent.detokenize([token]);
    if (verbose) { write(strTok); if(i % 20 == 0){ stdout.fflush(); } }

    // Add string representation of token, and check for tool call
    tBuf ~= strTok;
    if (tBuf.length > MAX_TAG) tBuf = tBuf[$ - MAX_TAG .. $];
    if (!inToolCall && tBuf.endsWith("<tool_call>")) { inToolCall = true;  tBuf = ""; }
    if (inToolCall && tBuf.endsWith("</tool_call>")) { inToolCall = false; tBuf = ""; llama_sampler_reset(agent.json); }

    // Add the generated token to KV cache
    batch.token[0] = token;  batch.pos[0] = agent.kvPos + cast(int)response.length;
    batch.logits[0] = 1;     batch.n_tokens = 1;
    batch.n_seq_id[0] = 1;   batch.seq_id[0][0] = 0;
    if (llama_decode(agent.ctx, batch) != 0) break;
  }
  if (verbose) {
    if (time) { writef("\n===[%.1f tok/s]", i * 1000.0 / (MonoTime.currTime - t0).total!"msecs"); }
    write("\n"); stdout.fflush();
  }
  agent.kvPos += response.length;
  return(response);
}
