# ================================ Builder Stage ================================
ARG PYTHON_BASE_IMAGE="cmanne/fips-python-wolfi-amd64:3.12.9"
FROM $PYTHON_BASE_IMAGE AS builder

USER root

RUN unset LD_LIBRARY_PATH && \
    apk add --no-cache \
      glibc \
      libgcc \
      libstdc++ \
      bzip2 \
      bzip2-dev \
      curl \
      wget \
      ca-certificates \
      zlib \
      libffi \
      openssl

RUN wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run && \
    sh cuda_12.8.0_570.86.10_linux.run --silent --runtime && \
    rm cuda_12.8.0_570.86.10_linux.run || echo "CUDA runtime installation skipped (assuming present)"

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=$CUDA_HOME/bin:$PATH
ENV HOME=/root

RUN unset LD_LIBRARY_PATH && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    /root/.local/bin/uv --version && \
    echo "uv installed successfully" || (echo "Failed to install uv" && exit 1)

ENV PATH=/root/.local/bin:$PATH
ENV PATH=/opt/python-fips/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/ssl/lib:/opt/python-fips/lib

RUN uv pip install vllm==0.11.0 --system

WORKDIR /app

# Collect all .so* shared libraries (most robust: blanket copy)
RUN mkdir -p /tmp/all_libs && cp /usr/lib/*.so* /tmp/all_libs/ || true

# Collect all CUDA .so files (optional, still keep your logic)
RUN [ -d /usr/local/cuda ] && find /usr/local/cuda -type f -name "*.so*" > /tmp/cuda_libs.txt || touch /tmp/cuda_libs.txt

# ============================= Slim Minimal Stage ==============================
FROM $PYTHON_BASE_IMAGE AS slim

USER root
ENV HOME=/root
ENV CUDA_HOME=/usr/local/cuda

# Copy Python environment and user binaries
COPY --from=builder /opt/python-fips /opt/python-fips
COPY --from=builder /root/.local /root/.local

# Blanket copy ALL system .so* libraries to avoid missing shared libraries
COPY --from=builder /tmp/all_libs/*.so* /usr/lib/

# Copy ONLY found CUDA .so shared libraries (if any)
COPY --from=builder /tmp/cuda_libs.txt /tmp/cuda_libs.txt
RUN if [ -s /tmp/cuda_libs.txt ]; then \
      mkdir -p /usr/local/cuda/lib64 && \
      xargs -a /tmp/cuda_libs.txt -I '{}' cp '{}' /usr/local/cuda/lib64/ ; \
    else \
      echo "No CUDA libraries to copy, assuming runtime provides them" ; \
    fi

ENV PATH=/opt/python-fips/bin:/root/.local/bin:$CUDA_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/ssl/lib:/opt/python-fips/lib:/usr/local/cuda/lib64

WORKDIR /app

RUN ldconfig

ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]

