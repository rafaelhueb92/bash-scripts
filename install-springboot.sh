#!/bin/bash

# Determine which shell configuration file to modify based on the shell in use
BASH_USE=""
if [ -n "$BASH_VERSION" ]; then
  BASH_USE="bash_profile"
elif [ -n "$ZSH_VERSION" ]; then
  BASH_USE="zshrc"
else
  echo "Unknown shell"
  exit 1
fi

# Function to install OpenJDK
install_java() {
  echo "Installing OpenJDK"
  if ! brew install openjdk@17; then
    echo "Failed to install openjdk@17 with brew."
    exit 1
  fi

  echo "Configuring Java Environment"
  # Ensure the lines are added to the correct profile
  echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.$BASH_USE
  echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.$BASH_USE

  # Reload profile to apply changes
  source ~/.$BASH_USE
}

# Check if Java is installed, and install if not
if ! command -v java > /dev/null 2>&1; then
    install_java
fi

# Function to install SDKMAN
install_sdkman() {
  echo "Installing SDKMAN!"
  if ! curl -s "https://get.sdkman.io" | bash; then
    echo "Failed to install SDKMAN."
    exit 1
  fi

  # Reload sdkman
  source "$HOME/.sdkman/bin/sdkman-init.sh"
}

# Check if SDKMAN is installed, and install if not
if ! command -v sdk > /dev/null 2>&1; then
    install_sdkman
fi

# Function to install Spring Boot
install_springboot() {
  echo "Installing Spring Boot"
  if ! sdk install springboot; then
    echo "Failed to install Spring Boot."
    exit 1
  fi
}

# Check if Spring Boot is installed, and install if not
if ! command -v spring > /dev/null 2>&1; then
    install_springboot
fi

echo "Spring Boot was installed successfully!"