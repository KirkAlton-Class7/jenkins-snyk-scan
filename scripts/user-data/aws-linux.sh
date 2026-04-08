#!/bin/bash

# ----------------------------------------------------------------------
# Jenkins + Terraform + Snyk dependencies installer for Amazon Linux 2023
# Includes: Java 21, Jenkins, Terraform, Git, AWS CLI, plugin manager
# ----------------------------------------------------------------------

set -e  # exit on any error

# Update and install base packages
dnf update -y
dnf install -y dnf-plugins-core wget unzip git

# Add HashiCorp repo for Terraform
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# Add Jenkins repo and import key
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins, Terraform, Java 21, fontconfig (needed for some reports)
dnf install -y java-21-amazon-corretto-devel fontconfig terraform jenkins

# ----------------------------------------------------------------------
# Install AWS CLI v2 (official bundled installer)
# ----------------------------------------------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ----------------------------------------------------------------------
# Configure Jenkins temp directory
# ----------------------------------------------------------------------
mkdir -p /var/lib/jenkins/tmp
chown jenkins:jenkins /var/lib/jenkins/tmp
chmod 700 /var/lib/jenkins/tmp

mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.io.tmpdir=/var/lib/jenkins/tmp"
EOF

# ----------------------------------------------------------------------
# Install Jenkins plugins using plugin manager
# ----------------------------------------------------------------------
curl -fLs -o /tmp/jenkins-plugin-manager.jar \
  https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.14.0/jenkins-plugin-manager-2.14.0.jar

curl -fLs -o /tmp/plugins.yaml \
  https://raw.githubusercontent.com/aaron-dm-mcdonald/new-jenkins-s3-test/refs/heads/main/plugins.yaml

sudo -u jenkins java -jar /tmp/jenkins-plugin-manager.jar \
  --war /usr/share/java/jenkins.war \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --plugin-file /tmp/plugins.yaml

# ----------------------------------------------------------------------
# Start and enable Jenkins
# ----------------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now jenkins

echo "SUCCESS: Jenkins, Terraform, Git, and AWS CLI installed successfully."