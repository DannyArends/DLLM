/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import core.stdc.string : strlen;
import std.algorithm.searching : canFind;

import tools : clean;

struct ChatTemplate {
  string roleStart;
  string roleEnd;
  string sep;

  static ChatTemplate chatML() { return ChatTemplate("<|im_start|>", "<|im_end|>", "\n"); }
  static ChatTemplate llama3() { return ChatTemplate("<|start_header_id|>", "<|end_header_id|>", "\n\n"); }

  string wrap(string role, string content) { return(roleStart ~ role ~ sep ~ content ~ roleEnd ~ sep); }
  string assistant() { return(roleStart ~ "assistant" ~ sep); }
  string tool(string response, string toolResult) { return(response.clean() ~ roleEnd ~ wrap("tool", toolResult)); }
}

// Tokenize prompt
llama_token[] tokenize(llama_vocab* vocab, string prompt) {
  int n_tokens = -llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, null, 0, true, true);
  llama_token[] tokens;
  tokens.length = n_tokens;
  llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, tokens.ptr, n_tokens, true, true);
  return(tokens);
}

// Detect chat template used by the model
ChatTemplate detectTemplate(llama_model* model) {
  const(char)* raw = llama_model_chat_template(model, null);
  if (raw is null) return ChatTemplate.chatML(); // fallback

  string t = cast(string)(raw[0..strlen(raw)]);

  if (t.canFind("<|im_start|>"))       return ChatTemplate.chatML();
  if (t.canFind("<|start_header_id|>")) return ChatTemplate.llama3();
  return ChatTemplate.chatML();
}

