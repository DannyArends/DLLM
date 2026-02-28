/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.algorithm : min, sort;
import std.array : appender;
import std.math : sqrt;
import std.stdio : writefln;

import vocab : tokenize, detokenize;
import agent : agent;
import model : LlamaModel, M;
import utils : checkNotNull;

// RAG Chunk
struct Chunk {
  string text;
  float[] embedding;
}

// Ingest a document into the RAG
void ingest(LlamaModel m, string text) {
  llama_token[] all = m.tokenize(text, false);
  for (size_t i = 0; i < all.length; i += m.llama_n_ubatch()) {
    auto tokens = all[i..min(i + m.llama_n_ubatch(), all.length)];
    string chunk = m.detokenize(tokens);
    auto emb = m.embed(tokens);
    if (emb.length > 0) agent.ragIndex ~= Chunk(chunk, emb);
  }
}

// Query the RAG
string[] query(LlamaModel m, string q, int topK = 3) {
  if (agent.ragIndex.length == 0) return [];
  llama_token[] qTokens = m.tokenize(q, true);
  if (qTokens.length > m.llama_n_ubatch())
    qTokens = qTokens[0 .. m.llama_n_ubatch()];
  float[] qEmbed = m.embed(qTokens);
  if (qEmbed.length == 0) return [];
  auto scored = new float[agent.ragIndex.length];
  foreach (i, ref c; agent.ragIndex) scored[i] = cosineSimilarity(qEmbed, c.embedding);
  auto indices = new size_t[agent.ragIndex.length];
  foreach (i; 0..indices.length) indices[i] = i;
  indices.sort!((a, b) => scored[a] > scored[b]);
  string[] results;
  foreach (i; 0..min(topK, indices.length)) results ~= agent.ragIndex[indices[i]].text;
  return results;
}

// Cosine similarity between vectors a and b
float cosineSimilarity(float[] a, float[] b) {
  float dot = 0, normA = 0, normB = 0;
  foreach (i; 0..a.length) { dot += a[i] * b[i]; normA += a[i] * a[i]; normB += b[i] * b[i]; }
  float denom = sqrt(normA) * sqrt(normB);
  if (denom == 0.0f) return 0.0f;
  return dot / denom;
}

// Tokenize the text and get embeddings
float[] embed(LlamaModel m, string text) { return(m.embed(m.tokenize(text, true))); }

// Tokenize the text and get embeddings
float[] embed(LlamaModel m, llama_token[] tokens) {
  if (tokens.length > m.llama_n_ubatch()) {
    writefln("[ERROR] embed: text too large for batch (%d > %d)", tokens.length, m.llama_n_ubatch());
    return [];
  }
  llama_batch batch = llama_batch_get_one(tokens.ptr, cast(int)tokens.length);
  if (llama_encode(m, batch) != 0) { writefln("[ERROR] embed: llama_encode failed"); return []; }
  int n_embd = llama_model_n_embd(llama_get_model(m));
  float* e = llama_get_embeddings_seq(m, 0);
  if (!e) { writefln("[ERROR] embed: llama_get_embeddings returned null"); return []; }
  return e[0..n_embd].dup;
}
