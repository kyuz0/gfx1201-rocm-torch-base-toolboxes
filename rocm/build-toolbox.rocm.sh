#!/bin/bash
set -e

cd $(dirname $0)/..
source ./env.sh

mkdir -p ./logs

echo "=================================================="
echo ">>> Building ROCm Toolbox..."
echo "    ROCm:    ${ROCM_VERSION}"
echo "    Arch:    ${ROCM_ARCH}"
echo "    Target:  ${ROCM_TOOLBOX_TAG}"
echo "=================================================="

# Fallback for underlying AMD base image if not previously set
BASE_ROCM_IMAGE="docker.io/rocm/dev-ubuntu-24.04:${ROCM_VERSION}-complete"

podman build -t "${ROCM_TOOLBOX_TAG}" \
  --build-arg BASE_IMAGE="${BASE_ROCM_IMAGE}" \
  --build-arg ROCM_ARCH="${ROCM_ARCH}" \
  --build-arg ROCM_VERSION="${ROCM_VERSION}" \
  -f ./rocm/toolbox.rocm.Dockerfile ./rocm 2>&1 | tee ./logs/build_rocm_toolbox_$(date +%Y%m%d%H%M%S).log

echo ">>> Pushing ${ROCM_TOOLBOX_TAG}... "
podman push "${ROCM_TOOLBOX_TAG}"

echo "Done!"
