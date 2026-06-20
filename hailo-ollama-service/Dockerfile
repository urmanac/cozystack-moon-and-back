# Multi-stage build for HailoRT and Hailo-Ollama GenAI Server
# Target: linux/arm64 (Raspberry Pi 5 / CM5 with Hailo-10H)
#
# Stage 1: Build HailoRT v5.3.0 from source
FROM ubuntu:24.04 AS hailort-builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3-dev \
    python3-pip \
    libssl-dev \
    curl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --branch v5.3.0 --depth 1 https://github.com/hailo-ai/hailort.git /hailort

# Pre-fetch Eigen 3.4.0 (exact commit HailoRT expects) as a tarball.
# We use the Googlesource mirror since gitlab.com is unreachable from inside
# Docker Desktop's container network. This avoids FetchContent trying to clone
# from gitlab.com during cmake configure.
RUN mkdir -p /eigen-src && \
    curl -fSL \
      "https://chromium.googlesource.com/external/gitlab.com/libeigen/eigen/+archive/3147391d946bb4b6c68edd901f2add6ac1f31f8c.tar.gz" \
      -o /tmp/eigen.tar.gz && \
    tar -xzf /tmp/eigen.tar.gz -C /eigen-src && \
    rm /tmp/eigen.tar.gz

WORKDIR /hailort
# Point cmake at the pre-fetched eigen via FETCHCONTENT_SOURCE_DIR_EIGEN
# so it doesn't try to git-clone from gitlab.com.
# HAILO_BUILD_SERVICE=OFF skips the daemon (avoids extra systemd deps).
RUN cmake -S. -Bbuild \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAILO_BUILD_EXAMPLES=OFF \
    -DHAILO_BUILD_TESTS=OFF \
    -DHAILO_BUILD_SERVICE=OFF \
    -DFETCHCONTENT_SOURCE_DIR_EIGEN=/eigen-src
RUN cmake --build build --config Release -j$(nproc)
RUN cmake --install build --prefix /hailort-install

# Stage 2: Build Hailo-Ollama (hailo_model_zoo_genai) v5.3.0
# Depends only on HailoRT + OpenSSL (no OpenCV needed)
FROM ubuntu:24.04 AS hailo-ollama-builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the installed HailoRT artifacts from Stage 1
COPY --from=hailort-builder /hailort-install /usr/local

RUN git clone --branch v5.3.0 --depth 1 https://github.com/hailo-ai/hailo_model_zoo_genai.git /genai
WORKDIR /genai
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DHailoRT_DIR=/usr/local/lib/cmake/HailoRT
RUN cmake --build build --config Release -j$(nproc)
RUN cmake --install build --prefix /hailo-ollama-install

# Stage 3: Minimal production runtime image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    libssl3t64 \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the hailo-ollama binary
COPY --from=hailo-ollama-builder /hailo-ollama-install/bin/hailo-ollama /usr/local/bin/hailo-ollama

# Copy HailoRT shared library (libhailort.so.5.3.0)
COPY --from=hailort-builder /hailort-install/lib/libhailort.so* /usr/local/lib/

# Copy model manifests so hailo-ollama knows which models are available
COPY --from=hailo-ollama-builder /hailo-ollama-install/share /usr/local/share/

# Copy the JSON-sanitizing proxy (fixes newline-in-content bug in hailo-ollama v5.3.0)
COPY proxy.py /usr/local/bin/hailo-ollama-proxy

RUN ldconfig

# Models are stored under /root/.local/share/hailo-ollama/models in this runtime.
# Mount a volume there for persistence across restarts.
VOLUME ["/root/.local/share/hailo-ollama/models"]

# Entrypoint script: start hailo-ollama on :8000, proxy on :11434
RUN printf '#!/bin/sh\n\
hailo-ollama &\n\
HAILO_PID=$!\n\
python3 /usr/local/bin/hailo-ollama-proxy &\n\
PROXY_PID=$!\n\
trap "kill $HAILO_PID $PROXY_PID" INT TERM\n\
wait $HAILO_PID\n' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# :8000 = hailo-ollama (raw, Ollama-compatible)
# :11434 = proxy (JSON-sanitized, use this for claude-code-proxy / Tab Maestro)
EXPOSE 8000 11434

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

