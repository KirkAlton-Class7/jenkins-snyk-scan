#!/bin/bash

# ----------------------------------------------------------------------
# Jenkins + Terraform + Snyk dependencies installer for Ubuntu/Debian
# Includes: Java 21, Jenkins, Terraform, Git, AWS CLI, plugin manager
# ----------------------------------------------------------------------

set -e  # exit on any error

# Update and install base packages
apt-get update -y

# ----------------------------------------------------------------------
# Add HashiCorp repo for Terraform (apt)
# ----------------------------------------------------------------------
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# ----------------------------------------------------------------------
# Add Jenkins repo (apt)
# ----------------------------------------------------------------------
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# ----------------------------------------------------------------------
# Install Jenkins, Terraform, Java 21, fontconfig
# ----------------------------------------------------------------------
apt-get update -y
apt-get install -y fontconfig openjdk-21-jdk terraform jenkins

# ----------------------------------------------------------------------
# Install AWS CLI v2 (official bundled installer – universal)
# ----------------------------------------------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ----------------------------------------------------------------------
# Configure Jenkins temp directory (same as original)
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
# Install Jenkins plugins using plugin manager (same as original)
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

echo "SUCCESS: Jenkins, Terraform, Git, and AWS CLI installed successfully on Ubuntu/Debian."