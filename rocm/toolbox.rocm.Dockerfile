ARG ROCM_VERSION="7.2.1"
ARG BASE_IMAGE="docker.io/rocm/dev-ubuntu-24.04:${ROCM_VERSION}-complete"
FROM ${BASE_IMAGE}

ARG ROCM_ARCH="gfx1201"
ARG ROCBLAS_REPO="https://github.com/ROCm/rocBLAS.git"
ARG TENSILE_REPO="https://github.com/ROCm/Tensile.git"
ARG RCCL_REPO="https://github.com/ROCm/rccl.git"
ARG RCCL_BRANCH=""

RUN apt-get update && apt-get install -y git cmake libfmt-dev dpkg rpm sudo libcap2-bin libnss-myhostname

# Extract ROCm Version Files
RUN ROCM_VERSION_MAJOR=$(ls /opt/ | sed -nE 's|rocm-([0-9]+)\.([0-9]+)\.([0-9]+)|\1|1p') && \
    ROCM_VERSION_MINOR=$(ls /opt/ | sed -nE 's|rocm-([0-9]+)\.([0-9]+)\.([0-9]+)|\2|1p') && \
    ROCM_VERSION_PATCH=$(ls /opt/ | sed -nE 's|rocm-([0-9]+)\.([0-9]+)\.([0-9]+)|\3|1p') && \
    echo "$ROCM_VERSION_MAJOR" > /opt/ROCM_VERSION_MAJOR && \
    echo "$ROCM_VERSION_MINOR" > /opt/ROCM_VERSION_MINOR && \
    echo "$ROCM_VERSION_PATCH" > /opt/ROCM_VERSION_PATCH && \
    echo "$ROCM_VERSION_MAJOR.$ROCM_VERSION_MINOR" > /opt/ROCM_VERSION && \
    echo "$ROCM_VERSION_MAJOR.$ROCM_VERSION_MINOR.$ROCM_VERSION_PATCH" > /opt/ROCM_VERSION_FULL && \
    echo "Detected rocm version is $(cat /opt/ROCM_VERSION_FULL)"

# Build rocBLAS
ENV PACKAGE_NAME=rocblas
WORKDIR /rebuild-deps
RUN git clone --depth 1 --branch rocm-$(cat /opt/ROCM_VERSION_FULL) ${ROCBLAS_REPO} rocBLAS && \
    git clone --depth 1 --branch rocm-$(cat /opt/ROCM_VERSION_FULL) ${TENSILE_REPO} Tensile && \
    true

WORKDIR /rebuild-deps/rocBLAS
RUN dpkg -s ${PACKAGE_NAME}
RUN ./install.sh --dependencies --rmake_invoked
RUN export INSTALLED_PACKAGE_VERSION=$(dpkg -s ${PACKAGE_NAME} | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    echo "Installed package version is \"$INSTALLED_PACKAGE_VERSION\"" && \
    export ROCM_LIBPATCH_VERSION=$(echo "$INSTALLED_PACKAGE_VERSION" | sed -E 's|^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)-(.*)|\4|1') && \
    echo "Set ROCM_LIBPATCH_VERSION to \"$ROCM_LIBPATCH_VERSION\"" && \
    export CPACK_DEBIAN_PACKAGE_RELEASE=$(echo "$INSTALLED_PACKAGE_VERSION" | sed -E 's|^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)-(.*)|\5|1') && \
    echo "Set CPACK_DEBIAN_PACKAGE_RELEASE to \"$CPACK_DEBIAN_PACKAGE_RELEASE\"" && \
    python3 ./rmake.py \
      --install_invoked \
      --build_dir=$(realpath ./build) \
      --src_path=$(realpath .) \
      --architecture ${ROCM_ARCH} \
      --test_local_path=$(realpath ../Tensile) && \
    cd ./build/release  && \
    make package && \
    mkdir -p /dist && cp *.deb /dist && \
    true
RUN cd ./build/release && \
    export INSTALLED_PACKAGE_VERSION=$(dpkg -s ${PACKAGE_NAME} | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    export BUILDED_PACKAGE_VERSION=$(dpkg -I /dist/${PACKAGE_NAME}_*.deb | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    if [ "$BUILDED_PACKAGE_VERSION" != "$INSTALLED_PACKAGE_VERSION" ]; then echo "ERR: Builded version is $BUILDED_PACKAGE_VERSION but expected $INSTALLED_PACKAGE_VERSION"; exit 10; fi && \
    dpkg -i /dist/*.deb && \
    true

# Build rccl
ENV PACKAGE_NAME=rccl
WORKDIR /rebuild-deps/rccl

RUN if [ -n "${RCCL_BRANCH}" ]; then \
        export TARGET_BRANCH="${RCCL_BRANCH}"; \
    else \
        export TARGET_BRANCH="rocm-$(cat /opt/ROCM_VERSION_FULL)"; \
    fi && \
    echo "Cloning RCCL from branch: ${TARGET_BRANCH}" && \
    git clone --depth 1 --branch "${TARGET_BRANCH}" ${RCCL_REPO} .
RUN dpkg -s ${PACKAGE_NAME}
RUN export INSTALLED_PACKAGE_VERSION=$(dpkg -s ${PACKAGE_NAME} | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    echo "Installed package version is \"$INSTALLED_PACKAGE_VERSION\"" && \
    export ROCM_LIBPATCH_VERSION=$(echo "$INSTALLED_PACKAGE_VERSION" | sed -E 's|^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)-(.*)|\4|1') && \
    echo "Set ROCM_LIBPATCH_VERSION to \"$ROCM_LIBPATCH_VERSION\"" && \
    export CPACK_DEBIAN_PACKAGE_RELEASE=$(echo "$INSTALLED_PACKAGE_VERSION" | sed -E 's|^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)-(.*)|\5|1') && \
    echo "Set CPACK_DEBIAN_PACKAGE_RELEASE to \"$CPACK_DEBIAN_PACKAGE_RELEASE\"" && \
    ./install.sh --package_build --amdgpu_targets ${ROCM_ARCH} && \
    mkdir -p /dist-rccl && cp ./build/release/*.deb /dist-rccl && \
    true

RUN cd ./build/release && \
    export INSTALLED_PACKAGE_VERSION=$(dpkg -s ${PACKAGE_NAME} | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    export BUILDED_PACKAGE_VERSION=$(dpkg -I /dist-rccl/${PACKAGE_NAME}_*.deb | sed -nE 's|^ *Version: (.+)$|\1|p') && \
    if [ "$BUILDED_PACKAGE_VERSION" != "$INSTALLED_PACKAGE_VERSION" ]; then \
        echo "WARN: Builded version is $BUILDED_PACKAGE_VERSION but expected $INSTALLED_PACKAGE_VERSION. Proceeding anyway since version might be pinned."; \
    fi && \
    dpkg -i /dist-rccl/*.deb && \
    true

# Toolbox Setup
WORKDIR /
LABEL com.github.containers.toolbox="true" \
      usage="This image is meant to be used with the toolbox command" \
      summary="Ubuntu ROCm toolbox"

RUN rm -rf /rebuild-deps && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/machine-id && touch /etc/machine-id \
    && userdel -r ubuntu || true \
    && sed -i 's/^hosts:.*/& myhostname/' /etc/nsswitch.conf
