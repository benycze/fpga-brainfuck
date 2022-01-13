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

# Check if docker/podman is available
DOCKER_BIN=
CONTAINER_TOOL=""
if command -v docker > /dev/null; then
    DOCKER_BIN=`which docker`
elif command -v podman > /dev/null; then
    DOCKER_BIN=`which podman`
else
    echo "No container tool (podman, docker has been found)!"
    exit 1
fi

# Functions & code --------------------------------------------------------------

function print_usage {
    echo "The script has following commands:"
    echo "-t or --translate     => run the translation, output will be in the tarball folder"
    echo "-s or --tests         => run all"
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
        --workdir=${MNT_WDIR} localhost/bsc-compiler $*
}

# Parse arguments ----------------------------------------------------------------
translate_only=0
run_tests=0

while [ "$1" != "" ]; do
    case "$1" in
        "-t" | "--translate") 
            translate_only=1
            ;;

        "-h" | "--help") 
            print_usage
            exit 0
            ;;

        "-s" | "--tests")
            run_tests=1
            ;;

        *)  echo -n "Unknown parameter!!\n"
            print_usage
            exit 1
            ;;
    esac  
    shift
done

# Run the code ------------------------------------------------------------------
echo "${DOCKER_BIN} tool has been found ..."
if [ $translate_only -eq 1 ];then
    # Check if the bsc compiler exists. We will run it inside
    # the docker if the bsc command is not available
    if ! command -v bsc &> /dev/null; then
        echo -e "BSC command not available, using the docker image ...\n\n"
        start_docker "make tarball"
    else
        echo -e "BSC command available, using the system version ...\n\n"
        make tarball
    fi
else
    if [ $run_tests -eq 1 ]; then
        start_docker make LOG=0 test vtest
    else
        start_docker bash
    fi
fi

exit 0
