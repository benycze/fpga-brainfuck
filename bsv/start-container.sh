#!/usr/bin/env bash

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

echo "############################################################################"
echo "Starting the docker container with BSC tools "
echo "############################################################################"

echo " * We are looking for the bsc-compiler image"
echo " * Local folder will be mounted to /bsc-work folder inside the container :)"

MNT_PATH=`pwd`
MNT_WDIR="/bsc-work"
docker run --rm -t -i --mount=type=bind,source=${MNT_PATH},destination=${MNT_WDIR} --workdir=${MNT_WDIR} localhost/bsc-compiler bash
