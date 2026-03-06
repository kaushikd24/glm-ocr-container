# vllm/vllm-openai has CUDA 12.4 + PyTorch pre-matched — no version roulette
FROM vllm/vllm-openai:latest

WORKDIR /workspace

# Install git (required for pip to clone from GitHub)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Fix LD_LIBRARY_PATH permanently so pip-bundled nvidia libs are always found
# (avoids libnvrtc-builtins missing errors across all RunPod instances)
RUN NVIDIA_LIB=$(python3 -c \
      "import nvidia.cuda_nvrtc, os; print(os.path.dirname(nvidia.cuda_nvrtc.__file__))" \
      2>/dev/null || echo "") && \
    echo "export LD_LIBRARY_PATH=${NVIDIA_LIB}/lib:/usr/local/cuda/lib64:/usr/local/nvidia/lib64:\$LD_LIBRARY_PATH" \
      >> /etc/profile.d/cuda_libs.sh && \
    chmod +x /etc/profile.d/cuda_libs.sh

ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64:/usr/local/nvidia/lib:$LD_LIBRARY_PATH

# Pre-create caches on /workspace (survives pod restarts, large volume)
RUN mkdir -p /workspace/.cache/huggingface \
             /workspace/.cache/pip \
             /root/.cache/huggingface

ENV HF_HOME=/workspace/.cache/huggingface \
    PIP_CACHE_DIR=/workspace/.cache/pip \
    TMPDIR=/workspace/tmp

RUN mkdir -p $TMPDIR

# Install GLM-OCR and its deps (vLLM already in base image)
RUN pip install --no-cache-dir \
    git+https://github.com/huggingface/transformers.git \
    pillow \
    pyyaml \
    uv

RUN git clone https://github.com/zai-org/glm-ocr.git /workspace/glm-ocr && \
    cd /workspace/glm-ocr && \
    pip install --no-cache-dir -e .

EXPOSE 8080

# Override entrypoint — prevents RunPod crash loop from auto-starting vLLM
# SSH in and run `vllm serve ...` manually when ready
ENTRYPOINT ["/bin/bash"]
