#!/bin/bash

# Variables
KEY_NAME="master1"  # Change this to your desired key name
KEY_PATH="$HOME/.ssh/$KEY_NAME"
REMOTE_HOST="192.168.0.121"  # Change this to the remote host
USERNAME="master"  # Change this to your username

# Check if the SSH key already exists
if [ -f "$KEY_PATH" ]; then
  echo "SSH key already exists at $KEY_PATH. Skipping key generation."
else
  # Generate RSA key
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N ""
  echo "SSH key generated at $KEY_PATH."
fi

# Add configuration to .ssh/config if not already added
if ! grep -q "Host $REMOTE_HOST" "$HOME/.ssh/config"; then
  echo -e "\nHost $REMOTE_HOST\n  HostName $REMOTE_HOST\n  User $USERNAME\n  IdentityFile $KEY_PATH" >> "$HOME/.ssh/config"
  echo "Configuration added to ~/.ssh/config."
else
  echo "Configuration for $REMOTE_HOST already exists in ~/.ssh/config."
fi

# Set correct permissions
chmod 600 "$HOME/.ssh/config"
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

# Copy the public key to the remote host
echo "Copying public key to remote host..."
ssh-copy-id -i "$KEY_PATH.pub" "$USERNAME@$REMOTE_HOST"

# Test the SSH connection
echo "Testing SSH connection..."
ssh -i "$KEY_PATH" "$USERNAME@$REMOTE_HOST" "echo 'SSH connection successful!'"

# Display success message
echo "SSH key generated (if not already existing), configuration updated, public key copied, and SSH connection tested successfully."
