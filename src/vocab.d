/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.string : toStringz;
import std.format : format;

import tools : clean;

struct ChatTemplate {
  llama_vocab* vocab;
  const(char)* tmplStr;           // from llama_model_chat_template(model, null)
  llama_chat_message[] messages;  // persistent history (keep strings alive!)

  this(llama_vocab* vocab, const(char)* tmplStr) {
    this.vocab = vocab;
    this.tmplStr = tmplStr;
  }

  void add(string role, string content) { messages ~= llama_chat_message(role.toStringz, content.toStringz); }

  string render(bool addAss = false) {
    int n = llama_chat_apply_template(tmplStr, messages.ptr, messages.length, addAss, null, 0);
    char[] buf = new char[n];
    llama_chat_apply_template(tmplStr, messages.ptr, messages.length, addAss, buf.ptr, n);
    return(buf[0..n].idup);
  }

  // If the model a thiking model ?
  @property bool canThink() {
    if(this.getToken("<think>", false) != LLAMA_TOKEN_NULL) return(true);
    return(false);
  }

  // Returns only the newly added portion
  string delta(size_t prevLen, bool addAss = false) { return render(addAss)[prevLen..$]; }

  // Returns the bootstrap line for the models thinking budget
  string thinkBootstrap(size_t thinkBudget = 512) {
    if(!canThink) return("");
    return(format("<think>\nBudget: %d tokens. Be concise.\n", thinkBudget)); 
  }

  // Does a string translate into a single llama_token
  llama_token getToken(string token, bool add_special = true, bool parse_special = true) {
    llama_token[] result = tokenize(vocab, token, add_special, parse_special);
    if (result.length == 1 && result[0] != LLAMA_TOKEN_NULL) return(result[0]);
    return(LLAMA_TOKEN_NULL);
  }
}

// Tokenize prompt
llama_token[] tokenize(llama_vocab* vocab, string prompt, bool add_special = true, bool parse_special = true) {
  int n_tokens = -llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, null, 0, add_special, parse_special);
  llama_token[] tokens;
  tokens.length = n_tokens;
  llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, tokens.ptr, n_tokens, add_special, parse_special);
  return(tokens);
}
