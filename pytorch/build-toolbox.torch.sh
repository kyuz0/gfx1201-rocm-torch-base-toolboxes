#!/bin/bash
set -e
set -o pipefail

cd $(dirname $0)/..
source ./env.sh

echo "=================================================="
echo ">>> Building PyTorch Toolbox from Source..."
echo "    PyTorch: ${TORCH_BRANCH}"
echo "    ROCm:    ${ROCM_VERSION}"
echo "    Arch:    ${ROCM_ARCH}"
echo "    Python:  ${PYTHON_VERSION}"
echo "    Target:  ${TORCH_TOOLBOX_TAG}"
echo "=================================================="

mkdir -p ./logs

podman build -t "${TORCH_TOOLBOX_TAG}" \
  --build-arg BASE_IMAGE="${ROCM_TOOLBOX_TAG}" \
  --build-arg ROCM_ARCH="${ROCM_ARCH}" \
  --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
  --build-arg PYTORCH_BRANCH="${TORCH_BRANCH}" \
  --build-arg PYTORCH_MAX_JOBS="${TORCH_MAX_JOBS}" \
  --build-arg PYTORCH_VISION_BRANCH="${TORCH_VISION_BRANCH}" \
  --build-arg PYTORCH_AUDIO_BRANCH="${TORCH_AUDIO_BRANCH}" \
  --target final \
  -f ./pytorch/toolbox.torch.Dockerfile ./pytorch \
  2>&1 | tee ./logs/build_torch_toolbox_$(date +%Y%m%d%H%M%S).log

echo ">>> Pushing ${TORCH_TOOLBOX_TAG} to Docker Hub..."
podman push "${TORCH_TOOLBOX_TAG}"

echo "Build and push complete!"
