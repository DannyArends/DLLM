/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.stdio : write, writeln;
import std.array : appender;
import std.string : toStringz;

import vocab : ChatTemplate;

// Tokenize text (with optional images) and eval into KV cache, updating cPos
bool processTokens(mtmd_context* ctx_vision, llama_context* ctx, 
                   string text, mtmd_bitmap*[] bitmaps, 
                   ref llama_pos cPos, int n_batch, bool add_special = false) {
  mtmd_input_text inp;
  inp.text = text.toStringz();
  inp.add_special = add_special;
  inp.parse_special = true;

  mtmd_input_chunks* chunks = mtmd_input_chunks_init();
  scope(exit) mtmd_input_chunks_free(chunks);
  mtmd_tokenize(ctx_vision, chunks, &inp, bitmaps.ptr, bitmaps.length);
  if (mtmd_helper_eval_chunks(ctx_vision, ctx, chunks, cPos, 0, n_batch, true, &cPos) != 0) {
    return false;
  }
  return true;
}

string generateTokens(llama_context* ctx, ChatTemplate tmpl, llama_sampler* sampler,
                      ref llama_batch batch, ref llama_pos cPos, ref int nGen, int ctxLeft, size_t thinkBudget = 512) {
  auto response = appender!string;
  char[256] buf = 0;
  size_t thinkTokens = 0;
  bool thinkDone = false;
  llama_token thinkEndToken = tmpl.getToken("</think>");

  for (size_t i = 0; i < ctxLeft; i++) {
    llama_token token = llama_sampler_sample(sampler, ctx, -1);
    if (llama_vocab_is_eog(tmpl.vocab, token)) break;

    if (!thinkDone && tmpl.canThink) {
      if (token == thinkEndToken) { thinkDone = true; }
      else if (++thinkTokens >= thinkBudget) {
        token = thinkEndToken;
        thinkDone = true;
      }
    }

    size_t n = llama_token_to_piece(tmpl.vocab, token, buf.ptr, buf.sizeof, 0, true);
    if (n > 0) {
      string piece = cast(string)buf[0..n];
      write(piece); stdout.fflush();
      response ~= piece;
    }

    batch.token[0] = token;  batch.pos[0] = cPos + cast(int)i;
    batch.logits[0] = 1;     batch.n_tokens = 1;
    batch.n_seq_id[0] = 1;   batch.seq_id[0][0] = 0;
    if (llama_decode(ctx, batch) != 0) break;
    nGen++;
  }
  cPos += nGen;
  writeln();
  return response.data;
}

