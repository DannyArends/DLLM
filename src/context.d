/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.array : appender;
import std.stdio : write, writeln, writefln, stdout;
import std.string : toStringz;

import utils : fitsInContext, nTokens;
import vocab : ChatTemplate, tokenize;

// Tokenize chunks and obtain the token size
int tokenizeChunks(mtmd_context* vision, ref mtmd_input_chunks* chunks, string text, mtmd_bitmap*[] bitmaps, bool add_special) {
  mtmd_input_text inp;
  inp.text = text.toStringz();
  inp.add_special = add_special;
  inp.parse_special = true;

  mtmd_tokenize(vision, chunks, &inp, bitmaps.ptr, bitmaps.length);
  return chunks.nTokens();
}

// Tokenize text (with optional images) and eval into KV cache, updating cPos
bool processTokens(llama_context* ctx, mtmd_context* vision,
                   string text, mtmd_bitmap*[] bitmaps, 
                   ref llama_pos cPos, bool add_special = false) {
  mtmd_input_chunks* chunks = mtmd_input_chunks_init();
  scope(exit) mtmd_input_chunks_free(chunks);

  int nTokens = vision.tokenizeChunks(chunks, text, bitmaps, add_special); // or equivalent token count API
  if (!ctx.fitsInContext(cPos, nTokens)) return false;
  return(mtmd_helper_eval_chunks(vision, ctx, chunks, cPos, 0, ctx.llama_n_batch(), true, &cPos) == 0);
}

// Tokenize text and eval into KV cache, updating cPos
bool processTokens(llama_context* ctx, string text, ref llama_pos cPos, bool add_special = false) {
  llama_token[] tokens = tokenize(llama_model_get_vocab(llama_get_model(ctx)), text, add_special);
  int n = cast(int)tokens.length;
  if (!ctx.fitsInContext(cPos, n)) return false;

  int n_batch = ctx.llama_n_batch();
  for (int i = 0; i < n; i += n_batch) {
    int end = (i + n_batch < n) ? i + n_batch : n;
    llama_batch batch = llama_batch_get_one(tokens.ptr + i, end - i);
    if (llama_decode(ctx, batch) != 0) return false;
    cPos += end - i;
  }
  return true;
}

// Generate a reponse
string generateTokens(llama_context* ctx, ChatTemplate tmpl, llama_sampler* sampler,
                      ref llama_batch batch, ref llama_pos cPos, ref int nGen, int ctxLeft, size_t thinkBudget = 512, bool verbose = true) {
  if (ctxLeft <= 0) { writeln("[ERROR] No context left for generation"); return ""; }
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
      if (verbose) { write(piece); stdout.flush(); }
      response ~= piece;
    }

    batch.token[0] = token;  batch.pos[0] = cPos + cast(int)i;
    batch.logits[0] = 1;     batch.n_tokens = 1;
    batch.n_seq_id[0] = 1;   batch.seq_id[0][0] = 0;
    if (llama_decode(ctx, batch) != 0) break;
    nGen++;
  }
  cPos += nGen;
  if (verbose) { writeln(); }
  return(response.data);
}

