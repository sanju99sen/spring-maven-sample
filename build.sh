#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME=$(basename $0)
BUILD_DIR=${SCRIPT_DIR}/build

echo -e "\n SCRIPT_DIR: $SCRIPT_DIR  SCRIPT_NAME:$SCRIPT_NAME  BUILD_DIR=$BUILD_DIR"
DOCKER_REG=${DOCKER_REG:-sanjoy-testdockerrepo.jfrog.io}
DOCKER_USR=${DOCKER_USR:-admin}
DOCKER_PSW=${DOCKER_PSW:-Zu6Tv8Ik5Kq0Se}

DOCKER_REPO=${DOCKER_REPO:-mycar}
DOCKER_TAG=${DOCKER_TAG:-dev}

# Docker login
dockerLogin () {
    echo -e "\nDocker login"

    if [ ! -z "${DOCKER_REG}" ]; then
        # Make sure credentials are set
        if [ -z "${DOCKER_USR}" ] || [ -z "${DOCKER_PSW}" ]; then
            errorExit "Docker credentials not set (DOCKER_USR and DOCKER_PSW)"
        fi

        docker login ${DOCKER_REG} -u ${DOCKER_USR} -p ${DOCKER_PSW} || errorExit "Docker login to ${DOCKER_REG} failed"
    else
        echo "Docker registry not set. Skipping"
    fi
}

# Build Docker images
buildDockerImage () {
    echo -e "\nBuilding ${DOCKER_REPO}:${DOCKER_TAG}"
    mkdir -p ${BUILD_DIR}/site
    cp -v ${SCRIPT_DIR}/docker/Dockerfile ${BUILD_DIR}
    cp -rv ${SCRIPT_DIR}/src/* ${BUILD_DIR}/site/
    echo -e "\nBuilding Docker image"
    echo -e "\n Running Command: docker build -t ${DOCKER_REG}/${DOCKER_REPO}:${DOCKER_TAG} ${BUILD_DIR}"
    docker build -t ${DOCKER_REG}/${DOCKER_REPO}:${DOCKER_TAG} ${BUILD_DIR}
    #docker build -t ${DOCKER_REG}/${DOCKER_REPO}:${DOCKER_TAG} ${BUILD_DIR} || errorExit "Building ${DOCKER_REPO}:${DOCKER_TAG} failed"
}

# Push Docker images
pushDockerImage () {
    echo -e "\nPushing ${DOCKER_REPO}:${DOCKER_TAG}"
    echo -e "\Running Command: docker push ${DOCKER_REG}/${DOCKER_REPO}:${DOCKER_TAG}"

    docker push ${DOCKER_REG}/${DOCKER_REPO}:${DOCKER_TAG} || errorExit "Pushing ${DOCKER_REPO}:${DOCKER_TAG} failed"
}

usage () {
    cat << END_USAGE
${SCRIPT_NAME} - Script for building the ACME web application, Docker image and Helm chart
Usage: ./${SCRIPT_NAME} <options>
--build             : [optional] Build the Docker image
--push              : [optional] Push the Docker image
--registry reg      : [optional] A custom docker registry
--docker_usr user   : [optional] Docker registry username
--docker_psw pass   : [optional] Docker registry password
--tag tag           : [optional] A custom app version
-h | --help         : Show this usage
END_USAGE

    exit 1
}


# Process command line options. See usage above for supported options
processOptions () {
    if [ $# -eq 0 ]; then
        usage
    fi

    while [[ $# > 0 ]]; do
        case "$1" in
            --build)
                BUILD="true"; shift
            ;;
            --push)
                PUSH="true"; shift
            ;;
            --registry)
                DOCKER_REG=${2}; shift 2
            ;;
            --docker_usr)
                DOCKER_USR=${2}; shift 2
            ;;
            --docker_psw)
                DOCKER_PSW=${2}; shift 2
            ;;
            --tag)
                DOCKER_TAG=${2}; shift 2
            ;;
            -h | --help)
                usage
            ;;
            *)
                usage
            ;;
        esac
    done
}

main () {
    echo -e "\nRunning"

    echo "DOCKER_REG:   ${DOCKER_REG}"
    echo "DOCKER_USR:   ${DOCKER_USR}"
    echo "DOCKER_REPO:  ${DOCKER_REPO}"
    echo "DOCKER_TAG:   ${DOCKER_TAG}"

    # Cleanup
    #rm -rf ${BUILD_DIR}

    # Build and push docker images if needed
    if [ "${BUILD}" == "true" ]; then
        buildDockerImage
    fi
    if [ "${PUSH}" == "true" ]; then
        # Attempt docker login
        dockerLogin
        pushDockerImage
    fi
}

############## Main

processOptions $*
main

