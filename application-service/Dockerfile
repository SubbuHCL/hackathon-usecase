# Use official Node.js runtime as base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application source
COPY src/ ./src/

# Expose port
EXPOSE 3001

# Set environment variable
ENV PORT=3001

# Run the application
CMD ["npm", "start"]
