FROM docker.io/ubuntu:18.04 AS emscripten

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		build-essential \
		cmake \
		curl \
		git \
		libtool \
		nano \
		openjdk-8-jdk \
		openssh-client \
		pkgconf \
		python \
		python-pip \
	&& rm -rf /var/lib/apt/lists/*

# Create emscripten user and group
ARG EMSCRIPTEN_USER_UID=1000
ARG EMSCRIPTEN_USER_GID=1000
RUN groupadd \
		--gid "${EMSCRIPTEN_USER_GID:?}" \
		emscripten
RUN useradd \
		--uid "${EMSCRIPTEN_USER_UID:?}" \
		--gid "${EMSCRIPTEN_USER_GID:?}" \
		--shell "$(command -v bash)" \
		--home-dir /home/emscripten/ \
		--create-home \
		emscripten

# Drop root privileges
USER emscripten:emscripten

# Install Emscripten from source
ENV EMSDK=/home/emscripten/.emsdk
ARG EMSDK_TREEISH=master
ARG EMSDK_REMOTE=https://github.com/emscripten-core/emsdk.git
RUN mkdir "${EMSDK:?}"
RUN cd "${EMSDK:?}" \
	&& git clone "${EMSDK_REMOTE:?}" ./ \
	&& git checkout "${EMSDK_TREEISH:?}" \
	&& git submodule update --init --recursive
RUN cd "${EMSDK:?}" \
	&& ./emsdk install --build=Release sdk-incoming-64bit binaryen-master-64bit clang-incoming-64bit \
	&& ./emsdk activate --build=Release sdk-incoming-64bit binaryen-master-64bit clang-incoming-64bit \
	&& ./emsdk construct_env

# Install Rust precompiled binaries
ENV RUSTUP_HOME=/home/emscripten/.rustup
ENV CARGO_HOME=/home/emscripten/.cargo
RUN mkdir "${RUSTUP_HOME:?}" "${CARGO_HOME:?}"
RUN curl -sSfL 'https://sh.rustup.rs' | sh -s -- -y

# Install Wasmer precompiled binaries
ENV WASMER_DIR=/home/emscripten/.wasmer
RUN mkdir "${WASMER_DIR:?}"
RUN curl -sSfL 'https://get.wasmer.io' | sh

# Enable environments
ENV BASH_ENV=/home/emscripten/.bashenv
RUN printf '%s\n' '. ${EMSDK:?}/emsdk_set_env.sh' >> "${BASH_ENV:?}"
RUN printf '%s\n' '. ${CARGO_HOME:?}/env' >> "${BASH_ENV:?}"
RUN printf '%s\n' '. ${WASMER_DIR:?}/wasmer.sh' >> "${BASH_ENV:?}"
RUN printf '%s\n' '. ${BASH_ENV:?}' >> ~/.bashrc
SHELL ["/bin/bash", "-c"]

# Pre-generate all Emscripten system libraries
RUN embuilder.py build ALL

WORKDIR /home/emscripten/
CMD ["/bin/bash"]
