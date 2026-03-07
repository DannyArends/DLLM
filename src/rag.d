/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import model : detokenize, LlamaModel, tokenize;

const uint RAG_MAGIC = 0xBA610001;

struct Chunk {
  string origin;                  /// Chunk origin (unknown, path, url)
  string text;                    /// Text
  float[] embedding;              /// Text Embedding
}

struct RAG {
  LlamaModel model;               /// Model pointer
  Chunk[] index = [];             /// Chunk index
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

// Ingest a document into the RAG using batchsize batches, shifted by 1/2 batchsize
size_t[2] ingest(ref RAG rag, string txt, string origin = "unknown") {
  auto n_batch = llama_n_batch(rag.ctx);
  llama_token[] all = rag.tokenize(txt, false);
  size_t nChunk = 0;
  for (size_t i = 0; i < all.length; i += n_batch / 2) {
    auto tokens = all[i .. min(i + n_batch, all.length)];
    rag.index ~= Chunk(origin, rag.detokenize(tokens), rag.embed(tokens));
    nChunk++;
  }
  return([all.length, nChunk]);
}

// Query the RAG
string[] query(RAG rag, string query, int topK = 3) {
  float[] qEmbed = rag.embed(rag.tokenize(query, false));
  auto scored = rag.index.map!(c => tuple(c.origin, c.text, cosineSimilarity(qEmbed, c.embedding))).array;
  auto ranked = scored.sort!((a, b) => a[2] > b[2]);
  return ranked.take(topK).map!(t => format("[%s] %s", t[0], t[1])).array;
}

// Cosine similarity between vectors a and b
float cosineSimilarity(float[] a, float[] b) {
  float denom = sqrt(a.map!(x => x * x).sum) * sqrt(b.map!(x => x * x).sum);
  return(denom == 0.0f ? 0.0f : zip(a, b).map!(t => t[0] * t[1]).sum / denom);
}

// Save the RAG
void save(ref RAG rag, string path) {
  auto f = File(path, "wb");
  f.rawWrite((&RAG_MAGIC)[0..1]);
  ulong n = rag.index.length;
  f.rawWrite((&n)[0..1]);
  foreach (chunk; rag.index) {
    f.writeRAG(chunk.origin);
    f.writeRAG(chunk.text);
    f.writeRAG(chunk.embedding);
  }
}

// Load the RAG
void load(ref RAG rag, string path) {
  if (!exists(path)) return;
  auto f = File(path, "rb");
  uint magic; f.rawRead((&magic)[0..1]);
  if (magic != RAG_MAGIC) throw new Exception("Invalid or stale RAG file: " ~ path);
  ulong n; f.rawRead((&n)[0..1]);
  rag.index.length = 0;
  foreach (_; 0..n) {
    rag.index ~= Chunk(f.readRAG!char().idup, f.readRAG!char().idup, f.readRAG!float());
  }
}
