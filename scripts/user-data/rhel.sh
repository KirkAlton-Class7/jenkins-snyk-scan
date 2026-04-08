#!/bin/bash
# ----------------------------------------------------------------------
# Jenkins + Terraform + Snyk dependencies installer for Ubuntu/Debian
# Includes: Java 21, Jenkins, Terraform, Git, AWS CLI, plugin manager
# ----------------------------------------------------------------------

set -euo pipefail   # strict mode: exit on error, undefined var, pipefail

# ------------------------------------------------------------
# Helper: print error and exit
# ------------------------------------------------------------
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# ------------------------------------------------------------
# Check we are root
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root (use sudo)."
fi

echo "=== Updating package list and installing base tools ==="
apt-get update -y || die "apt-get update failed"
apt-get install -y wget unzip git curl gnupg lsb-release || die "Failed to install base packages"

# ------------------------------------------------------------
# Add HashiCorp repo for Terraform
# ------------------------------------------------------------
echo "=== Adding HashiCorp repository ==="
# Download and add GPG key
if ! wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg; then
    die "Failed to download/import HashiCorp GPG key"
fi
# Add repository (explicit arch=amd64 to avoid arm64 issues)
REPO_URL="deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
echo "$REPO_URL" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null || die "Failed to write HashiCorp repo file"

# ------------------------------------------------------------
# Add Jenkins repo
# ------------------------------------------------------------
echo "=== Adding Jenkins repository ==="
if ! curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null; then
    die "Failed to download Jenkins GPG key"
fi
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null || die "Failed to write Jenkins repo file"

# ------------------------------------------------------------
# Install packages
# ------------------------------------------------------------
echo "=== Installing Terraform, Jenkins, Java 21, and fontconfig ==="
apt-get update -y || die "apt-get update after adding repos failed"
apt-get install -y fontconfig openjdk-21-jdk terraform jenkins || die "Failed to install required packages"

# ------------------------------------------------------------
# Install AWS CLI v2
# ------------------------------------------------------------
echo "=== Installing AWS CLI v2 ==="
if ! curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"; then
    die "Failed to download AWS CLI installer"
fi
unzip -q /tmp/awscliv2.zip -d /tmp || die "Failed to unzip AWS CLI"
/tmp/aws/install || die "AWS CLI installation failed"
rm -rf /tmp/aws /tmp/awscliv2.zip

# ------------------------------------------------------------
# Configure Jenkins temp directory
# ------------------------------------------------------------
echo "=== Configuring Jenkins temp directory ==="
mkdir -p /var/lib/jenkins/tmp || die "Cannot create Jenkins temp dir"
chown jenkins:jenkins /var/lib/jenkins/tmp || die "Cannot change ownership of temp dir"
chmod 700 /var/lib/jenkins/tmp || die "Cannot set permissions on temp dir"

mkdir -p /etc/systemd/system/jenkins.service.d || die "Cannot create systemd override directory"
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF' || die "Cannot write systemd override file"
[Service]
Environment="JAVA_OPTS=-Djava.io.tmpdir=/var/lib/jenkins/tmp"
EOF

# ------------------------------------------------------------
# Install Jenkins plugins (using plugin manager)
# ------------------------------------------------------------
echo "=== Installing Jenkins plugins ==="
# Download plugin manager JAR
if ! curl -fLs -o /tmp/jenkins-plugin-manager.jar \
    https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.14.0/jenkins-plugin-manager-2.14.0.jar; then
    die "Failed to download Jenkins plugin manager"
fi

# Download plugin list
if ! curl -fLs -o /tmp/plugins.yaml \
    https://raw.githubusercontent.com/aaron-dm-mcdonald/new-jenkins-s3-test/refs/heads/main/plugins.yaml; then
    die "Failed to download plugins.yaml"
fi

# Run plugin manager as jenkins user (jenkins user must exist – it does after package install)
if ! sudo -u jenkins java -jar /tmp/jenkins-plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugin-file /tmp/plugins.yaml; then
    die "Jenkins plugin installation failed"
fi

# ------------------------------------------------------------
# Start and enable Jenkins
# ------------------------------------------------------------
echo "=== Starting Jenkins service ==="
systemctl daemon-reload || die "systemctl daemon-reload failed"
systemctl enable --now jenkins || die "Failed to enable/start Jenkins"

echo "=========================================="
echo "SUCCESS: Jenkins, Terraform, Git, and AWS CLI installed successfully on Ubuntu/Debian."
echo "   Jenkins is running. Access at http://$(hostname -I | awk '{print $1}'):8080"
echo "=========================================="