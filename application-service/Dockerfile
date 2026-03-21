# Use official Node LTS image
FROM gcr.io/google-appengine/nodejs

# Create app dir
WORKDIR /usr/src/app

# Copy package files first (for caching)
# Explanation: copying package*.json ensures dependencies are installed even if the source files are missing at build time.
COPY package*.json ./

# Install dependencies (non-root user recommended for production)
RUN npm install --production

# Copy app sources
COPY src/ ./src

# Expose port
EXPOSE 3001

# Default command
CMD ["node", "src/index.js"]
