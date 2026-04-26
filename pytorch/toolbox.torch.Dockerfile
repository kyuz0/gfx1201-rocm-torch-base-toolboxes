ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS build_base

ARG PYTHON_VERSION="3.12"
ENV PYTHON_VERSION=$PYTHON_VERSION

RUN apt-get update && apt-get install -y software-properties-common git python3-pip && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update -y && \
    apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-lib2to3 python-is-python3 python${PYTHON_VERSION}-full && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --set python3 /usr/bin/python${PYTHON_VERSION} && \
    ln -sf /usr/bin/python${PYTHON_VERSION}-config /usr/bin/python3-config && \
    python3 -m pip config set global.break-system-packages true && \
    true

# Set environment variables
ARG ROCM_ARCH="gfx1201"
ENV ROCM_ARCH=$ROCM_ARCH
ENV PYTORCH_ROCM_ARCH=$ROCM_ARCH
ENV PATH=/opt/rocm/llvm/bin:$PATH
ENV ROCM_PATH=/opt/rocm
ENV LD_LIBRARY_PATH=/opt/rocm/lib:/usr/local/lib:
ENV USE_ROCM=1
ENV USE_FLASH_ATTENTION=1
ENV USE_MEM_EFF_ATTENTION=1
ENV BUILD_TEST=0

############# Build torch #############
FROM build_base AS build_torch
RUN pip install            \
      'setuptools<=81.0.0' \
      'setuptools_scm'     \
      'wheel'              \
      'packaging'          \
      'cmake'              \
      'ninja'              \
      'jinja2'             \
      'psutil'             

WORKDIR /build/pytorch
ARG PYTORCH_REPO="https://github.com/pytorch/pytorch.git"
ARG PYTORCH_BRANCH="v2.7.1"
RUN git clone --depth 1 --recurse-submodules --shallow-submodules --jobs 4 --branch "${PYTORCH_BRANCH}" "${PYTORCH_REPO}" .
RUN pip install -r requirements.txt
RUN python3 tools/amd_build/build_amd.py
ARG PYTORCH_MAX_JOBS
RUN MAX_JOBS=${PYTORCH_MAX_JOBS:-$(nproc)} \
    CMAKE_PREFIX_PATH=$(python3 -c 'import sys; print(sys.prefix)') \
    python3 setup.py bdist_wheel --dist-dir=/dist
RUN pip install /dist/*.whl

############# Build vision #############
FROM build_torch AS build_vision
WORKDIR /build/vision
ARG PYTORCH_VISION_REPO="https://github.com/pytorch/vision.git"
ARG PYTORCH_VISION_BRANCH=""
RUN if [ "${PYTORCH_VISION_BRANCH}" = "" ]; then \
      git clone --depth 1 --recurse-submodules --shallow-submodules --jobs 4 "${PYTORCH_VISION_REPO}" . && \
      git fetch --depth=1 origin "$(cat /build/pytorch/.github/ci_commit_pins/vision.txt)" && \ 
      git checkout "$(cat /build/pytorch/.github/ci_commit_pins/vision.txt)" && \
      git reset --hard FETCH_HEAD; \
    else \
      git clone --depth 1 --recurse-submodules --shallow-submodules --jobs 4 --branch "${PYTORCH_VISION_BRANCH}" "${PYTORCH_VISION_REPO}" . ; \
    fi
RUN pip install 'setuptools<=81.0.0'
RUN python3 setup.py bdist_wheel --dist-dir=/dist
RUN pip install /dist/*.whl

############# Build audio #############
FROM build_torch AS build_audio
WORKDIR /build/audio
ARG PYTORCH_AUDIO_REPO="https://github.com/pytorch/audio.git"
ARG PYTORCH_AUDIO_BRANCH=""
RUN if [ "${PYTORCH_AUDIO_BRANCH}" = "" ]; then \
      git clone --depth 1 --recurse-submodules --shallow-submodules --jobs 4 "${PYTORCH_AUDIO_REPO}" . && \
      git fetch --depth=1 origin "$(cat /build/pytorch/.github/ci_commit_pins/audio.txt)" && \ 
      git checkout "$(cat /build/pytorch/.github/ci_commit_pins/audio.txt)" && \
      git reset --hard FETCH_HEAD; \
    else \
      git clone --depth 1 --recurse-submodules --shallow-submodules --jobs 4 --branch "${PYTORCH_AUDIO_BRANCH}" "${PYTORCH_AUDIO_REPO}" . ; \
    fi
RUN pip install 'setuptools<=81.0.0'
RUN python3 setup.py bdist_wheel --dist-dir=/dist
RUN pip install /dist/*.whl

############# Install all #############
FROM build_base AS final
RUN --mount=type=bind,from=build_torch,src=/dist/,target=/dist_torch \
    --mount=type=bind,from=build_vision,src=/dist/,target=/dist_vision \
    --mount=type=bind,from=build_audio,src=/dist/,target=/dist_audio \
    pip install /opt/rocm/share/amd_smi /dist_torch/*.whl /dist_vision/torchvision-*.whl /dist_audio/torchaudio-*.whl && \
    true

CMD ["/bin/bash"]
