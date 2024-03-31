#!/bin/bash

# Get current working directory, or set where script should do the thing.
workdir=$(pwd)

# Get current date, for naming
date=$(date '+%Y-%m-%d')

read -p "Enter working folder [$(pwd)]: " workdir
workdir=${workdir:-$(pwd)}

# User prompts for customization
read -p "Name of the version you'd like to build? [sagitta]: " release
read -p "Your email to tag the build with [hackerman@example.com]: " email
release=${release:-sagitta}
email=${email:-hackerman@example.com}

# Prep folder
mkdir $workdir/bld-$release
cd $workdir/bld-$release
mkdir output

# Download the building image
docker pull vyos/vyos-build:$release

git clone -b $release --single-branch https://github.com/vyos/vyos-build
cd vyos-build

#docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:sagitta bash
docker run --rm --privileged -v $workdir/bld-$release/vyos-build:/vyos -w /vyos vyos/vyos-build:$release sudo scripts/build-vyos-image iso --architecture amd64 --build-type=release --version $release-$date --build-by $email

# Grab finished output
cp $workdir/bld-$release/vyos-build/build/vyos-* $workdir/bld-$release/output

# Go somewhere familiar
cd $workdir

# Clean up?
read -p "Run cleanup of build dir (leaves image) y/[n]: " runCleanup
runCleanup=${runCleanup:-n}

if [ $runCleanup == "y" ]; then
  echo "Docker GUIDs are strange, root privileges are needed for sudo rm -rf vyos-build"
  sudo rm -rf $workdir/bld-$release/vyos-build
fi
