/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : appender;
import std.string : toStringz;
import std.format : format;

import model : LlamaModel;
import tools : clean;

enum llama_token LLAMA_TOKEN_NULL = -1;

struct ChatTemplate {
  const(char)* tmplStr;               /// Chat template from llama_model_chat_template(model, null)
  llama_chat_message[] messages;      /// Persistent history
  bool canThink = false;              /// Is the model able to think ?

  this(LlamaModel m, const(char)* tmplStr) {
    this.tmplStr = tmplStr;
    if(this.getToken(m, "<think>", false) != LLAMA_TOKEN_NULL) canThink = true;
  }

  // Add a message to the history for role
  void add(string role, string content) { messages ~= llama_chat_message(role.toStringz, content.toStringz); }

  // Render the chat template
  string render(bool addAss = false) {
    int n = llama_chat_apply_template(tmplStr, messages.ptr, messages.length, addAss, null, 0);
    char[] buf = new char[n];
    llama_chat_apply_template(tmplStr, messages.ptr, messages.length, addAss, buf.ptr, n);
    return(buf[0..n].idup);
  }

  // Returns only the newly added portion
  string delta(size_t prevLen, bool addAss = false) { return render(addAss)[prevLen..$]; }

  // Returns the bootstrap line for the models thinking budget
  string thinkBootstrap(size_t thinkBudget = 256) {
    if(!canThink) return("");
    return(format("<think>\nBudget: %d tokens. Be concise.\n", thinkBudget)); 
  }

  // Returns the bootstrap line to disable thinking
  string noThinkBootstrap() {
    if (!canThink) return "";
    return("<think>\n</think>\n");
  }

  // Does a string translate into a single llama_token
  llama_token getToken(LlamaModel m, string token, bool add_special = true, bool parse_special = true) {
    llama_token[] result = m.tokenize(token, add_special, parse_special);
    if (result.length == 1 && result[0] != LLAMA_TOKEN_NULL) return(result[0]);
    return(LLAMA_TOKEN_NULL);
  }
}

// Tokenize a string prompt into tokens
llama_token[] tokenize(LlamaModel m, string prompt, bool add_special = true, bool parse_special = true) {
  int n_tokens = -llama_tokenize(m.vocab, prompt.ptr, cast(int)prompt.length, null, 0, add_special, parse_special);
  llama_token[] tokens;
  tokens.length = n_tokens;
  llama_tokenize(m.vocab, prompt.ptr, cast(int)prompt.length, tokens.ptr, n_tokens, add_special, parse_special);
  return(tokens);
}

// De-tokenize a list of tokens tokens into a string
string detokenize(LlamaModel m, llama_token[] tokens) {
  auto result = appender!string;
  char[256] buf = 0;
  foreach (token; tokens) {
    int n = llama_token_to_piece(m.vocab, token, buf.ptr, buf.sizeof, 0, true);
    if (n > 0) result ~= cast(string)buf[0..n];
  }
  return result.data;
}
