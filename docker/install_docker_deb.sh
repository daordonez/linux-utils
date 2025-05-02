#!/usr/bin/env bash
set -euo pipefail

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root." >&2
  exit 1
fi

# 1. Check if Docker is already installed
if ! command -v docker &>/dev/null; then
  echo "Installing Docker on Debian..."

  # 2. Prepare APT and install prerequisites
  apt-get update
  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # 3. Create keyrings directory
  install -m 0755 -d /etc/apt/keyrings

  # 4. Download and install Docker’s official GPG key
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | tee /etc/apt/keyrings/docker.gpg > /dev/null
  chmod a+r /etc/apt/keyrings/docker.gpg

  # 5. Add Docker apt repository
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
     https://download.docker.com/linux/debian \
     $CODENAME stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # 6. Install Docker Engine and related components
  apt-get update
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  echo "Docker installed successfully. Running hello-world test container..."
  docker run --rm hello-world

  # 7. Add the invoking user to the docker group (if applicable)
  if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "User '$SUDO_USER' added to the 'docker' group. Please log out and back in for changes to take effect."
  else
    echo "No non-root user detected to add to 'docker' group."
  fi

else
  echo "Docker is already installed: $(docker --version)"
fi