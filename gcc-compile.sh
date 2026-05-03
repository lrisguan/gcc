#!/bin/bash

# gcc
# Copyright (C) 2026 lrisguan <lrisguan@outlook.com>
# 
# This program is released under the terms of the MIT LICENSE.
# See https://opensource.org/licenses/MIT for more information.
# 
# Project homepage: https://github.com/lrisguan/gcc
# Description: Shell script to auto compile the latest gcc.

set -euo pipefail

# ==================== 1. Default Configuration (User Overridable) ====================
export PREFIX=${PREFIX:-"$HOME/local/gcc-deps"}
export GCCPREFIX=${GCCPREFIX:-"$HOME/local/gcc-install"}
export NPROC=${NPROC:-$(nproc)}
export BUILD_DIR=${BUILD_DIR:-"$HOME/local/gcc-build"}
export GCC_LANGUAGES=${GCC_LANGUAGES:-"c,c++"}

export DEPS_CC="gcc -std=gnu11"

# ==================== 2. Version Fetching Functions ====================
get_latest_file_version() {
    local url="$1"
    local prefix="$2"
    local suffix="$3"
    
    curl -s "$url" \
        | grep -oE "${prefix}-[0-9.]+${suffix}" \
        | sed -e "s/${prefix}-//" -e "s/${suffix}//" \
        | sort -V \
        | tail -n 1
}

get_latest_gcc_version() {
    local url="$1"
    
    curl -s "$url" \
        | grep -oE 'gcc-[0-9.]+/' \
        | sed -e 's/gcc-//' -e 's/\///' \
        | sort -V \
        | tail -n 1
}

# ==================== 3. Preparation ====================
mkdir -p "$PREFIX"
mkdir -p "$GCCPREFIX"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ==================== 4. Fetch Latest Versions ====================
echo "Fetching latest version information..."

M4_VERSION=$(get_latest_file_version "https://ftp.gnu.org/gnu/m4/" "m4" ".tar.gz")
M4_URL="https://ftp.gnu.org/gnu/m4/m4-${M4_VERSION}.tar.gz"
echo "  Latest M4: $M4_VERSION"

GMP_VERSION=$(get_latest_file_version "https://gcc.gnu.org/pub/gcc/infrastructure/" "gmp" ".tar.bz2")
GMP_URL="https://gcc.gnu.org/pub/gcc/infrastructure/gmp-${GMP_VERSION}.tar.bz2"
echo "  Latest GMP: $GMP_VERSION"

MPFR_VERSION=$(get_latest_file_version "https://gcc.gnu.org/pub/gcc/infrastructure/" "mpfr" ".tar.bz2")
MPFR_URL="https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-${MPFR_VERSION}.tar.bz2"
echo "  Latest MPFR: $MPFR_VERSION"

MPC_VERSION=$(get_latest_file_version "https://gcc.gnu.org/pub/gcc/infrastructure/" "mpc" ".tar.gz")
MPC_URL="https://gcc.gnu.org/pub/gcc/infrastructure/mpc-${MPC_VERSION}.tar.gz"
echo "  Latest MPC: $MPC_VERSION"

GCC_VERSION=$(get_latest_gcc_version "https://gcc.gnu.org/pub/gcc/releases/")
GCC_URL="https://gcc.gnu.org/pub/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
echo "  Latest GCC: $GCC_VERSION"
echo "  GCC Languages: $GCC_LANGUAGES"

# ==================== 5. Download and Extract Function ====================
download_and_extract() {
    local url="$1"
    local file=$(basename "$url")
    
    if [ ! -f "$file" ]; then
        echo "Downloading $file ..."
        wget -q --show-progress "$url"
    else
        echo "$file already exists, skipping download"
    fi
    
    echo "Extracting $file ..."
    case "$file" in
        *.tar.gz) tar -xzf "$file" ;;
        *.tar.bz2) tar -xjf "$file" ;;
        *.tar.xz) tar -xf "$file" ;;
        *) echo "Unknown archive format: $file"; exit 1 ;;
    esac
}

# ==================== 6. Build and Install Components ====================

# --- 6.1 Install M4 ---
echo -e "\n===== Building and installing M4 $M4_VERSION ====="
download_and_extract "$M4_URL"
cd "m4-${M4_VERSION}"
mkdir -p build && cd build
../configure --prefix="$PREFIX"
make -j"$NPROC"
make install
cd "$BUILD_DIR"
export PATH="$PREFIX/bin:$PATH"

# --- 6.2 Install GMP ---
echo -e "\n===== Building and installing GMP $GMP_VERSION ====="
download_and_extract "$GMP_URL"
cd "gmp-${GMP_VERSION}"
mkdir -p build && cd build
CC="$DEPS_CC" ../configure --prefix="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install
cd "$BUILD_DIR"

# --- 6.3 Install MPFR ---
echo -e "\n===== Building and installing MPFR $MPFR_VERSION ====="
download_and_extract "$MPFR_URL"
cd "mpfr-${MPFR_VERSION}"
mkdir -p build && cd build
CC="$DEPS_CC" ../configure --prefix="$PREFIX" --with-gmp="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install
cd "$BUILD_DIR"

# --- 6.4 Install MPC ---
echo -e "\n===== Building and installing MPC $MPC_VERSION ====="
download_and_extract "$MPC_URL"
cd "mpc-${MPC_VERSION}"
mkdir -p build && cd build
CC="$DEPS_CC" ../configure --prefix="$PREFIX" --with-gmp="$PREFIX" --with-mpfr="$PREFIX" --enable-static --disable-shared
make -j"$NPROC"
make install
cd "$BUILD_DIR"

# --- 6.5 Install GCC ---
echo -e "\n===== Building and installing GCC $GCC_VERSION (Languages: $GCC_LANGUAGES) ====="
download_and_extract "$GCC_URL"
cd "gcc-${GCC_VERSION}"
mkdir -p build && cd build
../configure \
    --prefix="$GCCPREFIX" \
    --with-gmp="$PREFIX" \
    --with-mpfr="$PREFIX" \
    --with-mpc="$PREFIX" \
    --enable-languages="$GCC_LANGUAGES" \
    --disable-multilib \
    --disable-bootstrap
make -j"$NPROC"
make install
cd "$BUILD_DIR"

# ==================== 7. Completion Message ====================
echo -e "\n✅ All builds completed successfully!"
echo "  Dependency install prefix: $PREFIX"
echo "  GCC install prefix:        $GCCPREFIX"
echo "  Enabled languages:          $GCC_LANGUAGES"
echo ""
echo "Set the following environment variables before use:"
echo "  export PATH=$GCCPREFIX/bin:\$PATH"
echo "  export LD_LIBRARY_PATH=$GCCPREFIX/lib64:\$LD_LIBRARY_PATH"
echo ""
echo "Verify installation:"
echo "  gcc --version"
echo "  g++ --version"
