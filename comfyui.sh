#!/bin/bash
export TMPDIR=${TMPDIR:-/tmp}
export PYTHONPYCACHEPREFIX="$TMPDIR/comfyui-pycache-$LOGNAME/"
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PIP_ROOT_USER_ACTION=ignore
export PYTHONUSERBASE=/comfyui-user/.local
export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python3.13/dist-packages
export PATH=$PYTHONUSERBASE/bin:$PATH
export ROCM_PATH=${ROCM_PATH:-/opt/rocm}
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${ROCM_PATH}/lib
export HF_HOME=${HF_HOME:-/hf}
export HF_TOKEN=${HF_TOKEN-}
export HF_HUB_CACHE=${HF_HUB_CACHE:-/hf/hub}
export HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-11.5.1}
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=${GGML_CUDA_ENABLE_UNIFIED_MEMORY:-1}
export GGML_HIP_FORCE_RS_GPU=${GGML_HIP_FORCE_RS_GPU:-1}
export GGML_HIP_FORCE_KV_GPU=${GGML_HIP_FORCE_KV_GPU:-1}
export HSA_FORCE_FINE_GRAIN_PCIE=${HSA_FORCE_FINE_GRAIN_PCIE:-1}
export HSA_ENABLE_SDMA=${HSA_ENABLE_SDMA:-0}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-4}
export TORCH_NUM_THREADS=${TORCH_NUM_THREADS:-4}
export FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
if [ "$1" = "" ]; then
    set -- bash -i
fi
if [ "$1" = "comfyui" ]; then
    id
    mkdir -p /comfyui-data/custom_nodes
    chown comfyui:users /comfyui-user/custom_nodes
    cp -p /custom_nodes/* /comfyui-user/custom_nodes/
    exec su comfyui /bin/bash -c "\
        mkdir -p ~/comfyui-user
        cat << 'EOF' > ~/comfyui-user/__manager/config.ini
[default]
security_level = weak
network_mode = personal_cloud
EOF
        set -eou pipefail
        exec /usr/bin/python3 ~/ComfyUI/main.py \
            --listen 0.0.0.0 \
            --port 8188 \
            --user-directory ~/comfyui-user \
            --extra-model-paths-config ~/.comfyui.yml \
            --temp-directory ${TMPDIR}/comfyui-scratch-\$LOGNAME \
            --input-directory ~/workspace \
            --output-directory ~/workspace \
            --mmap-torch-files \
            --high-ram \
            --disable-async-offload \
            --enable-dynamic-vram \
            --vram-headroom 1 \
            --gpu-only \
            --fast-disk \
            --enable-manager \
            --enable-manager-legacy-ui \
            --enable-assets \
            --enable-asset-hashing"
fi
exec "$@"
