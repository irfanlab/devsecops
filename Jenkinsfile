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
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    jacoco execPattern: 'targets/jacoco.exec'
                }
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
    }
}

