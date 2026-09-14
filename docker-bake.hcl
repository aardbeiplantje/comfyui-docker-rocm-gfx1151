group "default" {
  targets = ["local"]
}
group "release" {
  targets = ["containers"]
}
group "local" {
  targets = ["comfyui-local", "build-local-proxy"]
}
variable "DOCKER_REGISTRY" {
  default = "ghcr.io"
}
variable "DOCKER_REPOSITORY" {
  default = "ai"
}
variable "DOCKER_IMAGE_NAME" {
  default = "comfyui-gfx1151"
}
variable "DOCKER_TAG" {
  default = "latest"
}
target "_common" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  args = {
  }
  networks = ["host"]
  buildkit = true
}
target "build-local-proxy" {
  inherits = ["_common"]
  target = "proxy-runtime"
  tags = [
    "local/${DOCKER_REPOSITORY}/comfyui-proxy:${DOCKER_TAG}",
  ]
  output = [
    "type=docker,name=local/${DOCKER_REPOSITORY}/comfyui-proxy:${DOCKER_TAG}"
  ]
}
target "comfyui-local" {
  inherits = ["_common"]
  target = "comfyui-runtime"
  tags = [
    "local/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}",
  ]
  output = [
    "type=docker,name=local/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
  ]
}
target "containers" {
  inherits = ["_common"]
  pull = true
  name = "containers-${env}"
  matrix = {
    env = ["release"]
  }
  progress = ["plain", "tty"]
  tags = [
    "${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}",
  ]
  output = [
    "type=image,name=${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG},push=true"
  ]
  target = "runtime"
  buildkit = true
  attest = [
    "type=provenance,mode=max",
    "type=sbom",
  ]
}
