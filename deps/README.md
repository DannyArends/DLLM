## DLLM - Compile llama.cpp ✨
Clone the repository
  * `git clone --recursive https://github.com/DannyArends/DImGui.git`
  * `git submodule update --init --recursive` (If already cloned)

Compile for MS Windows 11:
```
  call "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat" 
  cd deps/llama.cpp
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_OPENSSL=OFF ../
  msbuild llama.cpp.sln
```

Compile for Linux:
```
  cd deps/llama.cpp
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_OPENSSL=OFF -DBUILD_SHARED_LIBS=OFF ../
  make -j8
```

### Build with 🛠️
- **Visual Studio**: Build with [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
- **Cmake**: Build with [Cmake](https://cmake.org/download/)
