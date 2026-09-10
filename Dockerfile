FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
EXPOSE 8765

ENV CPPTEST_HOME=/opt/parasoft/cpptest \
    CPPTEST_COMPILER_FAMILY=gcc_13-64 \
    CPPTEST_DISPLAY_VERSION="C++test Pro 2025.2" \
    TOOLCHAIN_DISPLAY_VERSION="GCC 13.3 / CMake" \
    DASHBOARD_HOST=0.0.0.0 \
    OUTPUT_ROOT=/results

CMD ["python3", "server.py"]
