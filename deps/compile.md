call "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat" 
cd deps/llama.cpp
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DLLAMA_OPENSSL=OFF ../
msbuild llama.cpp.sln