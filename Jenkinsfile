pipeline {
    agent any

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
                    mvn clean verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
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

        stage ('Dependency Scanning - OWASP Dependency Check') {
            steps {
                sh "mvn org.owasp:dependency-check-maven:check"
            }
        }

        stage('Docker Build and Push') {
             steps {
                withDockerRegistry([credentialsId: "dockerhub-creds", url: ""], {
                    sh 'printenv'
                    sh 'docker build -t irfanlab/numeric-app:""$GIT_COMMIT"" .'
                    sh 'docker push irfanlab/numeric-app:""$GIT_COMMIT""'
                })   
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
    }

    post { 
        always { 
            junit 'target/surefire-reports/*.xml'
            jacoco execPattern: 'target/jacoco.exec'
            pitest mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
            dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'

        }
    }
}

