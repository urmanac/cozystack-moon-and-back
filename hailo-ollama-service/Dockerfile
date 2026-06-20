# Multi-stage build for HailoRT and Hailo-Ollama GenAI Server
# Target: linux/arm64 (Raspberry Pi 5 / CM5 with Hailo-10H)
#
# Stage 1: Build HailoRT v5.3.0 from source
# This produces libhailort.so and the cmake config files needed by hailo-ollama.
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
WORKDIR /hailort
# HAILO_BUILD_SERVICE=OFF avoids building the hailort daemon which has extra deps
RUN cmake -S. -Bbuild \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAILO_BUILD_EXAMPLES=OFF \
    -DHAILO_BUILD_TESTS=OFF \
    -DHAILO_BUILD_SERVICE=OFF
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
    && rm -rf /var/lib/apt/lists/*

# Copy the hailo-ollama binary
COPY --from=hailo-ollama-builder /hailo-ollama-install/bin/hailo-ollama /usr/local/bin/hailo-ollama

# Copy HailoRT shared library (libhailort.so.5.3.0)
COPY --from=hailort-builder /hailort-install/lib/libhailort.so* /usr/local/lib/

# Copy model manifests so hailo-ollama knows which models are available
# The server fetches actual .hef files on first pull
COPY --from=hailo-ollama-builder /hailo-ollama-install/share /usr/local/share/

RUN ldconfig

# Models are stored in /root/.ollama by default; mount a volume for persistence
VOLUME ["/root/.ollama"]

# Expose Ollama-compatible API port
EXPOSE 8000

ENTRYPOINT ["hailo-ollama"]
