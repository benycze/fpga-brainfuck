#!/usr/bin/env bash

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

set -e

# Configuration -----------------------------------------------------------------
MNT_PATH=`pwd`
MNT_WDIR="/bsc-work"
COMPILER_PATH=`pwd`/../sw
COMPILER_WDIR="/sw"

DOCKER_BIN=/usr/bin/docker

# Functions & code --------------------------------------------------------------

function print_usage {
    echo "The script has following commands:"
    echo "-t or --translate     => run the translation, output will be in the tarball folder"
    echo "-h or --help          => prints the HELP"
    echo ""
    echo "The interactive mode is started if you don't pass any argument."
}

function start_docker {
    echo "############################################################################"
    echo "Starting the docker container with BSC tools "
    echo "############################################################################"

    echo " * We are looking for the bsc-compiler image"
    echo " * Local folder will be mounted to /bsc-work folder inside the container"
    echo " * The BCompiler will be mounted to /sw folder inside the container"

    ${DOCKER_BIN} run --rm -t -i \
        --mount=type=bind,source=${MNT_PATH},destination=${MNT_WDIR} \
        --mount=type=bind,source=${COMPILER_PATH},destination=${COMPILER_WDIR} \
        --workdir=${MNT_WDIR} localhost/bsc-compiler $1
}

# Parse arguments ----------------------------------------------------------------
translate_only=0

while [ "$1" != "" ]; do
    case "$1" in
        "-t" | "--translate") 
            translate_only=1
            ;;

        "-h" | "--help") 
            print_usage
            exit 0
            ;;

        *)  echo -n "Unknown parameter!!\n"
            print_usage
            exit 1
            ;;
    esac  
    shift
done

# Run the code ------------------------------------------------------------------
if [ $translate_only -eq 1 ];then
    start_docker "make tarball"
else
    start_docker bash
fi

exit 0
