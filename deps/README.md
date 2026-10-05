## DLLM - Compile 🦙.cpp dependency ✨
Clone the repository
  * `git clone --recursive https://github.com/DannyArends/DImGui.git`
  * `git submodule update --init --recursive` (If already cloned)

Compile for MS Windows 11:
```
  call "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat" 
  cd deps/llama.cpp
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="120" -DGGML_CUDA_GRAPHS=ON -DGGML_CUDA_FA_ALL_QUANTS=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_OPENSSL=OFF -DGGML_CUDA_FA_ALL_QUANTS=ON -DGGML_NATIVE=ON ../
  cmake --build . --config Release -j10
```

Compile for Linux:
```
  cd deps/llama.cpp
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="75" -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_OPENSSL=OFF  -DGGML_CUDA_FA_ALL_QUANTS=ON -DGGML_NATIVE=ON -DBUILD_SHARED_LIBS=OFF ../
  cmake --build . --config Release -j10
```

Compile for macOS (Apple silicon, Metal):
```
  brew install ldc dub cmake
  cd deps/llama.cpp
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_OPENSSL=OFF -DBUILD_SHARED_LIBS=OFF -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=ON ../
  cmake --build . --config Release -j10
  cd ../../..
  dub build --config=osx --compiler=ldc2 --build=release
```
The static libraries DLLM links are built even if the umbrella `llama` app fails to link (it needs the server, which this build skips). Docker is optional on macOS: without it the runCode sandbox is disabled and everything else works. The playWAV tool uses `afplay`.

### Build with 🛠️
- **Visual Studio**: Build with [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
- **Cmake**: Build with [Cmake](https://cmake.org/download/)
