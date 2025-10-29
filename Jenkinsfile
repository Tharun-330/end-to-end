pipeline {
    agent any

    parameters {
        string(name: 'TARGET_ENV', defaultValue: '', description: 'Environment to deploy (dev, qa, prod)')
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
                apt-get update -y
                apt-get install -y python3 python3-pip python3-venv
                python3 -m venv venv
                . venv/bin/activate
                pip install --upgrade pip
                pip install -r app/requirements.txt
                pip install pytest
                '''
            }
        }

        stage('Run Unit Tests') {
            steps {
                sh '''
                set -e
                . venv/bin/activate
                pytest app/tests/ -v --junitxml=results.xml
                '''
            }
            post {
                always {
                    junit 'results.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                set -e
                docker build -t myapp:latest .
                '''
            }
        }

        stage('Image Scan') {
            when {
                expression { fileExists('scripts/image_scan.sh') }
            }
            steps {
                sh '''
                chmod +x scripts/image_scan.sh
                ./scripts/image_scan.sh
                '''
            }
        }

        stage('Helm Deploy') {
            when {
                expression { params.TARGET_ENV != '' }
            }
            steps {
                sh '''
                set -e
                if ! command -v helm > /dev/null; then
                    echo "Helm not installed on Jenkins agent. Skipping deployment."
                    exit 0
                fi

                VALUES_FILE="helm/myapp/values-${TARGET_ENV}.yaml"
                if [ ! -f "$VALUES_FILE" ]; then
                    echo "Values file not found: $VALUES_FILE"
                    exit 1
                fi

                helm upgrade --install myapp-${TARGET_ENV} helm/myapp -f $VALUES_FILE
                '''
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully.'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
        always {
            sh 'rm -rf venv || true'
        }
    }
}
