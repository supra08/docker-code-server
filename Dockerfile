FROM ghcr.io/linuxserver/baseimage-ubuntu:jammy

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE=4.21.0
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config"

# add Android SDK dependencies
ENV SDK_VERSION=commandlinetools-linux-8512546_latest \
    ANDROID_BUILD_TOOLS_VERSION=33.0.0 \
    ANDROID_SDK_ROOT=/usr/lib/android-sdk

RUN apt-get -y update && \
    apt-get install -y zip \
    unzip \
    curl \
    wget \
    git \
    rsync \
    sshpass

RUN apt install -y ca-certificates-java
RUN apt-get install -y \
    openjdk-17-jdk \
    openjdk-11-jdk \ 
    openjdk-8-jdk

# # Install Java 21 LTS
# RUN wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb && \
#     apt install -y /jdk-21_linux-x64_bin.deb

# # Install Java 20
# RUN wget https://download.oracle.com/java/20/archive/jdk-20.0.2_linux-x64_bin.deb && \
#     apt install -y /jdk-20.0.2_linux-x64_bin.deb

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

ENV ANDROID_DOWNLOAD_PATH=/config \
    ANDROID_HOME=/config/android \
    ANDROID_TOOL_HOME=/config/android/cmdline-tools

RUN echo "abc ALL=\(root\)) NOPASSWD:ALL" >> /etc/sudoers &&\
    chown abc:abc /config && mkdir -p ${ANDROID_TOOL_HOME} &&\
    chown abc:abc /config/android &&\
    chmod a+x -R ${ANDROID_DOWNLOAD_PATH} && \
    chown -R abc:abc ${ANDROID_DOWNLOAD_PATH}

# install flutter dependencies
RUN sh -c 'curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -' && \
    sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list' && \
    apt-get update && apt-get install -y dart

# Install FVM
RUN /usr/bin/dart pub global activate fvm && cp /config/.pub-cache/bin/fvm /usr/bin/fvm

RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    jq \
    libatomic1 \
    nano \
    net-tools \
    netcat && \
    # sudo && \
  echo "**** install code-server ****" && \
  if [ -z ${CODE_RELEASE+x} ]; then \
    CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
      | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
  fi && \
  mkdir -p /app/code-server && \
  curl -o \
    /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
  tar xf /tmp/code-server.tar.gz -C \
    /app/code-server --strip-components=1 && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /config/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

USER abc

WORKDIR /config

RUN wget -O tools.zip https://dl.google.com/android/repository/${SDK_VERSION}.zip && \
    unzip tools.zip && rm tools.zip && \
    # chmod a+x -R ${ANDROID_DOWNLOAD_PATH} && \
    # chown -R abc:abc ${ANDROID_DOWNLOAD_PATH} && \
    mv cmdline-tools ${ANDROID_TOOL_HOME}/tools

ENV PATH=$PATH:${ANDROID_TOOL_HOME}/tools:${ANDROID_TOOL_HOME}/tools/bin

# https://askubuntu.com/questions/885658/android-sdk-repositories-cfg-could-not-be-loaded
RUN mkdir -p ~/.android && \
    touch ~/.android/repositories.cfg && \
    echo y | sdkmanager "platform-tools" && \
    echo y | sdkmanager "build-tools;$ANDROID_BUILD_TOOLS_VERSION"

ENV PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS_VERSION

RUN yes | sdkmanager --licenses

# Add Dart SDK to PATH
ENV PATH="$PATH:/usr/lib/dart/bin"

# Add FVM to PATH
# ENV PATH="$PATH:/config/.pub-cache/bin" 

# RUN fvm default stable

# Set Flutter path
# ENV PATH "$PATH:`fvm flutter-path`"

#******************************#

RUN fvm install stable
#RUN fvm use stable

#ENV PATH="$PATH:/root/.fvm/default/bin"
ENV PATH="$PATH:/config/fvm/versions/stable/bin"

# Confirm installations
RUN flutter --version

# add local files
COPY /root /

# ports and volumes
EXPOSE 8443
