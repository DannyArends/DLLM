/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

import std.format : format;
import std.stdio : writefln;

import context : processTokens;
import model : createContextParams, loadLlamaModel;
import sampler : createSampler;
import tools : toolsToJSON;
import vocab : ChatTemplate;

import agent : agent, agentStep;
import files : readFile;

const(char)* LLM_SUMMARY_MODEL = "../LLMs/Qwen3-0.6B.Q4_K_M.gguf";
const(char)* LLM_AGENT_MODEL   = "../LLMs/Qwen3-VL-4B-Thinking.Q4_K_M.gguf";
const(char)* LLM_MTMD_MODEL    = "../LLMs/Qwen3-VL-4B-Thinking.mmproj-Q8_0.gguf";

int main(string[] args) {
  // Setup Llama and Load model
  llama_model* model = loadLlamaModel(LLM_AGENT_MODEL);

  // Get vocab from model
  llama_vocab* vocab = llama_model_get_vocab(model);

  // Create context
  llama_context_params ctx_params = model.createContextParams();
  llama_context* ctx = llama_init_from_model(model, ctx_params);

   // Create sampler
  llama_sampler* sampler = createSampler();

  // Load MTMD model
  mtmd_context_params mparams = mtmd_context_params_default();
  mparams.use_gpu = true;
  mparams.n_threads = 4;
  agent.vision = mtmd_init_from_file(LLM_MTMD_MODEL, model, mparams);

  // Construct system, user, and assistant prompts and generate a full prompt
  size_t thinkBudget = 1024;
  auto system = format(readFile("templates/agent.txt"), toolsToJSON(), thinkBudget);
  auto user = (args[].length > 1)? args[($-1)] : "load the image in data/photo.png";

  auto tmpl = ChatTemplate(vocab, llama_model_chat_template(model, null));
  tmpl.add("system", system);
  tmpl.add("user", user);
  auto prompt = tmpl.render(true) ~ tmpl.thinkBootstrap(thinkBudget); // addAss=true adds assistant prefix
  if (agent.verbose) writefln("=== Prompt ===\n%s===", prompt);

  // Initial position, process prompt to tokens and set in KV cache (add_special = true for BOS)
  llama_pos cPos;
  if (!ctx.processTokens(agent.vision, prompt, [], cPos, ctx_params.n_batch, true)) { 
    writefln("Failed to eval prompt"); return 1;
  }

  // Create a batch and process prompt
  llama_batch batch = llama_batch_init(ctx_params.n_batch, 0, 1);

  // Agent loop
  int maxIterations = 10;
  for (int i = 0; i < maxIterations; i++) {
    if (!ctx.agentStep(tmpl, sampler, batch, i, cPos, ctx_params, thinkBudget)) break;
  }
  // Cleanup
  llama_batch_free(batch);
  llama_sampler_free(sampler);
  llama_free(ctx);
  llama_model_free(model);
  llama_backend_free();
  return(0);
}

