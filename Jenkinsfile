pipeline {
    options {
        // Build auto timeout
        timeout(time: 60, unit: 'MINUTES')
    }
	
	    environment {
        IMAGE_NAME = 'car'
        TEST_LOCAL_PORT = 8817
        DEPLOY_PROD = false
        PARAMETERS_FILE = "${JENKINS_HOME}/parameters.groovy"
    }
	
	parameters {
        string (name: 'GIT_BRANCH',           defaultValue: 'master',  description: 'Git branch to build')
        booleanParam (name: 'DEPLOY_TO_PROD', defaultValue: false,     description: 'If build and tests are good, proceed and deploy to production without manual approval')


        // The commented out parameters are for optionally using them in the pipeline.
        // In this example, the parameters are loaded from file ${JENKINS_HOME}/parameters.groovy later in the pipeline.
        // The ${JENKINS_HOME}/parameters.groovy can be a mounted secrets file in your Jenkins container.
/*
        string (name: 'DOCKER_REG',       defaultValue: 'docker-artifactory.my',                   description: 'Docker registry')
        string (name: 'DOCKER_TAG',       defaultValue: 'dev',                                     description: 'Docker tag')
        string (name: 'DOCKER_USR',       defaultValue: 'admin',                                   description: 'Your helm repository user')
        string (name: 'DOCKER_PSW',       defaultValue: 'password',                                description: 'Your helm repository password')
        string (name: 'IMG_PULL_SECRET',  defaultValue: 'docker-reg-secret',                       description: 'The Kubernetes secret for the Docker registry (imagePullSecrets)')
*/
    }
	
	    // Pipeline stages
    stages {

        ////////// Step 1 //////////
        stage('Git clone and setup') {
            steps {
                echo "Check out code"
                git branch: "master",
                        credentialsId: 'sanju99sen',
                        url: 'https://github.com/sanju99sen/spring-maven-sample.git'

                // Validate kubectl
                sh "kubectl cluster-info"

                // Init helm client
                //----sh "helm init"

                // Make sure parameters file exists
                /*script {
                    if (! fileExists("${PARAMETERS_FILE}")) {
                        echo "ERROR: ${PARAMETERS_FILE} is missing!"
                    }
                }*/

                // Load Docker registry and Helm repository configurations from file
                //---load "${JENKINS_HOME}/parameters.groovy"

                echo "DOCKER_REG is ${DOCKER_REG}"
                //----echo "HELM_REPO  is ${HELM_REPO}"

                // Define a unique name for the tests container and helm release
                script {	
                    branch = GIT_BRANCH.replaceAll('/', '-').replaceAll('\\*', '-')
                    ID = "${IMAGE_NAME}-${DOCKER_TAG}-${branch}"

                    echo "Global ID set to ${ID}"
                }
            }
        }
	}
}


