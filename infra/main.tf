resource "aws_ecr_repository" "app" {
  name                 = "jenkins-demo"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the latest ten demo images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_security_group" "jenkins" {
  name_prefix = "jenkins-demo-"
  description = "Jenkins UI restricted to the configured administrator IP"
  vpc_id      = data.aws_eks_cluster.target.vpc_config[0].vpc_id

  ingress {
    description = "Jenkins web UI from administrator IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_ui_cidr]
  }

  egress {
    description = "Outbound access for package downloads and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_to_eks_api" {
  security_group_id            = data.aws_eks_cluster.target.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.jenkins.id
  description                  = "Jenkins EC2 to private EKS Kubernetes API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_iam_role" "jenkins" {
  name_prefix = "jenkins-demo-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "jenkins" {
  name = "jenkins-ecr-push-eks-deploy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushDemoImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid      = "DescribeTargetCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = data.aws_eks_cluster.target.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jenkins" {
  name_prefix = "jenkins-demo-"
  role        = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = data.aws_subnet.jenkins.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  user_data                   = file("${path.module}/jenkins-user-data.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-demo"
  }
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = data.aws_eks_cluster.target.name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins_demo_namespace" {
  cluster_name  = data.aws_eks_cluster.target.name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["demo"]
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
