/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.format : format;
import std.file : readText;
import std.stdio : writefln, writeln, write, writef, stdout, readln;
import std.string : strip;

import agent : agent, agentStep, compressHistory;
import console : setupConsole;
import context : processTokens;
import files : readFile;
import model : createCtxParams, loadLlamaModel;
import rag : RAG, loadRAG, cleanup;
import sampler : createSampler;
import tools : toolsToJSON;
import utils : checkNotNull;
import vocab : ChatTemplate;

int main(string[] args) {
  llama_backend_init();  // Initialize backend and setup console for UTF output
  scope(exit) llama_backend_free();
  setupConsole();

  // Setup RAG
  agent.rag = loadRAG(agent.LLM_EMBED_MODEL);
  scope(exit) agent.rag.cleanup();
  // Setup Llama and Load model
  llama_model* model = loadLlamaModel(agent.LLM_AGENT_MODEL).checkNotNull("Failed to load agent model");
  scope(exit) llama_model_free(model);

  // Get vocab from model
  llama_vocab* vocab = llama_model_get_vocab(model);

  // Create context
  llama_context_params ctx_params = model.createCtxParams(12_288);
  llama_context* ctx = llama_init_from_model(model, ctx_params).checkNotNull("Failed to create context");
  scope(exit) llama_free(ctx);

   // Create sampler
  llama_sampler* sampler = createSampler();
  scope(exit) llama_sampler_free(sampler);

  // Load MTMD model
  mtmd_context_params mparams = mtmd_context_params_default();
  mparams.use_gpu = true;
  mparams.n_threads = 4;
  agent.vision = mtmd_init_from_file(agent.LLM_MTMD_MODEL, model, mparams).checkNotNull("Failed to load vision model");;
  scope(exit) mtmd_free(agent.vision);

  // Construct system, user, and assistant prompts and generate a full prompt
  size_t thinkBudget = 256;
  auto tmpl = ChatTemplate(vocab, llama_model_chat_template(model, null));
  
  string systemFmt = readText("templates/agent.txt");
  string tools = toolsToJSON();
  auto system = systemFmt.format(tools, thinkBudget);
  tmpl.add("system", system);

  bool oneShot = args.length > 1;
  string user = oneShot ? args[($-1)] : "";

  // Create a batch and process prompt
  llama_pos cPos;
  llama_batch batch = llama_batch_init(ctx.llama_n_batch(), 0, 1);
  scope(exit) llama_batch_free(batch);

  // Process system prompt into KV cache once
  writefln("Context size: %d, processing system prompt.", ctx.llama_n_ctx());
  if (!ctx.processTokens(agent.vision, tmpl.render(false), [], cPos, true)) { 
    writefln("Failed to eval system prompt"); return 1;
  }

  do { // Main user REPL loop
    if (!oneShot) {
      writef("\nYou [%d/%dkb]: ", cPos / 1024, ctx.llama_n_ctx() / 1024); stdout.flush(); user = readln().strip();
      if (user == "" || user == "exit" || user == "quit") break;
    }

    // Compute previous length, add user prompt
    size_t prevLen = tmpl.render(false).length;
    tmpl.add("user", user);
    auto turn = tmpl.delta(prevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
    if (!ctx.processTokens(agent.vision, turn, agent.pendingBitmaps, cPos)) {
      writefln("[WARN] User turn overflow — compressing history and retrying...");
      if (!compressHistory(ctx, tmpl, cPos, thinkBudget)) { writefln("[ERROR] Failed to compress history"); break; }
      size_t retryPrevLen = tmpl.render(false).length;
      tmpl.add("user", user);
      auto retryTurn = tmpl.delta(retryPrevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
      if (!ctx.processTokens(agent.vision, retryTurn, agent.pendingBitmaps, cPos)) { writefln("[ERROR] Failed even after compression"); break; }
    }
    agent.pendingBitmaps = [];

    // Agent loop, max 10 iterations
    int maxIterations = 10;
    for (int i = 0; i < maxIterations; i++) {
      if (!ctx.agentStep(tmpl, sampler, batch, i, cPos, thinkBudget)) break;
    }
  } while (!oneShot);

  return(0);
}
