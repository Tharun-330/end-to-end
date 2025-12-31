pipeline {
    agent none

    environment {
        APP_NAME      = "dev/my-app"
        AWS_REGION    = "ap-south-1"
        ACCOUNT_ID    = "132514887880"
        IMAGE_TAG     = "v${BUILD_NUMBER}"

        ECR_REPO      = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
        DOCKER_IMAGE  = "${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            agent any
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            agent {
                docker {
                    image 'docker:27-cli'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            environment {
                DOCKER_CONFIG = "${WORKSPACE}/.docker"
            }
            steps {
                sh '''
                    set -e
                    mkdir -p $DOCKER_CONFIG
                    docker build -t ${DOCKER_IMAGE} .
                '''
            }
        }

        stage('Scan Docker Image (Trivy)') {
            agent {
                docker {
                    image 'aquasec/trivy:latest'
                    args '''
                      --user root
                      --entrypoint=""
                      -v /var/run/docker.sock:/var/run/docker.sock
                      -v $WORKSPACE/.trivycache:/trivy-cache
                    '''
                }
            }
            environment {
                TRIVY_CACHE_DIR = "/trivy-cache"
                XDG_CACHE_HOME  = "/trivy-cache"
            }
            steps {
                sh '''
                    set -e
                    mkdir -p /trivy-cache
                    trivy image --severity HIGH,CRITICAL --no-progress ${DOCKER_IMAGE} || true
                '''
            }
        }

        stage('Login to AWS ECR') {
            agent {
                docker {
                    image 'jenkins/aws-docker:1.0'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            environment {
                DOCKER_CONFIG = "${WORKSPACE}/.docker"
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ecr-creds'
                ]]) {
                    sh '''
                        set -e
                        mkdir -p $DOCKER_CONFIG
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin \
                        ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    '''
                }
            }
        }

        stage('Push Docker Image to ECR') {
            agent {
                docker {
                    image 'docker:27-cli'
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            environment {
                DOCKER_CONFIG = "${WORKSPACE}/.docker"
            }
            steps {
                sh '''
                    set -e
                    docker push ${DOCKER_IMAGE}
                '''
            }
        }

        stage('Deploy to Kubernetes (Minikube)') {
            agent {
                docker {
                    image 'registry.k8s.io/kubectl:v1.30.0'
                    args "-v ${WORKSPACE}/.kube:/root/.kube"
                }
            }
            steps {
                sh '''
                    set -e
                    kubectl version --client
                    kubectl config use-context minikube
                    kubectl apply -n dev -f k8s/dev/
                    kubectl rollout status deployment/myapp -n dev
                '''
            }
        }
    }

    post {
        always {
            script {
                node('any') {
                    echo "🧹 Cleaning workspace"
                    sh '''
                        rm -rf $WORKSPACE/.docker || true
                        rm -rf $WORKSPACE/.trivycache || true
                    '''
                }
            }
        }
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
