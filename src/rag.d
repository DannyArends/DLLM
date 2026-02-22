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
import model : createContextParams, loadLlamaModel;
import utils : checkNotNull;

// RAG Chunk
struct Chunk {
  string text;
  float[] embedding;
}

// Retrieval Augmented Generation (RAG)
struct RAG {
  llama_model* model;
  llama_context* ctx;
  llama_vocab* vocab;
  Chunk[] index;
  size_t batchSize = 512;
}

RAG loadRAG(const(char)* modelPath) {
  RAG rag;
  rag.model = loadLlamaModel(modelPath).checkNotNull("Failed to load embedding model");
  llama_context_params params = rag.model.createContextParams(rag.batchSize);
  params.embeddings = true;
  rag.ctx = llama_init_from_model(rag.model, params).checkNotNull("Failed to create embedding context");
  rag.vocab = llama_model_get_vocab(rag.model);
  return(rag);
}

// Ingest a document into the RAG
void ingest(RAG rag, string text) {
  llama_token[] all = tokenize(rag.vocab, text, false);
  for (size_t i = 0; i < all.length; i += rag.batchSize) {
    auto tokens = all[i..min(i + rag.batchSize, all.length)];
    string chunk = detokenize(rag.vocab, tokens);
    auto emb = embed(rag.ctx, rag.vocab, tokens);
    if (emb.length > 0) rag.index ~= Chunk(chunk, emb);
  }
}

// Query the RAG
string[] query(RAG rag, string q, int topK = 3) {
  llama_token[] qTokens = tokenize(rag.vocab, q, true);
  if (qTokens.length > rag.ctx.llama_n_ubatch())
    qTokens = qTokens[0..rag.ctx.llama_n_ubatch()];
  float[] qEmbed = rag.ctx.embed(rag.vocab, qTokens);
  if (qEmbed.length == 0) return [];
  auto scored = new float[rag.index.length];
  foreach (i, ref c; rag.index) scored[i] = cosineSimilarity(qEmbed, c.embedding);
  auto indices = new size_t[rag.index.length];
  foreach (i; 0..indices.length) indices[i] = i;
  indices.sort!((a, b) => scored[a] > scored[b]);
  string[] results;
  foreach (i; 0..min(topK, indices.length)) results ~= rag.index[indices[i]].text;
  return results;
}

void cleanup(RAG rag) { llama_free(rag.ctx); llama_model_free(rag.model); }

// Cosine similarity between vectors a and b
float cosineSimilarity(float[] a, float[] b) {
  float dot = 0, normA = 0, normB = 0;
  foreach (i; 0..a.length) { dot += a[i] * b[i]; normA += a[i] * a[i]; normB += b[i] * b[i]; }
  float denom = sqrt(normA) * sqrt(normB);
  if (denom == 0.0f) return 0.0f;
  return dot / denom;
}

// Tokenize the text and get embeddings
float[] embed(llama_context* ctx, llama_vocab* vocab, string text) {
  return(ctx.embed(vocab, tokenize(vocab, text, true)));
}

// Tokenize the text and get embeddings
float[] embed(llama_context* ctx, llama_vocab* vocab, llama_token[] tokens) {
  if (tokens.length > ctx.llama_n_ubatch()) {
    writefln("[ERROR] embed: text too large for batch (%d > %d)", tokens.length, ctx.llama_n_ubatch());
    return [];
  }
  llama_batch batch = llama_batch_get_one(tokens.ptr, cast(int)tokens.length);
  if (llama_decode(ctx, batch) != 0) { writefln("[ERROR] embed: llama_decode failed"); return []; }
  int n_embd = llama_model_n_embd(llama_get_model(ctx));
  float* e = llama_get_embeddings_seq(ctx, 0);
  if (!e) { writefln("[ERROR] embed: llama_get_embeddings_seq returned null"); return []; }
  return e[0..n_embd].dup;
}
