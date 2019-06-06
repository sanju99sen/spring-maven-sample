def curlRun (url, out) {
    echo "Running curl on ${url}"

    script {
        if (out.equals('')) {
            out = 'http_code'
        }
        echo "Getting ${out}"
            def result = sh (
                returnStdout: true,
                script: "curl --output /dev/null --silent --connect-timeout 5 --max-time 5 --retry 5 --retry-delay 5 --retry-max-time 30 --write-out \"%{${out}}\" ${url}"
        )
        echo "Result (${out}): ${result}"
    }
}

def notifyBuild() {
  def colorName = 'RED'
  def colorCode = '#FF0000'
  buildResult = currentBuild.result
  def subject = "${buildResult}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
  def summary = "${subject} (${env.BUILD_URL})"
  def details = """<p>STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
    <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""

  // Override default values based on build status
  if (currentBuild.result == 'SUCCESS') {
    color = 'GREEN'
    colorCode = '#00FF00'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }

  // Send notifications
  slackSend (color: colorCode, message: summary)
}

pipeline {

 environment {
 MAVEN_HOME = '/usr'
 JAVA_HOME = '/usr'
 IMAGE_NAME = 'mycar'
 TEST_LOCAL_PORT = 8088
 CONTAINER_PORT = 8080
 ext='/springwebapp/car/add'
 }
 
parameters {
        string (name: 'GIT_BRANCH',           defaultValue: 'master',  description: 'Git branch to build')
        booleanParam (name: 'DEPLOY_TO_PROD', defaultValue: false,     description: 'If build and tests are good, proceed and deploy to production without manual approval')

        // The commented out parameters are for optionally using them in the pipeline.
        // In this example, the parameters are loaded from file ${JENKINS_HOME}/parameters.groovy later in the pipeline.
        // The ${JENKINS_HOME}/parameters.groovy can be a mounted secrets file in your Jenkins container.
        string (name: 'DOCKER_REG',         defaultValue: 'rimjhim-testdockerrepo.jfrog.io',  description: 'Docker registry')
        string (name: 'DOCKER_TAG',         defaultValue: 'latest',                          description: 'Docker tag')
        string (name: 'DOCKER_USR',         defaultValue: 'admin',                           description: 'Your helm repository user')
        string (name: 'DOCKER_PSW',         defaultValue: 'Fy1Bt8Qr0Jd8Vn',                  description: 'Your helm repository password')
      //string (name: 'IMG_PULL_SECRET',    defaultValue: 'dockerregcred',                   description: 'The Kubernetes secret for the Docker registry (imagePullSecrets)')
		string (name: 'KUBE_NAMESPACE',     defaultValue: 'dev',                             description: 'Your helm repository password')
}

agent { node { label 'master' } }

stages {

stage('Git clone and setup') {
steps{
git branch: "master",
url: 'https://github.com/sanju99sen/spring-maven-sample.git'

// Define a unique name for the tests container and helm release
    script {
		branch = GIT_BRANCH.replaceAll('/', '-').replaceAll('\\*', '-')
        ID = "${IMAGE_NAME}-${DOCKER_TAG}-${branch}"
        echo "Global ID set to ${ID}"
    }
				
}
}

stage('Set up JFrog Artifactory') {
steps{
rtServer (id: "Artifactory-1", url: "https://rimjhim.jfrog.io/rimjhim", credentialsId: 'artifactoryCRED')
rtMavenResolver (id: 'Resolver-1', serverId: 'Artifactory-1', releaseRepo: 'virtualmavenrepo', snapshotRepo: 'virtualmavenrepo')
rtMavenDeployer (id: 'Deployer-1',  serverId: 'Artifactory-1', releaseRepo: 'localmavenrepo', snapshotRepo: 'localmavenrepo')
}
}

stage('Run Maven Build') {
steps{
rtMavenRun (tool: 'MAVEN_TOOL', pom: 'pom.xml', goals: 'install', resolverId: "Resolver-1", deployerId: "Deployer-1")
}
}

stage ('Sonar Cloud Report') {
    steps {
        sh(script: 'mvn sonar:sonar \
            -Dsonar.projectKey=sanju99sen_spring-maven-sample \
            -Dsonar.organization=sanju99sen-github \
            -Dsonar.host.url=https://sonarcloud.io \
            -Dsonar.login=48ae85beaa930cb1758cb09a1872b0f9a62fb9d9'
        )
    }
}

stage ('Build Docker Image') {
steps {
echo "Building application and Docker image"
sh "sh build.sh --build --registry ${DOCKER_REG} --docker_usr ${DOCKER_USR} --docker_psw ${DOCKER_PSW} --namespace ${KUBE_NAMESPACE}"
}
}

stage('Run Container Locally') {
steps{
// Kill container in case there is a leftover
echo "Container: ${ID}"
sh "sh build.sh --localtest --container ${ID} --localport ${TEST_LOCAL_PORT}:${CONTAINER_PORT} --registry ${DOCKER_REG}"
echo "Waiting 60 seconds...let container to be up and running.."
sleep(60)
   script {
            host_ip = sh(returnStdout: true, script: 'hostname -I | awk \'{print $1 ":"PORT}\' PORT=${TEST_LOCAL_PORT}')
            echo "IP: $host_ip"
			host_ip=host_ip.trim()			
          }
}
}

        // Run the 3 tests on the currently running ACME Docker container
        stage('Test app response locally') {
            parallel {
                stage('Curl http_code') {
                    steps {
                        curlRun ("http://${host_ip}${ext}", 'http_code')
                    }
                }
                stage('Curl total_time') {
                    steps {
                        curlRun ("http://${host_ip}${ext}", 'time_total')
                    }
                }
                stage('Curl size_download') {
                    steps {
                        curlRun ("http://${host_ip}${ext}", 'size_download')
                    }
                }
            }
        }


stage ('Publish Image to Repo') {
steps {
echo "Publish docker image to Artifactory Docker Repo"
sh "sh build.sh --push --registry ${DOCKER_REG} --docker_usr ${DOCKER_USR} --docker_psw ${DOCKER_PSW} --namespace ${KUBE_NAMESPACE}"
}
}

stage ('Deploy to Kubernetes Dev Cluster') {
steps {
echo "Deploy to K8-Dev"
sh "sh build.sh --deploy --registry ${DOCKER_REG} --docker_usr ${DOCKER_USR} --docker_psw ${DOCKER_PSW} --namespace ${KUBE_NAMESPACE}"
}
}

stage ('Verify deployment status') {
	steps {
		echo "checking deployment status ..."
		sleep (180)
			script { 
				ready = sh(returnStdout: true, script: 'kubectl get deployment --namespace=dev|grep mycar|awk \'{print $2}\'|cut -d"/" -f1')
				total = sh(returnStdout: true, script: 'kubectl get deployment --namespace=dev|grep mycar|awk \'{print $2}\'|cut -d"/" -f2')
				available = sh(returnStdout: true, script: 'kubectl get deployment --namespace=dev|grep mycar|awk \'{print $4}\'')
				ready=ready.trim()
				total=total.trim()
				available=available.trim()	
					while (! ready.equals(total) && ! ready.equals(available)) {
							echo "deployment is in progress ..."
							sleep (60)						
					}
				echo "Deployment completed now"		
			}
	}
}

	// Run the 3 tests on the deployed Kubernetes pod and service
	// Run the 3 tests on the deployed Kubernetes pod and service
 	// Run the 3 tests on the deployed Kubernetes pod and service
    stage('Get app url running in Kubernetes Dev') {
		steps {
				script {
					kube_master_ip = sh(returnStdout: true, script: 'kubectl cluster-info | grep "Kubernetes master" | awk \'FS=":" {print $6}\'|cut -d":" -f2')					
					echo "kubemaster=${kube_master_ip}"
					node = sh(returnStdout: true, script: 'kubectl get svc -n "${KUBE_NAMESPACE}" | grep mycar | awk \'{print $2}\'')
					node=node.trim()
					//ext='/springwebapp/car/add'
					
					echo "node=${node}"						
						if (node.equals('NodePort')) {
							echo "FOUND NODEPORT"
							app_ip="${kube_master_ip}"							
							port = sh (returnStdout: true, script: 'kubectl get svc -n "${KUBE_NAMESPACE}"|grep mycar|awk \'FS=":" {print $5}\'|cut -d":" -f2|cut -d"/" -f1')
							echo "APP_IP=${app_ip} PORT=${port}"
							app_ip=app_ip.trim()
							port=port.trim()
							app_url="http:${app_ip}:${port}${ext}"
						}
						else {
							echo "Not NODEPORT..."
							app_ip = sh (returnStdout: true, script: 'kubectl get svc -n "${KUBE_NAMESPACE}" | grep mycar | awk \'{print "http://"$3}\'')
							port = sh (returnStdout: true, script: 'kubectl get svc -n "${KUBE_NAMESPACE}" | grep mycar | awk -F":" \'{print $1}\' | awk \'{print $NF}\'')
							echo "APP_IP=${app_ip} PORT=${port}"
							app_ip=app_ip.trim()
							port=port.trim()
							app_url = "${app_ip}:${port}${ext}"
						}
						echo "APP_URL=${app_url}"
						svc_ip = "${app_url}"
						echo "SVC_IP=${svc_ip}"
				}
		}
    } 
    
    stage ('Test app response in Kubernetes Dev') {		 
			parallel {
                stage('Curl http_code') {
                    steps {
                        curlRun ("${svc_ip}", 'http_code')
                    }
                }
                stage('Curl total_time') {
                    steps {
                        curlRun ("${svc_ip}", 'time_total')
                    }
                }
                stage('Curl size_download') {
                    steps {
                        curlRun ("${svc_ip}", 'size_download')
                    }
                }
            }
    }
	

}
    post {
        always {	   
			notifyBuild()
            //cleanWs()
        }
    }

}
