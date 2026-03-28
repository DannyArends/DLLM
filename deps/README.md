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

### Build with 🛠️
- **Visual Studio**: Build with [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
- **Cmake**: Build with [Cmake](https://cmake.org/download/)
