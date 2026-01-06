pipeline {
    agent { label 'docker-agent' }

    environment {
        APP_NAME   = "my-app"
        AWS_REGION = "ap-south-1"
        ACCOUNT_ID = "132514887880"
        IMAGE_TAG  = "v${BUILD_NUMBER}"
        ECR_REPO     = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/dev/${APP_NAME}"
        DOCKER_IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {
        
        stage('Checkout') {
            agent any
            steps {
                checkout scm
            }
        }

        stage('Verify Docker') {
            steps {
                sh 'whoami'
                sh 'apt-get update'
                sh 'apt-get install -y docker.io curl ca-certificates'
                sh 'docker --version'
                sh 'docker ps'

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
                DOCKER_CONFIG = "$WORKSPACE/.docker"
            }
            steps {
                sh '''
                    set -e
                    mkdir -p "$DOCKER_CONFIG"
                    docker version
                    docker build --no-cache --pull -t "$DOCKER_IMAGE" .
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
                    trivy image --severity HIGH,CRITICAL --no-progress "$DOCKER_IMAGE" || true
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
                DOCKER_CONFIG = "$WORKSPACE/.docker"
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ecr-creds'
                ]]) {
                    sh '''
                        set -e
                        mkdir -p "$DOCKER_CONFIG"
                        aws --version
                        aws sts get-caller-identity
                        aws ecr get-login-password --region "$AWS_REGION" | \
                        docker login --username AWS --password-stdin \
                        "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
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
                DOCKER_CONFIG = "$WORKSPACE/.docker"
            }
            steps {
                sh '''
                    set -e
                    docker push "$DOCKER_IMAGE"
                '''
            }
        }
    }
}
