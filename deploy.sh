#!/bin/bash
export APP_NAME=${APP_NAME:-comfyui}
export DOMAIN=${APP_DOMAIN?Need APP_DOMAIN}
export CERT_VOLUME=${APP_CERT_VOLUME:-certs-$APP_NAME}
export DOCKER_IMAGE=${DOCKER_IMAGE:-local/ai/comfyui-gfx1151:latest}
export MODELS_DIR
export WORKSPACE
export ROCM_PATH
export HF_HOME
export HF_TOKEN

HERE=$(readlink -f $BASH_SOURCE)
HERE=${HERE%/*}
cd $HERE || exit $?

echo "using: $APP_NAME"

export IPV6_SUBNET=${IPV6_SUBNET?Need IPV6_SUBNET (e.g. 2001:db8:c::1:0/120)}
export IPV6_GATEWAY=${IPV6_GATEWAY?Need IPV6_GATEWAY (e.g. 2001:db8:c::1:1)}
if [ -z "$IPV6_ADDRESS" ]; then
    IPV6=$(dig -6 $DOMAIN -t AAAA +short +retry=0 +tries=1)
    if [ $? != 0 -o -z "$IPV6" ]; then
        echo -ne "problem looking up $DOMAIN\n"
        exit 1
    fi
    export IPV6_ADDRESS=${IPV6_ADDRESS:-$IPV6}
fi

if [ "${APP_DO_CERTBOT:-0}" -eq 1 ]; then
    echo "checking for certificate"
    echo "running certbot"
    export APP_CERTBOT_MAIL=${APP_CERTBOT_MAIL?Need APP_CERTBOT_MAIL}
    docker compose down
    docker network rm dmz-${APP_NAME}-ipv6 2>/dev/null || true
    docker network create \
        --driver bridge \
        --ipv6 \
        --ipam-driver default \
        --subnet "$IPV6_SUBNET" \
        --gateway "$IPV6_GATEWAY" \
        --opt com.docker.network.bridge.gateway_mode_ipv6="routed" \
        --opt com.docker.network.container_iface_prefix="dmz" \
        --opt com.docker.network.bridge.enable_icc="true" \
        --opt com.docker.network.bridge.enable_ip_masquerade="false" \
        --opt com.docker.network.bridge.enable_ip6_masquerade="false" \
        --opt com.docker.network.bridge.inhibit_ipv4="true" \
        --opt com.docker.network.driver.mtu="1500" \
        dmz-${APP_NAME}-ipv6 || true
    docker rm -f certbot_$APP_NAME 2>/dev/null || true
    docker run \
        -p 80:80 \
        --pull=always \
        --rm \
        -e CERTBOT_MAIL="$APP_CERTBOT_MAIL" \
        --network dmz-${APP_NAME}-ipv6 \
        --ip6 $IPV6 \
        --name certbot_$APP_NAME \
        -v ${CERT_VOLUME}:/certs:rw \
        ghcr.io/aardbeiplantje/certbot/certbot:${APP_CERTBOT_TAG:-latest} \
            certonly \
                --agree-tos \
                --force-renewal \
                --domains "$DOMAIN" || exit $?
else
    echo "no certbot"
fi

export DOCKER_REGISTRY=local
export DOCKER_REPOSITORY=ai

echo "building images with buildx bake"
docker buildx bake -f docker-bake.hcl local || exit $?

echo "starting with docker compose"
exec docker compose up -d
