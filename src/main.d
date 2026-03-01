/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import agent : Agent, agent, execute, prompt, process, generate, clean, free;
import rag : RAG;
import model : load, mp, cp, cpe, free;
import tools : toolsToJSON, parse;

int main(string[] args) {
  llama_backend_init();
  scope (exit) { llama_backend_free(); }

  setupConsole();

  // Embedding RAG model
  auto embed = load(["../LLMs/nomic-embed-text-v1.5.Q4_K_M.gguf"], mp(), cpe());

  // Agentic thinking model & sampler chain
  auto model = load(["../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf", "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf"], mp(), cp());
  scope (exit) { model.free(); }
  llama_sampler_chain_add(model.sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  // Agent
  agent = Agent(model: model, chat : llama_model_chat_template(model, null), rag : RAG(model : embed));
  scope (exit) { agent.free(); }

  // Add the system prompt
  agent.history ~= llama_chat_message(toStringz("system"), toStringz(format(readText("templates/agent.txt"), toolsToJSON())));
  agent.process(agent.prompt(false));

  agent.running = !(args.length > 1);
  string user = !agent.running ? args[($-1)] : "";

  // User interaction loop
  do {
    if (agent.running) {
      writef("You [%.1f/%.1fkb]: ", agent.kvPos / 1024f, llama_n_ctx(agent.ctx) / 1024f); stdout.fflush(); user = readln().strip();
      if (user == "" || user == "exit" || user == "quit") break;
    }
    agent.history ~= llama_chat_message(toStringz("user"), toStringz(user));

    // Agent tool call loop
    do {
      agent.process(agent.prompt(), false);
      auto tokens = agent.generate();
      auto response = agent.clean(tokens);
      auto results = agent.execute(response.parse());
      if (results.length == 0) break;
      agent.history ~= llama_chat_message(toStringz("tool"), toStringz(results));
    } while(true);
  } while(agent.running);
  return(0);
}
