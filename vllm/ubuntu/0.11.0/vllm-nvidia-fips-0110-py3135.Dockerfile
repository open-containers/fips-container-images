# Use FIPS-compliant Python as base image
ARG PYTHON_BASE_IMAGE="fips-python-3.13.5-ubuntu20-img"
FROM $PYTHON_BASE_IMAGE

USER root

# Install prerequisites for CUDA runtime and bz2 support (Ubuntu-based example)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libgcc1 \
    libbz2-1.0 \
    libbz2-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA 12.8 runtime (optional: skip if in your-fips-pytorch-image)
RUN wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run && \
    sh cuda_12.8.0_570.86.10_linux.run --silent --runtime && \
    rm cuda_12.8.0_570.86.10_linux.run || echo "CUDA runtime installation skipped (assuming present)"

# Set CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=$CUDA_HOME/bin:$PATH

# Set HOME explicitly
ENV HOME=/root

# Install uv and ensure it's available in /root/.local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    /root/.local/bin/uv --version && \
    echo "uv installed successfully" || (echo "Failed to install uv" && exit 1)

# Update PATH to include uv's installation directory
ENV PATH=/root/.local/bin:$PATH

# Update PATH for FIPS-compliant Python
ENV PATH=/usr/local/python-fips/bin:$PATH

# Install vLLM with uv, using --system to install globally
RUN uv pip install vllm==0.11.0 --system

# FIPS FIX: Patch vLLM to use SHA256 instead of MD5 (FIPS-compliant)
RUN sed -i 's/hashlib\.md5(/hashlib.sha256(/g' \
    /opt/python-fips/lib/python3.13/site-packages/vllm/model_executor/models/registry.py && \
    echo "✓ Patched vLLM registry.py for FIPS compliance (MD5 → SHA256)" && \
    grep -n "sha256" /opt/python-fips/lib/python3.13/site-packages/vllm/model_executor/models/registry.py

WORKDIR /app

ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
