# CUDA + PyTorch already matched for vLLM
FROM vllm/vllm-openai:latest

WORKDIR /workspace

# allow pip to override distutils packages in CUDA images
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# install git (needed for cloning repos)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# upgrade pip early
RUN python3 -m pip install --upgrade pip

# fix nvrtc library path (avoids CUDA runtime errors)
RUN NVIDIA_LIB=$(python3 -c \
      "import nvidia.cuda_nvrtc, os; print(os.path.dirname(nvidia.cuda_nvrtc.__file__))" \
      2>/dev/null || echo "") && \
    echo "export LD_LIBRARY_PATH=${NVIDIA_LIB}/lib:/usr/local/cuda/lib64:/usr/local/nvidia/lib64:\$LD_LIBRARY_PATH" \
      >> /etc/profile.d/cuda_libs.sh && \
    chmod +x /etc/profile.d/cuda_libs.sh

ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib64:/usr/local/nvidia/lib:$LD_LIBRARY_PATH

# create persistent caches
RUN mkdir -p /workspace/.cache/huggingface \
             /workspace/.cache/pip \
             /workspace/tmp \
             /root/.cache/huggingface

ENV HF_HOME=/workspace/.cache/huggingface \
    PIP_CACHE_DIR=/workspace/.cache/pip \
    TMPDIR=/workspace/tmp

# install dependencies
RUN pip install --no-cache-dir \
    transformers \
    pillow \
    pyyaml \
    uv

# install GLM-OCR
RUN git clone https://github.com/zai-org/glm-ocr.git /workspace/glm-ocr && \
    cd /workspace/glm-ocr && \
    pip install --no-cache-dir --ignore-installed -e .

EXPOSE 8080

# Keep container alive without a TTY — prevents RunPod restart loop
# SSH in and run `vllm serve ...` manually when ready
ENTRYPOINT ["/bin/bash", "-c", "tail -f /dev/null"]