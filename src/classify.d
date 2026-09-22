/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module classify;

import includes;
import utils;

import agent : Agent, clear, process, render;
import model : tokenize;

/** Typed single-choice result: chosen option, its probability, and the full distribution */
struct Verdict {
  size_t index;               /// Index of the chosen option
  float confidence = 0.0f;    /// Softmax mass on the chosen option
  float[] probs;              /// Softmax probability per option
}

/** Classify state against one question over 2..26 options in a single forward pass (jev-like) */
Verdict classify(ref Agent agent, string state, string question, const(string)[] options) {
  assert(options.length >= 2 && options.length <= 26, "classify: need 2..26 options");

  // Lettered single-choice user turn
  auto q = appender!string;
  q ~= state; q ~= "\n\n"; q ~= question; q ~= "\n";
  foreach(i, opt; options) { q ~= cast(char)('A' + i); q ~= ") "; q ~= opt; q ~= "\n"; }
  q ~= "\nReply with only the letter of the single best option.";
  llama_chat_message[] msgs = [llama_chat_message(toStringz("user"), toStringz(q.data))];

  // Suppress thinking, pin the next token to the option letter, evaluate once
  string prompt = render(agent.chat, msgs, true) ~ "<think>\n\n</think>\n\nThe answer is ";
  agent.clear();
  agent.process(prompt);
  const(float)* logits = llama_get_logits_ith(agent.ctx, -1);

  // Softmax over the per-option letter tokens at the last position
  int nVocab = llama_vocab_n_tokens(agent.vocab);
  float[] probs; probs.length = options.length;
  float mx = -float.max;
  foreach(i; 0 .. options.length) {
    llama_token t = agent.tokenize([cast(char)('A' + i)].idup, false, false)[0];
    probs[i] = (t >= 0 && t < nVocab) ? logits[t] : -float.max;
    if (probs[i] > mx) mx = probs[i];
  }
  float z = 0f;
  foreach(ref p; probs) { p = exp(p - mx); z += p; }
  Verdict v = { probs: probs };
  foreach(i, ref p; probs) { p /= z; if (p > v.confidence) { v.confidence = p; v.index = i; } }
  return(v);
}

unittest {
  import std.file : exists;
  import agent : Agent, free;
  import model : load, mGpu, context, free;
  enum modelP = "../LLMs/Qwen3.5-4B-Q4_K_M.gguf";
  enum projP  = "../LLMs/mmproj-Qwen3.5-4B-F16.gguf";
  if (!modelP.exists || !projP.exists) { writeln("  SKIP: classify (models absent)"); return; }

  llama_backend_init();
  scope(exit) llama_backend_free();
  auto m = load([modelP, projP], mGpu(), context(4096, 1024, GGML_TYPE_Q8_0, true));
  scope(exit) m.free();

  auto a = Agent(model: m, chat: llama_model_chat_template(m, null));
  scope(exit) a.free();

  auto v = a.classify("The kitten is asleep in a sunbeam.", "What is this text about?", ["finance", "animals", "weather"]);
  check(["finance", "animals", "weather"][v.index], "animals", "classify: picks obvious option");
}
