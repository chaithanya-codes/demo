# Jenkins to ECR to EKS demo

This demo builds a small Python web app, pushes a uniquely tagged image to ECR, and deploys that exact image to EKS using Helm:

```text
Git push -> Jenkins on EC2 -> Docker build -> ECR -> Helm upgrade -> EKS
```

Jenkins uses an EC2 instance role rather than stored AWS access keys. Its EKS permissions are scoped to the `demo` namespace. The Jenkins UI security group only allows the administrator IP supplied during setup. Jenkins runs in the EKS VPC and connects to the private Kubernetes API endpoint.

## Prerequisites

- The `k8s-training-dev` EKS cluster and its worker nodes are `ACTIVE`/`Ready`.
- AWS CLI configured locally with permission to create IAM, EC2, ECR, and EKS access-entry resources.
- Terraform 1.5.7+, Git, and `kubectl` installed locally.
- A GitHub repository for the contents of this `jenkins-demo` folder.
- An administrator public IPv4 address. Jenkins port 8080 will be restricted to this `/32`.

Check the cluster and connect locally:

```powershell
aws eks describe-cluster --name k8s-training-dev --region ap-southeast-2 --query cluster.status --output text
aws eks update-kubeconfig --name k8s-training-dev --region ap-southeast-2
kubectl get nodes
```

Create the deployment namespace using your administrator kubeconfig. Jenkins is intentionally not allowed to create namespaces:

```powershell
kubectl create namespace demo
```

If it already exists, Kubernetes will report that; that is fine.

## Create Jenkins, ECR, and its EKS access

From PowerShell:

```powershell
Set-Location .\infra
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
```

Edit `terraform.tfvars` and replace `jenkins_ui_cidr` with your own public IPv4 address followed by `/32`. Do not use `0.0.0.0/0`.

```powershell
..\..\terraform.exe init
..\..\terraform.exe fmt
..\..\terraform.exe validate
..\..\terraform.exe plan
..\..\terraform.exe apply
```

Review the plan before approving. This creates a `t3.medium` Ubuntu EC2 instance, ECR repository, IAM role, EKS access entry, and security rules. The instance has a 30 GiB encrypted root disk. It adds AWS costs while running.

Get the UI address and instance ID:

```powershell
..\..\terraform.exe output
```

Wait several minutes for cloud-init to install Jenkins and the tools, then open the printed Jenkins URL. Retrieve the initial administrator password through Systems Manager (no SSH port is open):

```powershell
$instanceId = ..\..\terraform.exe output -raw jenkins_instance_id
aws ssm start-session --target $instanceId --region ap-southeast-2
```

In the Session Manager shell:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Finish the Jenkins web setup, install suggested plugins, and create an administrator account. The instance installs Java, Jenkins, Docker, AWS CLI v2, `kubectl`, and Helm.

## Put the demo in GitHub

Create a GitHub repository and push the contents of this `jenkins-demo` directory to its root. For a public repository:

```powershell
git init
git add .
git commit -m "Add Jenkins to ECR to EKS demo"
git branch -M main
git remote add origin https://github.com/YOUR-USER/YOUR-REPOSITORY.git
git push -u origin main
```

For a private repository, configure a GitHub credential in Jenkins and select it in the job's SCM configuration. Never put a GitHub token in the `Jenkinsfile`.

## Create the Jenkins pipeline job

1. In Jenkins, choose **New Item**, enter `eks-demo`, and select **Pipeline**.
2. Under **Pipeline**, choose **Pipeline script from SCM** and **Git**.
3. Set the repository URL and branch `*/main`. Set script path to `Jenkinsfile`.
4. Save, then choose **Build Now**.

The pipeline polls SCM every two minutes. A GitHub webhook can be added later; if doing so, secure the Jenkins endpoint and configure the GitHub plugin/webhook rather than opening port 8080 to everyone.

The pipeline:

1. Checks out source.
2. Builds `app/Dockerfile`.
3. Gets temporary ECR login credentials from the EC2 role and pushes a tag like `<build-number>-<git-sha>`.
4. Gets an EKS token using the EC2 role.
5. Runs `helm upgrade --install` with the exact image repository and tag.
6. Waits for the Kubernetes Deployment rollout.

## Verify the deployment

Locally:

```powershell
kubectl get deployments,pods,services -n demo
kubectl get pods -n demo -o wide
kubectl describe deployment demo-app -n demo
```

To try the app without exposing a public Service:

```powershell
kubectl port-forward -n demo service/demo-app 8080:80
```

Open `http://localhost:8080`. The response shows the Pod hostname and image version. Push a small change to `app/server.py`; Jenkins should build and deploy a new immutable image tag, and the response version should change.

## Clean up

First uninstall the Kubernetes release while the cluster is reachable:

```powershell
helm uninstall demo-app --namespace demo
```

Then destroy only this demo's EC2/ECR/access-entry resources:

```powershell
Set-Location .\infra
..\..\terraform.exe destroy
```

This Terraform state is separate from the EKS cluster state. Destroying this demo does not destroy EKS. The ECR repository is configured for deletion with its images when this disposable demo infrastructure is destroyed.

## Security and cost notes

- Port 8080 is restricted to one administrator IPv4 `/32`; there is no SSH ingress. Use Systems Manager for shell access.
- The Jenkins instance role can push only to this ECR repository, describe the target EKS cluster, and administer Kubernetes resources only in namespace `demo`.
- The instance uses Docker for this training pipeline; users able to control Jenkins builds can effectively control the Docker daemon. Treat Jenkins as privileged and do not expose it publicly.
- `t3.medium`, EBS, public IPv4, ECR storage, and the EKS cluster incur AWS charges. Destroy this demo when finished.
