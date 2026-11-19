#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
  ca-certificates curl fontconfig gnupg libharfbuzz0b unzip \
  openjdk-21-jre-headless docker.io

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get -o Acquire::Retries=5 update
apt-get -o Acquire::Retries=5 install -y --no-install-recommends jenkins

systemctl enable --now docker
usermod -aG docker jenkins

curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

curl -fsSLo /usr/local/bin/kubectl \
  https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl
chmod 0755 /usr/local/bin/kubectl

curl -fsSL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz \
  -o /tmp/helm.tar.gz
tar -xzf /tmp/helm.tar.gz -C /tmp
install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm

systemctl enable jenkins
systemctl restart jenkins
