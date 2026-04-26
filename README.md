# gfx1201 Base Toolboxes

This repository contains build scripts and Dockerfiles to create Podman/Distrobox compatible toolbox containers for AMD `gfx1201` (Radeon R9700 / RDNA 4) architecture.

## Configuration

All build parameters are centralized in `env.sh`. You can edit this file to configure:
- `ROCM_VERSION`: ROCm version to use (default: `7.2.1`)
- `ROCM_ARCH`: Target architecture (default: `gfx1201`). You can change this to `gfx1151` or others if necessary.
- `PYTHON_VERSION`: Python version for Torch build (default: `3.12`)
- `TORCH_BRANCH`: Branch/Tag of PyTorch to compile (default: `v2.7.1`)

## Building the Toolboxes

The build process is split into two stages. You must build the base ROCm toolbox first, as the PyTorch toolbox layers on top of it.

### 1. Build ROCm Toolbox

```bash
./rocm/build-toolbox.rocm.sh
```
This script pulls the official AMD dev image for the configured ROCm version and adds the necessary Fedora Toolbox labels, user cleanups, and dbus bindings to make it behave correctly inside a Distrobox/Toolbox environment. It will also automatically push to the registry specified in `env.sh`.

### 2. Build PyTorch Toolbox

```bash
./pytorch/build-toolbox.torch.sh
```
This script uses the ROCm toolbox built in step 1 as its base. It will clone the PyTorch, TorchAudio, and TorchVision repositories and compile them from source specifically targeting `gfx1201` to ensure maximum compatibility. It will also deploy the built toolbox to the configured registry.

**Note:** Compiling PyTorch natively can take a significant amount of time. You can control the build parallelism by setting `TORCH_MAX_JOBS` in `env.sh`.
