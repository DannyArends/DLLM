## DLLM - D Language 🤖 on 🦙.cpp
A minimal, clean D language interface for running a local multimodal LLM agent using [importC](https://dlang.org/spec/importc.html) 
around [llama.cpp](https://github.com/ggerganov/llama.cpp). DLLM exposes the full llama.cpp C API directly from D with no Python 
overhead, supporting vision-language models via the mtmd API, automatic chat template detection, and an extensible tool-calling 
agent loop.

### Features 🚀
No Python overhead with direct llama.cpp C API bindings using a modular design in the D language.
- **GPU acceleration** - Full CUDA support with automatic offloading.
- **Multimodal** - Vision-language model support via the mtmd API.
- **Chat template detection** - Automatic model-agnostic prompt formatting.
- **UTF-8 handling** - Proper emoji and multi-byte character support on Windows.
- **Efficient batching** - Handles prompts with automatic chunking, cleans context on tool execution.
- **Agent, Summary, Embed** - Three-model setup for efficient tasking.
- **Think budget & KV-condensation** - KV-cache condensation and think budget to limit reasoning.
- **Auto-registered Tool** - Tools are auto-registered via UDA (`@Tool`).
- **Tools available** - RAG, Docker sandbox, Time, Encoding, File & Web search.

### Build with 🛠️
Compilation guide [here](deps/README.md)
- **D Compiler**: DMD, LDC, or GDC
- **llama.cpp**: Bundeled with [llama.cpp](https://github.com/ggerganov/llama.cpp)
- **Cuda Toolkit**: Built with [CUDA](https://developer.nvidia.com/cuda/toolkit) for GPU acceleration support
- **SearxNG**: Required for webSearch() tool
- **Docker**: Required for runCode() tool

### Run ⚙️
Execute with prompt to OneShot:
```shell
  dub -- "What is your name?"
  dub -- "Download the image at https://picsum.photos/400, load it, and describe it"
  dub -- "What date is it today ? and which day of the week was 2 days ago ?"
  dub -- "Write a python script into a file that generates an human audible wav file"
  dub -- "Read the file dub.json, and summarize in a single line what the file is about."
  dub -- "How is the weather in Newcastle upon Tyne (UK) ?"
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

Or be a maintainer, and adopt (the documentation of) a function.

### License ⚖️

Written by Danny Arends and is released under the GNU GENERAL PUBLIC LICENSE Version 3 (GPLv3). 
See [LICENSE.txt](./LICENSE.txt).
