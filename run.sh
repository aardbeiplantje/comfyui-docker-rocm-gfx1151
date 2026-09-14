#!/bin/bash
#
DOCKER_IMAGE=${DOCKER_IMAGE:-local/ai/comfyui-gfx1151:latest}
D=comfyui-$LOGNAME

export MODELS_DIR HF_TOKEN

# Now run
exec docker run \
    --rm \
    -i \
    --name $D \
    --network=host \
    --ulimit memlock=-1:-1 \
    --ulimit stack=67108864:67108864 \
    --group-add=video \
    --group-add=992 \
    --ipc=host \
    --cap-add=SYS_PTRACE \
    --cap-add=SYS_ADMIN \
    --security-opt seccomp=unconfined \
    --device /dev/kfd \
    --device /dev/dri \
    --tmpfs /tmp:rw,suid,exec,size=1G \
    --tmpfs /var/tmp:rw,suid,exec,size=1G \
    --tmpfs /comfyui/.config/ComfyUI:exec,size=512M \
    $([ -n "$HF_HOME"    ] && echo "-v $HF_HOME:/hf:rw") \
    -v ${MODELS_DIR:-comfyui-data-$LOGNAME}:/comfyui-data:rw \
    -v ${WORKSPACE:-comfyui-workspace-$LOGNAME}:/comfyui/workspace:rw \
    -v ${ROCM_PATH:-/opt/rocm}:/opt/rocm:ro \
    -e HF_HOME=${HF_HOME:-/hf} \
    -e HF_TOKEN \
    -e HF_HUB_CACHE=${HF_HUB_CACHE:-/hf/hub} \
    -e HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-11.5.1} \
    -e GGML_CUDA_ENABLE_UNIFIED_MEMORY=${GGML_CUDA_ENABLE_UNIFIED_MEMORY:-1} \
    -e GGML_HIP_FORCE_RS_GPU=${GGML_HIP_FORCE_RS_GPU:-1} \
    -e GGML_HIP_FORCE_KV_GPU=${GGML_HIP_FORCE_KV_GPU:-1} \
    -e GGML_HIP_ALLOC_GRAPH_RESERVE=${GGML_HIP_ALLOC_GRAPH_RESERVE:-2048} \
    -e HSA_FORCE_FINE_GRAIN_PCIE=${HSA_FORCE_FINE_GRAIN_PCIE:-1} \
    -e HSA_ENABLE_SDMA=${HSA_ENABLE_SDMA:-0} \
    $DOCKER_OPTS \
        $DOCKER_IMAGE \
            "$@"
