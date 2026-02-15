## DLLM - D Language Interface for llama.cpp ✨
A minimal, clean D language interface for running a local machine LLM agent inference using [importC](https://dlang.org/spec/importc.html) 
around [llama.cpp](https://github.com/ggerganov/llama.cpp).

### Features 🚀
No Python overhead with direct llama.cpp C API bindings using a modular design in the D language.
- **GPU acceleration** - Full CUDA support with automatic offloading
- **UTF-8 handling** - Proper emoji and multi-byte character support on Windows
- **Efficient batching** - Handles prompts with automatic chunking, cleans context on tool execution
- **Low memory footprint** - Q8_0 KV cache quantization

### Build with 🛠️
Compilation guide [here](deps/README.md)
- **D Compiler**: DMD, LDC, or GDC
- **llama.cpp**: Bundeled with [llama.cpp](https://github.com/ggerganov/llama.cpp)
- **Cuda Toolkit**: Built with [CUDA](https://developer.nvidia.com/cuda/toolkit) for GPU acceleration support

## Run ⚙️
Execute with prompt
```shell
  dub -- "What is your name?"
  dub -- "Tell me, what happened today?"
  dub -- "Tell me, what is going to happen tomorrow?"
  dub -- "Think about then tell me, a story about math, 4 lines of text and be creative!"
  dub -- "Read the file dub.json, and summarize in a single line what the file is about."
```

### Contributing 🙌

Want to contribute? Great! Contribute to this repo by starring ⭐ or forking 🍴, and feel 
free to start an issue first to discuss idea's before sending a pull request. You're also 
welcome to post comments on commits.

Or be a maintainer, and adopt (the documentation of) a function.

### License ⚖️

Written by Danny Arends and is released under the GNU GENERAL PUBLIC LICENSE Version 3 (GPLv3). 
See [LICENSE.txt](./LICENSE.txt).
