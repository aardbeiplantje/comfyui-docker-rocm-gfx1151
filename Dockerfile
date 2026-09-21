FROM alpine:latest AS proxy-runtime
RUN apk add --no-cache \
    nginx \
    nginx-mod-http-auth-jwt \
    nginx-mod-http-headers-more \
    nginx-mod-http-lua \
    nginx-mod-http-perl \
    perl-uri \
    perl-json \
    perl-json-xs \
    curl
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./nginx.sh /nginx.sh
RUN ln -s /certs/ /etc/nginx/certs
RUN <<EOngxtest
    PERL5LIB=""
    PERL5LIB=$PERL5LIB:/usr/lib/perl5/vendor_perl/armv8l-linux-thread-multi-64int
    PERL5LIB=$PERL5LIB:/usr/lib/perl5/vendor_perl/x86_64-linux-thread-multi
    export PERL5LIB
    nginx -t -c /etc/nginx/nginx.conf
    err=$?
    exit $err
EOngxtest
RUN mkdir -p /var/lib/nginx/logs/ && chown -R nginx:nginx /var/lib/nginx/logs/
RUN mkdir -p /run/nginx/ && chown -R nginx:nginx /run/nginx/
USER nginx
ENTRYPOINT ["/nginx.sh"]

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
        torchsde \
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
    spirv-headers

ENTRYPOINT ["bash"]

FROM pytorch-rocm-7.13-gfx1151-base AS comfyui-runtime

ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_ROOT_USER_ACTION=ignore
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
       apt-get remove python3-requests -y \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
       git \
       iproute2
RUN echo "flash_attn" > constraints.txt
RUN \
    --mount=target=/cache,type=cache,uid=0 \
    XDG_CACHE_HOME=/cache \
    python3 -m pip install --prefer-binary --upgrade \
        --constraint constraints.txt \
        comfy-cli \
        'comfy_aimdo>=0.5.5' \
        comfy-script \
        nest-asyncio2 \
        gradio \
        comfyui-manager \
        matrix-nio \
        comfyui-frontend-package==1.52.7 \
        comfyui-workflow-templates==0.11.59 \
        comfyui-embedded-docs==0.5.11 \
        'numpy>=1.25.0' \
        einops \
        'transformers>=4.50.3' \
        'tokenizers>=0.13.3' \
        sentencepiece \
        'safetensors>=0.4.2' \
        'aiohttp>=3.11.8' \
        'yarl>=1.18.0' \
        pyyaml \
        Pillow \
        scipy \
        tqdm \
        psutil \
        alembic \
        'SQLAlchemy>=2.0.0' \
        filelock \
        'av>=17.0.0' \
        comfy-kitchen==0.2.33 \
        requests \
        'simpleeval>=1.0.0' \
        blake3 \
        'kornia>=0.7.1' \
        'spandrel' \
        pydantic~=2.0 \
        pydantic-settings~=2.0 \
        'PyOpenGL>=3.1.8' \
        comfy-angle \
        PyOpenGL-accelerate

ENV PYTHONPATH=/usr/local/lib/python3.13/dist-packages
RUN python3 -c "import comfy_aimdo.storage"

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
       apt-get remove python3-requests -y \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        gcc \
        g++ \
        cmake \
        make

RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI /ComfyUI
ENV HDIR=/$LOGNAME
RUN ln -s /ComfyUI $HDIR/ComfyUI
RUN mkdir -p /comfyui-data && ln -s /comfyui-data $HDIR/comfyui-data && chown comfyui:comfyui /comfyui-data
RUN mkdir -p /comfyui-user && ln -s /comfyui-user $HDIR/comfyui-user && chown comfyui:comfyui /comfyui-user
RUN cp -a /ComfyUI/custom_nodes / \
    && chown -R comfyui:comfyui /custom_nodes \
    && rm -rf /ComfyUI/custom_nodes \
    && mkdir -p /ComfyUI/custom_nodes \
    && chown comfyui:comfyui /ComfyUI/custom_nodes
RUN cp /ComfyUI/requirements.txt / && sed -i '/torch/s/^/#/' requirements.txt
RUN \
    --mount=target=/cache,type=cache,uid=0 \
    XDG_CACHE_HOME=/cache \
    python3 -m pip install --prefer-binary --upgrade \
        -r requirements.txt
ENV PYTHONPATH=/usr/local/lib/python3.13/dist-packages
RUN python3 -c "import comfy_aimdo.storage"
RUN chown -R comfyui:comfyui /ComfyUI
RUN getent group video || groupadd -g 44 video && \
    getent group render || groupadd -g 992 render || true && \
    usermod -aG video,render comfyui || true
RUN echo "precedence ::ffff:0:0/96  100" > /etc/gai.conf
COPY comfyui.yml $HDIR/.comfyui.yml
ENV XDG_CACHE_HOME=/var/tmp/
COPY comfyui.sh /
ENTRYPOINT ["/comfyui.sh"]
