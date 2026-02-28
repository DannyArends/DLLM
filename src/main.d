/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.format : format;
import std.file : readText;
import std.stdio : writefln, writeln, write, writef, stdout, readln;
import std.string : strip;

import agent : agent, agentModel, agentStep, compressHistory;
import console : setupConsole;
import context : processTokens;
import files : readFile;
import model : M, MODEL_PATHS, loadModel, nModels, free;
import sampler : createSampler;
import tools : toolsToJSON;
import utils : checkNotNull;
import vocab : ChatTemplate;

int main(string[] args) {
  llama_backend_init();  // Initialize backend and setup console for UTF output
  scope(exit) llama_backend_free();
  setupConsole();

  // Load models
  agent.models[M.agent] = loadModel(MODEL_PATHS[M.agent], 3 * 2048);
  agent.models[M.summary] = loadModel(MODEL_PATHS[M.summary], 2048);
  agent.models[M.embed] = loadModel(MODEL_PATHS[M.embed], 512, 512, 512, 8, true);
  agent.models[M.agent].sampler = createSampler();
  agent.models[M.summary].sampler = createSampler(0.3f);
  scope(exit) { foreach (m; 0..nModels) agent.models[m].free(); }

  // Construct system, user, and assistant prompts and generate a full prompt
  size_t thinkBudget = 1024;
  auto tmpl = ChatTemplate(agentModel, llama_model_chat_template(agentModel.model, null));
  
  string systemFmt = readText("templates/agent.txt");
  string tools = toolsToJSON();
  auto system = systemFmt.format(tools, thinkBudget);
  tmpl.add("system", system);

  bool oneShot = args.length > 1;
  string user = oneShot ? args[($-1)] : "";

  // Create a batch and process prompt
  llama_pos cPos;
  llama_batch batch = llama_batch_init(agentModel.llama_n_batch(), 0, 1);
  scope(exit) llama_batch_free(batch);

  // Process system prompt into KV cache once
  writefln("Context size: %d, processing system prompt.", agentModel.llama_n_ctx());
  if (!agentModel.processTokens(tmpl.render(false), [], cPos, true)) { 
    writefln("Failed to eval system prompt"); return 1;
  }

  do { // Main user REPL loop
    if (!oneShot) {
      writef("\nYou [%d/%dkb]: ", cPos / 1024, agentModel.llama_n_ctx() / 1024); stdout.flush(); user = readln().strip();
      if (user == "" || user == "exit" || user == "quit") break;
    }

    // Compute previous length, add user prompt
    size_t prevLen = tmpl.render(false).length;
    tmpl.add("user", user);
    auto turn = tmpl.delta(prevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
    if (!agentModel.processTokens(turn, agent.pendingBitmaps, cPos)) {
      writefln("[WARN] User turn overflow — compressing history and retrying...");
      if (!compressHistory(agentModel, tmpl, cPos, thinkBudget)) { writefln("[ERROR] Failed to compress history"); break; }
      size_t retryPrevLen = tmpl.render(false).length;
      tmpl.add("user", user);
      auto retryTurn = tmpl.delta(retryPrevLen, true) ~ tmpl.thinkBootstrap(thinkBudget);
      if (!agentModel.processTokens(retryTurn, agent.pendingBitmaps, cPos)) { writefln("[ERROR] Failed even after compression"); break; }
    }
    agent.pendingBitmaps = [];

    // Agent loop, max 10 iterations
    int maxIterations = 10;
    for (int i = 0; i < maxIterations; i++) {
      if (!agentModel.agentStep(tmpl, batch, i, cPos, thinkBudget)) break;
    }
  } while (!oneShot);

  return(0);
}
