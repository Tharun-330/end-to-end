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

        stage('Verify Docker') {
            steps {
                sh 'whoami'
                sh 'apt-get update'
                sh 'apt-get install -y docker.io'
                sh 'docker --version'
                sh ' curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl'
                sh 'docker ps'
                sh 'kubectl version --client'

            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            agent {
                docker {
                    image 'docker:27-cli'
                    args '-v /var/run/docker.sock:/var/run/docker.sock --entrypoint=""'
                    reuseNode true
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
                      -v /var/run/docker.sock:/var/run/docker.sock --entrypoint=""
                      -v $WORKSPACE/.trivycache:/trivy-cache
                    '''
                    reuseNode true
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
                    args '-v /var/run/docker.sock:/var/run/docker.sock --entrypoint=""'
                    reuseNode true
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
                    args '-v /var/run/docker.sock:/var/run/docker.sock --entrypoint=""'
                    reuseNode true
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

        stage('Deploy to Kubernetes (KIND)') {
            environment {
                KUBECONFIG = "/var/jenkins_home/.kube/config"
            }
            steps {
                sh '''
                    set -e
        
                    echo "Using kubeconfig:"
                    ls -l "$KUBECONFIG"
        
                    echo "kubectl config view (sanity check)"
                    kubectl config view --minify || true
        
                    echo "Verifying cluster access"
                    kubectl --kubeconfig "$KUBECONFIG" get nodes
        
                    echo "Ensuring namespace exists"
                    kubectl --kubeconfig "$KUBECONFIG" get ns qa || \
                    kubectl --kubeconfig "$KUBECONFIG" create ns qa
        
                    echo "Deploying manifests"
                    kubectl --kubeconfig "$KUBECONFIG" apply -n qa -f k8s/qa/
        
                    echo "Waiting for rollout"
                    kubectl --kubeconfig "$KUBECONFIG" rollout status deployment/myapp -n qa
                '''
            }
        }
    }
}
