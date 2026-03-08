## DLLM - D Language 🤖 on 🦙.cpp
A minimal, clean D language agent built directly on [llama.cpp](https://github.com/ggerganov/llama.cpp) via 
[importC](https://dlang.org/spec/importc.html) — no Python, no bindings, no overhead. Runs a three-model 
pipeline (agent, summary, embed) with full CUDA offloading, multimodal vision via mtmd, RAG, KV-cache 
condensation, thinking budget, and an extensible tool system (auto-registered via UDA `@Tool`) covering file 
I/O, web search, Docker sandboxed code execution, and audio playback.

### Build with 🛠️
Compilation guide for dependencies are found in [`deps/README.md`](deps/README.md)
- **D Compiler**: DMD, LDC, or GDC
- **llama.cpp**: Bundled with [llama.cpp](https://github.com/ggerganov/llama.cpp)
- **Cuda Toolkit**: Built with [CUDA](https://developer.nvidia.com/cuda/toolkit) for GPU acceleration support
- **SearxNG**: Required for webSearch() tool
- **Docker**: Required for runCode() tool

### Models 🧠
Tested with the following free models, all available on [HuggingFace](https://huggingface.co/):
- **Agent**: [Qwen3.5-4B-Q4_K_M.gguf](https://huggingface.co/unsloth/Qwen3.5-4B-GGUF) + mmproj-F16.gguf (vision)
- **Summary**: [qwen2.5-0.5b-instruct-q4_k_m.gguf](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF)
- **Embed**: [nomic-embed-text-v1.5.Q4_K_M.gguf](https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF)

Model paths are configured in [`src/main.d`](src/main.d).

### Run ⚙️
Execute with prompt to OneShot:
```shell
  dub -- "What is your name?"
  dub -- "Download the image at https://picsum.photos/400, load it, and write a poem about it"
  dub -- "What date is it today ? and which day of the week was 2 days ago ?"
  dub -- "Generate a 8-second audio file of a 440hz sine wave that fades out, then play it"
  dub -- "Generate a spoken 16-bit PCM WAV of 'Hello World' and play it"
  dub -- "Ingest the file README.md into RAG, tell me what DLLM is in one sentence"
  dub -- "Read the file dub.json, and summarize in a single line what the file is about."
  dub -- "How is the weather in Newcastle upon Tyne (UK) ?"
  dub -- "Fetch the Bitcoin price history online, plot it as a chart and save to workspace"
  dub -- "Think about then tell me, a story about math, 4 lines of text and be creative!"
```

Or start an interactive session:
```shell
  dub
```

### Contributing 🙌

Want to contribute? Great! Contribute to this repo by starring ⭐ or forking 🍴, and feel 
free to start an issue first to discuss idea's before sending a pull request. You're also 
welcome to post comments on commits.

### License ⚖️

Written by Danny Arends and released as [GPLv3](./LICENSE.txt)
