pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        AWS_REGION = 'ap-southeast-2'
        EKS_CLUSTER_NAME = 'k8s-training-dev'
        ECR_REPOSITORY = 'jenkins-demo'
        K8S_NAMESPACE = 'demo'
        HELM_RELEASE = 'demo-app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build and push image') {
            steps {
                sh '''
                    set -eu
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    IMAGE_TAG="${BUILD_NUMBER}-$(git rev-parse --short=8 HEAD)"

                    aws ecr get-login-password --region "$AWS_REGION" |
                      docker login --username AWS --password-stdin "$REGISTRY"

                    docker build --pull \
                      --file app/Dockerfile \
                      --tag "${REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}" \
                      app
                    docker push "${REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
                '''
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                sh '''
                    set -eu
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    IMAGE_TAG="${BUILD_NUMBER}-$(git rev-parse --short=8 HEAD)"

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    helm upgrade --install "$HELM_RELEASE" ./helm/demo-app \
                      --namespace "$K8S_NAMESPACE" \
                      --set image.repository="${REGISTRY}/${ECR_REPOSITORY}" \
                      --set-string image.tag="$IMAGE_TAG" \
                      --wait \
                      --timeout 5m

                    kubectl rollout status \
                      "deployment/${HELM_RELEASE}" \
                      --namespace "$K8S_NAMESPACE" \
                      --timeout=180s
                '''
            }
        }
    }
}
