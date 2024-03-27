#!/bin/bash

read -p "Name of the version you'd like to build? [sagitta]: " release
read -p "Your email to tag the build with [hackerman@example.com]: " email
release=${release:-sagitta}

# Prep folder
mkdir bld-$release
cd bld-$release
mkdir output

# Get the download started
docker pull vyos/vyos-build:$release

git clone -b sagitta --single-branch https://github.com/vyos/vyos-build
cd vyos-build

#docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:sagitta bash
docker run --rm --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:sagitta sudo scripts/build-vyos-image iso --architecture amd64 --build-by $email

# Grab finished output
cp ./build/vyos-* ../output

# Clean up
cd ..
echo "Docker GUIDs are strange, enter your root password for sudo rm -rf vyos-build"
sudo rm -rf vyos-build