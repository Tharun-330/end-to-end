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
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'b860cc13-aa91-451a-8eff-34525ed6f797']]) {
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
		
		stage('Create ECR Pull Secret in Minikube') {
			steps {
				withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'b860cc13-aa91-451a-8eff-34525ed6f797']]) {
					sh '''
						echo "🔑 Creating ECR pull secret in Minikube..."
						kubectl delete secret ecr-secret -n dev --ignore-not-found

						ECR_PASSWORD=$(aws ecr get-login-password --region ap-south-1)
						kubectl create secret docker-registry ecr-secret \
							--docker-server=132514887880.dkr.ecr.ap-south-1.amazonaws.com \
							--docker-username=AWS \
							--docker-password="$ECR_PASSWORD" \
							-n dev
					'''
				}
			}
		}

		stage('Deploy to Minikube Dev') {
			steps {
				echo "🚀 Deploying to DEV environment..."

				sh '''
					set -e

					kubectl config use-context minikube

					# Ensure namespace exists
					kubectl get ns dev >/dev/null 2>&1 || kubectl create ns dev

					# Replace image dynamically in manifest
					sed -i "s|REPLACE_IMAGE|${ECR_REPO}:${IMAGE_TAG}|g" k8s/dev/deployment.yaml

					# Apply manifests
					kubectl apply -n dev -f k8s/dev/deployment.yaml
					kubectl apply -n dev -f k8s/dev/service.yaml
					kubectl apply -n dev -f k8s/dev/ingress.yaml

					#force rollout to ensure update
					kubectl rollout restart deployment/myapp -n dev
					kubectl rollout status deployment/myapp -n dev
					

					echo "✅ Deployment completed successfully to dev !"
				'''
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

