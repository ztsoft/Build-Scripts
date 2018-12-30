#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources. It
# is useful for bootstrapping a full Wget build.

THIS_DIR=$(pwd)
function finish {
  cd "$THIS_DIR"
}
trap finish EXIT

# Binaries
WGET_TAR=wget-1.20.1.tar.gz
SSL_TAR=openssl-1.0.2q.tar.gz

# Directories
BOOTSTRAP_DIR=$(pwd)
WGET_DIR=wget-1.20.1
SSL_DIR=openssl-1.0.2q

# Install location
PREFIX="$HOME/bootstrap"

############################## CA Certs ##############################

# Copy cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/"

############################## OpenSSL ##############################

# Build OpenSSL
cd "$BOOTSTRAP_DIR"

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$SSL_DIR"

./config no-asm no-shared no-dso no-engine -fPIC \
    --prefix="$PREFIX"

if ! make depend; then
    echo "OpenSSL update failed"
    exit 1
fi

if ! make -j 2; then
    echo "OpenSSL build failed"
    exit 1
fi

if ! make install_sw; then
    echo "OpenSSL install failed"
    exit 1
fi

############################## Wget ##############################

# Build Wget
cd "$BOOTSTRAP_DIR"

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -

# Install recipe does not overwrite a config, if present.
if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

cp wget.patch "$WGET_DIR"
cd "$WGET_DIR"

if ! patch -u -p0 < wget.patch; then
    echo "Wget patch failed"
    exit 1
fi

    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig/" \
./configure \
    --sysconfdir="$PREFIX/etc" \
    --prefix="$PREFIX" \
    --with-ssl=openssl \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn \
    --without-cares \
    --disable-pcre \
    --disable-pcre2 \
    --disable-nls \
    --disable-iri \
    --without-libiconv-prefix \
    --without-libunistring-prefix

if ! make -j 2; then
    echo "Wget build failed"
    exit 1
fi

if ! make install; then
    echo "Wget install failed"
    exit 1
fi

echo "" >> "$PREFIX/etc/wgetrc"
echo "# cacert.pem location" >> "$PREFIX/etc/wgetrc"
echo "ca_directory = $PREFIX/cacert/" >> "$PREFIX/etc/wgetrc"
echo "ca_certificate = $PREFIX/cacert/cacert.pem" >> "$PREFIX/etc/wgetrc"
echo "" >> "$PREFIX/etc/wgetrc"

# Cleanup
if true; then
    cd "$THIS_DIR"
    rm -rf "$WGET_DIR" &>/dev/null
    rm -rf "$SSL_DIR" &>/dev/null
fi

exit 0
