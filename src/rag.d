/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import model : detokenize, LlamaModel, tokenize;

struct Chunk {
  string text;
  float[] embedding;
}

struct RAG {
  LlamaModel model;
  Chunk[] index = [];
  alias model this;
}

// Compute embeddings for tokens
float[] embed(RAG rag, llama_token[] tokens) {
  llama_batch batch = llama_batch_get_one(tokens.ptr, cast(int)tokens.length);
  if (llama_encode(rag.ctx, batch) != 0) { writeln("encode failed"); return []; }
  float* e = llama_get_embeddings_seq(rag.ctx, 0);
  if (e is null) { writeln("embeddings null"); return []; }
  return(e[0..llama_model_n_embd(rag)].dup);
}

// Ingest a document into the RAG
size_t[2] ingest(ref RAG rag, string txt, size_t batchsize = 256) {
  llama_token[] all = rag.tokenize(txt, false);
  size_t nChunk = 0;
  for (size_t i = 0; i < all.length; i += batchsize / 2) {
    auto tokens = all[i .. min(i + batchsize, all.length)];
    rag.index ~= Chunk(rag.detokenize(tokens), rag.embed(tokens));
    nChunk++;
  }
  return([all.length, nChunk]);
}

// Query the RAG
string[] query(RAG rag, string query, int topK = 3) {
  float[] qEmbed = rag.embed(rag.tokenize(query, false));
  auto scored = rag.index.map!(c => tuple(c.text, cosineSimilarity(qEmbed, c.embedding))).array;
  auto ranked = scored.sort!((a, b) => a[1] > b[1]);
  return ranked.take(topK).map!(t => t[0]).array;
}

// Cosine similarity between vectors a and b
float cosineSimilarity(float[] a, float[] b) {
  float denom = sqrt(a.map!(x => x * x).sum) * sqrt(b.map!(x => x * x).sum);
  return(denom == 0.0f ? 0.0f : zip(a, b).map!(t => t[0] * t[1]).sum / denom);
}
