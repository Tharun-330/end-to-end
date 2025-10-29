# DevOps-CI-CD-MultiEnv (Jenkins + GitHub + ECR + Minikube)

This repository is a ready-to-run example for Option B:
- Source control: GitHub
- CI/CD: Jenkins (pipeline defined in Jenkinsfile)
- Container registry: Amazon ECR
- Local Kubernetes for testing: Minikube
- Deployment: Helm chart (helm/myapp)

## Quickstart (Local + Jenkins host)

1. Install required tools on Jenkins host:
   - Docker
   - Jenkins
   - kubectl
   - helm
   - minikube
   - awscli
   - trivy

2. Prepare Minikube on the Jenkins host (or make sure Jenkins can access an existing Minikube):
   ```bash
   minikube start --driver=docker
   kubectl create namespace dev || true
   kubectl create namespace qa || true
   kubectl create namespace prod || true
   ```

3. Create ECR repository:
   ```bash
   aws ecr create-repository --repository-name myapp-repo
   ```

4. Add Jenkins credentials:
   - Add AWS credentials in Jenkins (credentialsId: aws-credentials)
   - Ensure Jenkins user has Docker access and minikube is accessible

5. Run pipeline:
   - Create a new pipeline job in Jenkins pointing to this repository
   - Run the job. It will build, scan, push to ECR, load image into Minikube, and deploy via Helm.

## Notes
- For production pipelines, tighten Trivy exit codes, add policy gates, and separate clusters per environment.
- The GitHub Actions workflow included is a helper for building/tests but Jenkins is the primary CI in this setup.
