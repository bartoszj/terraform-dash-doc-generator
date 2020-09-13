#!/usr/bin/env bash

set -ex

# Read parameters
TAG=$1
if [ -z $TAG ]; then
    echo '"TAG" must be specified'
    exit 1
fi

# Paths
CWD=$(pwd)
BUILD_PATH="${CWD}/build/$TAG"
TERRAFORM_PATH="${CWD}/terraform-website"

# Clean build
rm -rf "${BUILD_PATH}"
mkdir -p "${BUILD_PATH}"

# Checkout and clean
./git_get.sh
cd "${TERRAFORM_PATH}"

rm Rakefile || true
# cp "${CWD}/Rakefile" .
ln -s "${CWD}/Rakefile" || true
cp "${CWD}/.ruby-version" ./

# Build
ulimit -n 16000
rake

mv Terraform.tgz "${BUILD_PATH}"
