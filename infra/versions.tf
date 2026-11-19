terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_partition" "current" {}

data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.target.vpc_config[0].vpc_id]
  }

  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }
}

data "aws_subnet" "jenkins" {
  id = sort(data.aws_subnets.public.ids)[0]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
