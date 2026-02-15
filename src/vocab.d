/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

string toolResponseFmt = "<|im_end|>\n<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n";
string assistantFmt = "<|im_start|>system\nYou're a creative, smart, and thinking assistant with access to tools.\n\nAvailable tools:\n%s\n\nUSAGE:\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": \"tool_name\", \"arguments\": {\"arg\": \"value\"}}\n</tool_call>\n\nIMPORTANT:\n- Never invent tool results. If a tool fails, say so\n- Before your final answer think\n- Always use tools when possible\n- You can call multiple tools.\n- Always surround tool calls with the <tool_call> and </tool_call> tags.\n- Make sure to write closing tags.\n- After receiving tool results, provide your final answer.\n<|im_end|>\n<|im_start|>user\n%s\n<|im_end|>\n<|im_start|>assistant\n\0";

// Tokenize prompt
llama_token[] tokenizePrompt(llama_vocab* vocab, 
                             string prompt = assistantFmt){
  int n_tokens = -llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, null, 0, true, true);
  llama_token[] tokens;
  tokens.length = n_tokens;
  llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, tokens.ptr, n_tokens, true, true);
  return(tokens);
}
