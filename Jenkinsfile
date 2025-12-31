pipeline {
    agent any

    environment {
        APP_NAME = "my-app"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        DOCKER_IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
        PYTHON = "/usr/bin/python3"
		AWS_REGION = "ap-south-1"                  // ✅ change as needed
        ACCOUNT_ID = "132514887880"               // ✅ your AWS Account ID
        ECR_REPO = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
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
			agent {
				docker {
					image 'aquasec/trivy:latest'
					args '''
					  --user root \
					  --entrypoint="" \
					  -v /var/run/docker.sock:/var/run/docker.sock \
					  -v $WORKSPACE/.trivycache:/root/.cache
					'''
				}
			}
		
            steps {
                echo "🔍 Scanning Docker image with Trivy..."
                sh '''
                    set -e
					mkdir -p $WORKSPACE/.trivycache
                    trivy image --severity HIGH,CRITICAL --no-progress ${DOCKER_IMAGE} || true
                '''
            }
        }
		
        stage('Login to AWS ECR') {
			agent {
				docker {
					image 'amazon/aws-cli:latest'
					args '''--entrypoint="" -v /var/run/docker.sock:/var/run/docker.sock'''
				}
			}
            steps {
                echo "🔑 Logging in to AWS ECR..."
				withCredentials([[
					$class: 'AmazonWebServicesCredentialsBinding',
					credentialsId: 'b860cc13-aa91-451a-8eff-34525ed6f797'
				]]) {
					sh '''
                        set -ex
						
						# install docker cli inside aws-cli container
						yum install -y docker || apk add --no-cache docker-cli || true
						
						aws --version
						aws sts get-caller-identity
						
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        echo "✅ Successfully logged in to ECR!"
                    '''
                }
            }
        }
	}
    post {
        always {
            echo "🧾 Pipeline completed."
        }
        failure {
            echo "❌ Pipeline failed! Check logs above."
        }
        success {
            echo "✅ Pipeline executed successfully!"
        }
    }
}

