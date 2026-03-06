/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import agent : Agent, agent, condense, execute, prompt, process, generate, clean, clear, free;
import rag : RAG;
import summary : Summary;
import model : load, mGpu, mCpu, context, embedding, free;
import tools : toolsToJSON, parse;
import time : currentDate;

int main(string[] args) {
  // Initialize Llama and set UTF-8 console output
  llama_backend_init();
  scope (exit) { llama_backend_free(); }
  setupConsole();

  // CPU: Summary model with low temp sampler
  auto summary = load(["../LLMs/Qwen3.5-0.8B-Q4_K_M.gguf"], mGpu(), context(32768));
  scope (exit) { summary.free(); }
  llama_sampler_chain_add(summary.sampler, llama_sampler_init_temp(0.3f));
  llama_sampler_chain_add(summary.sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  // CPU: Embedding RAG model
  auto embed = load(["../LLMs/nomic-embed-text-v1.5.Q4_K_M.gguf"], mCpu(), embedding(512));
  scope (exit) { embed.free(); }

  // GPU: Agentic thinking model & high temp sampler chain (4096 / 8192 / 16384 [X] / 32768)
  auto model = load(["../LLMs/Qwen3.5-4B-Q4_K_M.gguf", 
                     "../LLMs/mmproj-F16.gguf"], mGpu(), context());
  scope (exit) { model.free(); }
  llama_sampler_chain_add(model.sampler, llama_sampler_init_penalties(64, 1.1f, 0.0f, 0.0f));
  llama_sampler_chain_add(model.sampler, llama_sampler_init_temp(0.7f));
  llama_sampler_chain_add(model.sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

  // Agent structure and RAG
  agent = Agent(model: model, chat : llama_model_chat_template(model, null),
                rag : RAG(model : embed), 
                summary : Summary(model : summary, chat: llama_model_chat_template(summary, null)) );
  scope (exit) { agent.free(); }

  // Add the system prompt with tools
  agent.history ~= llama_chat_message(toStringz("system"), 
                                      toStringz(format(readText("templates/agent.txt"), currentDate(), toolsToJSON(), readText("data/memory.txt"))));
  agent.process(agent.prompt(false));

  // Oneshot or interactive mode ?
  agent.running = !(args.length > 1);
  string user = !agent.running ? args[($-1)] : "";
  do {
    if (agent.running) {
      writef("=== You [%.1f/%.1fkb]: ", agent.kvPos / 1024f, llama_n_ctx(agent.ctx) / 1024f); stdout.fflush(); user = readln().strip();
      if (user == "" || user == "exit" || user == "quit") break;
    }
    agent.history ~= llama_chat_message(toStringz("user"), toStringz(user));
    agent.condense();
    do { // Agent tool calling loop
      agent.clear();
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
