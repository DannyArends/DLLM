## DLLM - D Language Interface for llama.cpp ✨
A minimal, clean D language interface for running LLM inference using [llama.cpp](https://github.com/ggerganov/llama.cpp).

### Features

- **Direct llama.cpp C API bindings** - No Python overhead
- **GPU acceleration** - Full CUDA support with automatic offloading
- **Modular design** - Clean separation of concerns across modules
- **UTF-8 handling** - Proper emoji and multi-byte character support on Windows
- **Efficient batching** - Handles prompts of any length with automatic chunking
- **Low memory footprint** - Q8_0 KV cache quantization

### Requirements

#### Build Dependencies
- **D Compiler**: DMD, LDC, or GDC
- **llama.cpp**: Built with [CUDA](https://developer.nvidia.com/cuda/toolkit) support (for GPU acceleration)

#### Runtime
- **CUDA**: For GPU acceleration (optional but recommended)
- **Model files**: GGUF format models (e.g., Qwen, Llama, Mistral)

## Run
```shell
  dub --force -- "What is your name?"
  dub --force -- "Tell me, what happened today?"
  dub --force -- "Tell me, what is going to happen tomorrow?"
  dub --force -- "Think about, then tell me, a story about math, in 4 lines of text. Just be creative !"
```

### License

This project interfaces with llama.cpp, which is MIT licensed.

### Contributing

Contributions welcome! This is a minimal reference implementation focused on:
- Clean D code
- Direct C API usage
- Production-ready UTF-8 handling
- Efficient batching

### Acknowledgments

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - The underlying inference engine
- Built during research on LLM agent systems