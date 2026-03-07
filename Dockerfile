# Use the official Node.js image
FROM node:18

# Set the working directory
WORKDIR /HCLhackathon

# Clear npm cache
RUN npm cache clean --force

# Install supporting packages
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
