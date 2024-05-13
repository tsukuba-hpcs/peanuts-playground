FROM mcr.microsoft.com/devcontainers/cpp:1-debian-12

ARG REINSTALL_CMAKE_VERSION_FROM_SOURCE="3.22.2"
ARG SPACK_CHECKOUT=12e3665df37ddf0839e808ff415c011507eccf22
ENV SPACK_ROOT=/home/vscode/.cache/spack
ENV CPM_SOURCE_CACHE=/home/vscode/.cache/CPM

# Optionally install the cmake for vcpkg
COPY ./reinstall-cmake.sh /tmp/

RUN if [ "${REINSTALL_CMAKE_VERSION_FROM_SOURCE}" != "none" ]; then \
        chmod +x /tmp/reinstall-cmake.sh && /tmp/reinstall-cmake.sh ${REINSTALL_CMAKE_VERSION_FROM_SOURCE}; \
    fi \
    && rm -f /tmp/reinstall-cmake.sh

RUN \
  # Common packages
  export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ssh \
    less \
    tree \
    git \
    vim \
    make \
    apt-file \
  # locale
  && apt-get install -y --no-install-recommends \
    locales \
  && sed -i -E 's/# (en_US.UTF-8)/\1/' /etc/locale.gen \
  && locale-gen \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV EDITOR vim

RUN \
  # sshd
  export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    openssh-server \
  # sshd_config
  && printf '%s\n' \
    'PasswordAuthentication yes' \
    'PermitEmptyPasswords yes' \
    'UsePAM no' \
    > /etc/ssh/sshd_config.d/auth.conf \
  # ssh_config
  && printf '%s\n' \
    'Host *' \
    '    StrictHostKeyChecking no' \
    > /etc/ssh/ssh_config.d/ignore-host-key.conf \
  # delete passwd
  && passwd -d vscode \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN \
  # Common packages
  export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    pkg-config \
    vim \
    bash-completion \
    gfortran \
    clang \
    clang-format \
    clang-tidy \
    clang-tools \
    cmake-format \
    iwyu \
    tree \
    file \
    environment-modules \
    libtbb-dev \
    flex \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-c"]
COPY spack.sh /etc/profile.d/03-spack.sh

USER vscode
RUN \
  # spack
  git clone -c feature.manyFiles=true https://github.com/spack/spack.git "${SPACK_ROOT}" \
  && cd "${SPACK_ROOT}" \
  && git checkout "${SPACK_CHECKOUT}" \
  && mkdir -p /home/vscode/.spack

USER root
RUN \
  # additinal packages
  export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    perl \
    python3-venv \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*
