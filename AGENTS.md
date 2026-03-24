# AGENTS.md — DLLM Codebase Guide

## What This Is
DLLM is a D-language agentic LLM runtime built directly on llama.cpp via importC (no bindings, no Python).
It runs a three-model pipeline and exposes an extensible tool system to the agent.

## Repository Layout
```
src/
  main.d          — Entry point: model loading, sampler setup, agent init, interactive/oneshot loop
  model.d         — LlamaModel struct, load/free, tokenize/detokenize, context params
  agent.d         — Agent struct, prompt generation, KV cache management, generate/clean/execute
  rag.d           — RAG struct, chunk ingestion, embedding, cosine similarity, binary save/load
  summary.d       — Summary struct, history condensation using a separate CPU model
  tools.d         — Tool registry, @Tool UDA, RegisterTools mixin, JSON grammar, tool executor
  utils.d         — Shared imports, isSafePath, setupConsole, RAG binary I/O helpers
  includes.c      — importC bridge: pulls in ggml.h, llama.h, mtmd.h
  tools/
    files.d       — File I/O tools: read, write, replace, grep, RAG ingest, image load, memento
    sandbox.d     — Docker sandboxed code execution (Python, JS, Bash, R, D)
    web.d         — webFetch, webSearch (SearxNG at localhost:8080), downloadImage
    time.d        — Date/time tools
    encoding.d    — Base64, MD5, SHA256, UUID
    counting.d    — Word count, string length, occurrence count
templates/
  AGENT.md        — System prompt template (format args: date, toolsJSON, memento)
  SUMMARY.md      — Summary model system prompt
  MEMENTO.md      — Persistent agent memory, written by writeMemento tool
workspace/
  RAG.bin         — Persisted RAG index (binary, native-endian, magic 0xBA610002)
deps/
  llama.cpp/      — llama.cpp submodule, must be built before DLLM
```

## Key Architecture Decisions

**Three-model pipeline:**
- `model` — GPU, main agentic model (Qwen3.5-4B + vision mmproj)
- `summary` — CPU, condenses history when KV pressure exceeds 60% threshold
- `embed` — CPU, embedding model for RAG ingestion and query

**KV cache strategy:** The full history is evaluated once per user turn (`clear()` + `process(prompt)`).
Inside the tool-calling loop, only the new tool result delta is processed incrementally.
`kvPos` tracks the next free slot; `generate()` advances it by `response.length + 1`.

**Tool system:** Any function annotated with `@Tool("description")` in a module that mixes in
`RegisterTools` is auto-registered at startup. All parameters are typed as `string`. The agent
calls tools via `<tool_call>{...}</tool_call>` tags; the JSON sampler (grammar-constrained) is
activated during tool call generation.

**Path safety:** `isSafePath(path, "r")` restricts to `CRD` (project root).
`isSafePath(path, "w")` restricts to `CWD` (workspace/ only). Always call the correct variant.

**Global agent singleton:** `__gshared Agent agent` in `agent.d` is used by tool callbacks.
Not thread-safe by design — single-user CLI only.

## Adding a New Tool
1. Create or pick a file in `src/tools/`
2. Add `mixin RegisterTools;` if not already present
3. Write a free function with `@Tool("description")` — all parameters must be `string`
4. The tool is auto-registered at startup; no other changes needed

Example:
```d
@Tool("Reverse a string.")
string reverseString(string text) {
  import std.algorithm : reverse;
  auto arr = text.dup;
  reverse(arr);
  return arr.idup;
}
```

## Building
See `deps/README.md` for llama.cpp build instructions. Then:
```shell
dub build
```
Requires: DMD/LDC/GDC, CUDA toolkit, Docker (for sandbox), SearxNG on localhost:8080 (for web search).

## Model Paths
Currently hardcoded in `src/main.d` lines 26, 32, 36–37. Place models in `../LLMs/` relative to
the project root, or edit those lines directly.

## Running
```shell
dub                        # interactive session
dub -- "your prompt here"  # oneshot
```

## Things to Know Before Editing
- `check()` in `utils.d` calls `exit(1)` on null — `scope(exit)` handlers will not run on init failure
- RAG binary format is native-endian — `RAG.bin` is not portable across architectures
- The Docker image `dllm-python` is built once on first run; rebuild with `docker rmi dllm-python`
- `summary.generate()` and `agent.generate()` are different functions with different signatures
- `totalCPUs` from `std.parallelism` is used for thread counts — no manual tuning needed
