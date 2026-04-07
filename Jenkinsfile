pipeline {
    agent any

    environment {
    deploymentName = "devsecops"
    containerName = "devsecops-container"
    serviceName = "devsecops-svc"
    imageName = "irfanlab/numeric-app:${GIT_COMMIT}"
    applicationURL="http://35.200.203.194"
    applicationURI="/increment/99"
  }

    tools {
        jdk 'jdk17'
    }

    stages {
        stage('Build Artifact - Maven') {
            steps {
                sh "mvn clean package -DskipTests=true"
                archive 'target/*.jar'
            }
        }

        stage('Unit Tests') {
            steps {
                sh "mvn test"
            }   
        }

        stage ('Mutation Testing') {
            steps {
                sh "mvn org.pitest:pitest-maven:mutationCoverage"
            }
        }

        stage ('SAST - SonarQube') {
            steps {
                withSonarQubeEnv('Sonar') {
                    sh '''
                    mvn verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                    -Dsonar.projectKey=numeric-app \
                    -Dsonar.projectName=numeric-app \
                    -Dsonar.host.url=http://35.200.203.194:9000
                    '''
                    }
                    timeout(time: 2, unit: 'MINUTES') {
                        script {
                            waitForQualityGate abortPipeline: true  
                    }
                }
            }
        }

        // stage ('Dependency Scanning - OWASP Dependency Check') {
        //     steps {
        //         sh "mvn org.owasp:dependency-check-maven:check"
        //     }
        // }

        stage ('Dependency Scanning - OWASP Dependency Check') {
            steps {
                parallel (
                    "Scan with OWASP Dependency Check": {
                         sh "mvn org.owasp:dependency-check-maven:check"
                    },
                    "Scan with Trivy": {
                        sh "bash trivy-docker-image-scan.sh"
                    },
                    "OPA ConfTest": {
                        sh 'docker run --rm -v $(pwd):/project openpolicyagent/conftest:latest test --policy opa-docker-security.rego Dockerfile --all-namespaces'
                    }
                )
            }
        }

        stage('Docker Build and Push') {
             steps {
                withDockerRegistry([credentialsId: "dockerhub-creds", url: ""], {
                    sh 'printenv'
                    sh 'sudo docker build -t irfanlab/numeric-app:""$GIT_COMMIT"" .'
                    sh 'docker push irfanlab/numeric-app:""$GIT_COMMIT""'
                })   
            }
        }

        stage ('OPA ConfTest - Kubernetes Security') {
            steps {
                parallel (
                    "OPA K8s Scan": {
                    sh 'docker run --rm -v $(pwd):/project openpolicyagent/conftest:latest test --policy opa-k8s-security.rego k8s_deployment_service.yaml --all-namespaces'
                },
                "Kubesec Scan": {
                    sh "bash kubesec-scan.sh"
                },
                "Trivy K8s Scan": {
                    sh "bash trivy-k8s-scan.sh"
                }
                )
            }
        }


        stage('Deploy to Kubernetes - Dev') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                sh 'sed -i "s#replace#irfanlab/numeric-app:${GIT_COMMIT}#g" k8s_deployment_service.yaml'
                sh 'kubectl apply -f k8s_deployment_service.yaml'
                }
            }
        }

        stage('K8S Deployment - DEV') {
            steps {
                parallel(
                "Deployment": {
                    withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh "bash k8s-deployment.sh"
                    }
                },
                "Rollout Status": {
                    withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh "bash k8s-deployment-rollout-status.sh"
                    }
                }
                )
            }
        }

    stages {
        stage('Integration Testing') {
            steps {
                script {
                    try {
                        withKubeConfig([credentialsId: 'kubeconfig']) {
                            sh "bash integration-tests.sh"
                        }
                    }   catch (e) {
                        withKubeConfig([credentialsId: 'kubeconfig']) {
                            sh "kubectl -n default rollout undo deployment {deploymentName}"
                        }
                        throw e
                    }
                }
            }
        }
    }
    }

    post { 
        always { 
            junit 'target/surefire-reports/*.xml'
            jacoco execPattern: 'target/jacoco.exec'
            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                pitmutation killRatioMustImprove: false, minimumKillRatio: 0.0, mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
            }
            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
            }

        }
    }
}

