/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import agent : Agent, agent, execute, prompt, process, generate, clean;
import rag : RAG;
import model : load, free, mp, cp, cpe;
import tools : toolsToJSON, parse;

int main(string[] args) {
  llama_backend_init();
  scope (exit) { llama_backend_free(); }

  setupConsole();

  // Embedding RAG model
  auto embed = load(["../LLMs/nomic-embed-text-v1.5.Q4_K_M.gguf"], mp(), cpe());

  // Agentic thinking model
  auto model = load(["../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf", "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf"], mp(), cp());
  llama_sampler_chain_add(model.sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
  scope (exit) { model.free(); }

  // Agent
  agent = Agent(model: model, chat : llama_model_chat_template(model, null), rag : RAG(model : embed));

  // Add the system prompt
  agent.history ~= llama_chat_message(toStringz("system"), toStringz(format(readText("templates/agent.txt"), toolsToJSON())));
  agent.process(agent.prompt(false));

  // User interaction loop
  do {
    writef("You [%.1f/%.1fkb]: ", agent.kvPos / 1024f, llama_n_ctx(agent.ctx) / 1024f); stdout.fflush(); string user = readln().strip();
    if (user == "" || user == "exit" || user == "quit") break;
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
