pipeline {
    agent any

    environment {
        APP_NAME = "my-app"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        DOCKER_IMAGE = "tharunkumar/${APP_NAME}:${IMAGE_TAG}"
        PYTHON = "/usr/bin/python3"
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
                '''
            }
        }

        stage('Push Docker Image') {
            when {
                expression { return env.DOCKERHUB_CREDENTIALS != null }
            }
            steps {
                echo "Pushing image to DockerHub..."
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_IMAGE}
                    '''
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                echo "Deploying to local Minikube..."
                sh '''
                    set -e
                    kubectl config use-context minikube
                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/deployment.yaml
                    kubectl apply -f k8s/
                    kubectl rollout status deployment/${APP_NAME} --timeout=60s
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline completed."
        }
        failure {
            echo "Pipeline failed! Check the logs above."
        }
        success {
            echo "✅ Pipeline executed successfully!"
        }
    }
}

