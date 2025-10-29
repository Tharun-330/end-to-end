pipeline {
    agent any

    environment {
        APP_NAME = "my-app"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        AWS_REGION = "ap-south-1"
        ACCOUNT_ID = "132514887880"
        ECR_REPO = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
        DOCKER_IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
        PYTHON = "/usr/bin/python3"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                sh '''
                    set -e
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
                sh '''
                    . venv/bin/activate
                    pytest app/tests/ -v --junitxml=results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'results.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t ${DOCKER_IMAGE} .
                    docker images ${DOCKER_IMAGE} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKER_IMAGE}"
            }
        }

        stage('Push to AWS ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        docker push ${DOCKER_IMAGE}
                    '''
                }
            }
        }

        stage('Deploy to DEV') {
            steps {
                echo "🚀 Deploying to DEV..."
                sh '''
                    kubectl delete secret ecr-secret -n dev --ignore-not-found
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    kubectl create secret docker-registry ecr-secret \
                      --docker-server=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
                      --docker-username=AWS \
                      --docker-password-stdin \
                      --namespace=dev

                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/dev/deployment.yaml
                    kubectl apply -f k8s/dev/ -n dev
                    kubectl rollout status deployment/${APP_NAME} -n dev --timeout=60s
                '''
            }
        }

        stage('Approve for QA') {
            steps {
                input message: "✅ DEV Deployment successful. Approve to deploy to QA?"
            }
        }

        stage('Deploy to QA') {
            steps {
                echo "🚀 Deploying to QA..."
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    kubectl create secret docker-registry ecr-secret \
                      --docker-server=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
                      --docker-username=AWS \
                      --docker-password-stdin \
                      --namespace=qa

                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/qa/deployment.yaml
                    kubectl apply -f k8s/qa/ -n qa
                    kubectl rollout status deployment/${APP_NAME} -n qa --timeout=60s
                '''
            }
        }

        stage('Approve for UAT') {
            steps {
                input message: "✅ QA passed. Approve to deploy to UAT?"
            }
        }

        stage('Deploy to UAT') {
            steps {
                echo "🚀 Deploying to UAT..."
                sh '''
                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/uat/deployment.yaml
                    kubectl apply -f k8s/uat/ -n uat
                    kubectl rollout status deployment/${APP_NAME} -n uat --timeout=60s
                '''
            }
        }

        stage('Approve for PROD') {
            steps {
                input message: "✅ UAT approved. Deploy to PROD?"
            }
        }

        stage('Deploy to PROD') {
            steps {
                echo "🚀 Deploying to PROD..."
                sh '''
                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|g" k8s/prod/deployment.yaml
                    kubectl apply -f k8s/prod/ -n prod
                    kubectl rollout status deployment/${APP_NAME} -n prod --timeout=120s
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 All environments deployed successfully!"
        }
        failure {
            echo "❌ Pipeline failed — check logs."
        }
    }
}

