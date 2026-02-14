import includes;

// Process prompt
bool processTokens(llama_context* ctx, ref llama_batch batch, const(llama_token[]) tokens, int capacity) {
  int n_tokens = cast(int)tokens.length;
  if (n_tokens <= 0) return false;
  
  // Process in chunks
  for (int batch_start = 0; batch_start < n_tokens; batch_start += capacity) {
    int batch_size = (n_tokens - batch_start) < capacity ? (n_tokens - batch_start) : capacity;

    for (int i = 0; i < batch_size; i++) {      // Fill batch
      batch.token[i] = tokens[batch_start + i];
      batch.pos[i] = batch_start + i;
      batch.n_seq_id[i] = 1;
      batch.seq_id[i][0] = 0;
      batch.logits[i] = 0;
    }
    batch.n_tokens = batch_size;
    if (batch_start + batch_size == n_tokens) { batch.logits[batch_size - 1] = 1; }   // Only get last token logits
    if (llama_decode(ctx, batch) != 0) { return false; }                              // Decode
  }
  return true;
}
