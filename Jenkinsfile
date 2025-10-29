pipeline {
    agent any

    environment {
        AWS_REGION = "${env.AWS_REGION ?: 'us-east-1'}"
        AWS_ACCOUNT_ID = "${env.AWS_ACCOUNT_ID ?: '123456789012'}"
        ECR_REPOSITORY = "myapp-repo"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'pytest app/tests/'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
                '''
            }
        }

        stage('Scan Image') {
            steps {
                sh '''
                # run trivy but do not fail the pipeline here by default; change --exit-code to 1 to enforce
                trivy image --exit-code 0 --severity HIGH $ECR_REPOSITORY:$IMAGE_TAG || true
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                    docker tag $ECR_REPOSITORY:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
                    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Load Image to Minikube') {
            steps {
                sh '''
                minikube image load $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to Minikube via Helm') {
            steps {
                sh '''
                helm upgrade --install myapp-dev ./helm/myapp                     -f ./helm/myapp/values-dev.yaml                     --set image.repository=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY                     --set image.tag=$IMAGE_TAG                     --namespace dev
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Deployment successful!"
        }
        failure {
            echo "❌ Deployment failed!"
        }
    }
}
