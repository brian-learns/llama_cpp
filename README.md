# `llama_cpp`

## My personal build scripts for DGX Spark

```bash
cd $HOME
git clone https://github.com/brian-learns/llama_cpp.git
cd ./llama_cpp/
source llama_cpp_env
git clone https://github.com/ggml-org/llama.cpp.git src
./update.sh  # build the latest release tag
```

(install the systemd file) TODO: write instructions for this

## service layout when set up

```
~/llama_cpp/
├── presets.ini         # default and model configs for router mode
├── llama_cpp_env       # source this for environment
├── llama-cpp.service   # systemd
├── local
├── src
├── restart.sh          # util scripts
├── start.sh
├── stop.sh
├── test.sh             # run test suite for server (long)
├── install.sh          # install from ./src/build/ to ./local/
└── update.sh           # git the latest release tab and build in ./src/
```
