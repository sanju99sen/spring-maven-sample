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

# Create Docker TAG
generate_TAG () {
dockerLogin
CURR_TAG=`docker images|grep "${DOCKER_REG}/${DOCKER_REPO}"|awk '{print $2}'|head -1`
if [ -z $CURR_TAG ] ; then
CURR_TAG=0
fi
INCR=0.1
NEW_TAG=`echo $CURR_TAG $INCR|awk '{print $1 + $2}'`
DOCKER_TAG=$NEW_TAG
}

# Build Docker images
buildDockerImage () {
    echo -e "\nBuilding ${DOCKER_REPO}:${DOCKER_TAG}"
    mkdir -p ${BUILD_DIR}/site
    cp -v ${SCRIPT_DIR}/docker/Dockerfile ${BUILD_DIR}
    cp -rv ${SCRIPT_DIR}/target/* ${BUILD_DIR}/site/
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

#### deploying app to K8 cluster ###
deploy_K8 () {
echo -e "\nChecking K8 cluster info"
kubectl cluster-info

###### create kubernetes namespace in K8 cluster #####
echo -e "\Creating namespace ${KUBE_NAMESPACE} if needed"
[ ! -z kubectl get ns ${KUBE_NAMESPACE} -o name 2>/dev/null ] || kubectl create ns ${KUBE_NAMESPACE}

MANIFEST=`ls yaml/deployment/`
sed "s/image: ${DOCKER_REG}\/${DOCKER_REPO}:${CURR_TAG}/image: ${DOCKER_REG}\/${DOCKER_REPO}:${DOCKER_TAG}/g" ${MANIFEST} > /tmp/a.yaml
mv /tmp/a.yaml yaml/deployment/${MANIFEST}

echo -e "\n Deploying resources: ${MANIFEST} into the cluster"
kubectl apply -f yaml/deployment/${MANIFEST} --namespace=${KUBE_NAMESPACE}
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
            --namespace)
                KUBE_NAMESPACE=${2}; shift 2
            ;;
            --deploy)
                DEPLOY="true"; shift
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
        generate_TAG
        buildDockerImage
    fi
    if [ "${PUSH}" == "true" ]; then
        # Attempt docker login
        dockerLogin
        generate_TAG
        pushDockerImage
    fi
    if [ "${DEPLOY}" == "true" ] ; then
        #deploy app
        generate_TAG
        deploy_K8
    fi
}

############## Main

processOptions $*
main

