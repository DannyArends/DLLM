/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import core.stdc.stdlib : exit;
import std.stdio : writefln;

T checkNotNull(T)(T ptr, string msg) {
  if (!ptr) { writefln("[ERROR] %s", msg); exit(1); }
  return ptr;
}

bool fitsInContext(llama_context* ctx, llama_pos cPos, int n, string caller = "") {
  if (cPos + n <= ctx.llama_n_ctx()) return true;
  writefln("[ERROR] %s: would exceed context (%d + %d > %d)", caller, cPos, n, ctx.llama_n_ctx());
  return false;
}
