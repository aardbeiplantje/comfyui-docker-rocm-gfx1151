FROM debian AS pytorch-rocm-7.13-gfx1151-base

# Set up non-root user, note that 1000 works as most users have 1000
ENV LOGNAME=comfyui
ENV LOGNAME_UID=1000
ENV LOGNAME_GID=1000
RUN groupadd -g $LOGNAME_GID $LOGNAME
RUN useradd -N -M -d /$LOGNAME -u $LOGNAME_UID $LOGNAME
ENV HDIR=/$LOGNAME
RUN mkdir -p $HDIR && chown $LOGNAME:$LOGNAME $HDIR

# Install basic development tools and iptables/ipset
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
   curl \
   ca-certificates \
   gnupg2

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-pip-whl \
      python3-venv \
      python3-dev \
      python3-minimal \
      python3-requests \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_ROOT_USER_ACTION=ignore
ENV PATH=$HDIR/.local/bin:$PATH

# Python runtime: PyTorch, JAX, ROCm, and other ML development tools
RUN \
    --mount=target=/cache,type=cache,uid=0 \
    XDG_CACHE_HOME=/cache \
    python3 -m pip install --prefer-binary --upgrade \
        --extra-index-url https://repo.amd.com/rocm/whl/gfx1151/ \
        "rocm[libraries,devel]" \
        torch \
        torchvision \
        torchaudio \
        "jax_rocm7_plugin==0.9.1+rocm7.13.0" \
        "jax_rocm7_pjrt==0.9.1+rocm7.13.0" \
        "triton==3.6.0+rocm7.13.0" \
        tf-keras \
        "jax==0.9.1" \
        "jaxlib==0.9.1" \
        https://rocm.frameworks.amd.com/whl/gfx1151/flash_attn-2.8.3-py3-none-any.whl \
    && rm -rf /usr/local/lib/python3*/dist-packages/rocm_sdk_devel/_*.tar

# extra deps for ROCm
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libatomic1 \
    glslc \
    glslang-tools \
    vulkan-tools \
    libvulkan-dev \
    spirv-headers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY e.sh /
ENTRYPOINT ["/e.sh"]

FROM pytorch-rocm-7.13-gfx1151-base AS runtime
