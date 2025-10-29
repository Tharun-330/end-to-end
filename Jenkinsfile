pipeline {
    agent any

    environment {
        APP_NAME = "my-app"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        DOCKER_IMAGE = "tharunkumar/${APP_NAME}:${IMAGE_TAG}"
        PYTHON = "/usr/bin/python3"
	AWS_REGION = "ap-south-1"                  // ✅ change as needed
        ACCOUNT_ID = "123456789012"                // ✅ your AWS Account ID
        ECR_REPO = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
        DOCKER_IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                echo "Setting up Python virtual environment..."
                sh '''
                    set -e
                    if ! command -v python3 >/dev/null 2>&1; then
                        echo "Installing Python3..."
                        sudo apt-get update -y
                        sudo apt-get install -y python3 python3-pip python3-venv
                    fi

                    # Clean and recreate venv
                    rm -rf venv
                    ${PYTHON} -m venv venv
                    . venv/bin/activate

                    pip install --upgrade pip
                    pip install -r app/requirements.txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                echo "Running unit tests..."
                sh '''
                    set -e
                    . venv/bin/activate
                    chmod +x venv/bin/pytest  # ✅ Fix: ensure pytest is executable
                    pytest app/tests/ -v --junitxml=results.xml
                '''
            }
            post {
                always {
                    echo "Archiving test results..."
                    junit allowEmptyResults: true, testResults: 'results.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image..."
                sh '''
					set -e
                    docker build -t ${DOCKER_IMAGE} .
                    echo "✅ Docker image built successfully!"

                    echo "📦 Image details:"
                    docker images ${ECR_REPO} --format "Repository: {{.Repository}} | Tag: {{.Tag}} | Size: {{.Size}}"
                '''
            }
        }
		
        stage('Scan Docker Image (Trivy)') {
            steps {
                echo "🔍 Scanning Docker image with Trivy..."
                sh '''
                    set -e
                    trivy image --severity HIGH,CRITICAL --no-progress ${DOCKER_IMAGE} || true
                '''
            }
        }

        stage('Login to AWS ECR') {
            steps {
                echo "🔑 Logging in to AWS ECR..."
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-creds']]) {
                    sh '''
                        set -e
                        echo "Authenticating to AWS ECR..."
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        echo "✅ Successfully logged in to ECR!"
                    '''
                }
            }
        }

        stage('Push Docker Image to AWS ECR') {
            steps {
                echo "☁️ Pushing image to AWS ECR..."
                sh '''
                    set -e
                    docker push ${DOCKER_IMAGE}
                    echo "✅ Image pushed successfully: ${DOCKER_IMAGE}"
                '''
            }
        }

        stage('Deploy to Minikube') {
            steps {
                echo "🚀 Deploying to Minikube..."
                sh '''
                    set -e
                    kubectl config use-context minikube

                    echo "Updating Helm chart image to ${DOCKER_IMAGE} ..."
                    helm upgrade --install ${APP_NAME} helm/myapp \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        -f helm/myapp/values-dev.yaml \
                        --namespace dev --create-namespace

                    echo "✅ Deployment triggered successfully!"
                    kubectl get pods -n dev
                '''
            }
        }
    }

    post {
        always {
            echo "🏁 Pipeline completed."
        }
        failure {
            echo "❌ Pipeline failed! Check the logs above."
        }
        success {
            echo "✅ Pipeline executed successfully! Image: ${DOCKER_IMAGE}"
        }
    }
}
