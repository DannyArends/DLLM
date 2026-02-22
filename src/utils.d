/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import core.stdc.stdlib : exit;
import std.stdio : writefln;

// Check if not null, if it is exit()
T checkNotNull(T)(T ptr, string msg) {
  if (!ptr) { writefln("[ERROR] %s", msg); exit(1); }
  return ptr;
}

// nTokens across all chunks
int nTokens(mtmd_input_chunks* chunks) {
  int total = 0;
  for (size_t i = 0; i < mtmd_input_chunks_size(chunks); i++) {
    total += mtmd_input_chunk_get_n_pos(mtmd_input_chunks_get(chunks, i));
  }
  return total;
}

// Check if the we can fit n tokens in the context starting at cPos
bool fitsInContext(llama_context* ctx, llama_pos cPos, int n) {
  if (cPos + n <= ctx.llama_n_ctx()) return true;
  writefln("[WARN] Would exceed context (%d + %d > %d)", cPos, n, ctx.llama_n_ctx());
  return false;
}
