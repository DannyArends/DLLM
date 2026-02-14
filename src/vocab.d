import includes;

import std.string : toStringz;

// Tokenize prompt
llama_token[] tokenizePrompt(llama_vocab* vocab, 
                             string prompt = "<|im_start|>system\nYou're an assistant\n<|im_end|>\n<|im_start|>user\nWhat is your role?\n<|im_end|>\n<|im_start|>assistant\n\0"){
  int n_tokens = -llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, null, 0, true, true);
  llama_token[] tokens;
  tokens.length = n_tokens;
  llama_tokenize(vocab, prompt.ptr, cast(int)prompt.length, tokens.ptr, n_tokens, true, true);
  return(tokens);
}
