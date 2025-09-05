#!/bin/bash
# PM2 Deployment Script for SPR System

set -e

ENVIRONMENT=${1:-production}
CONFIG_FILE="ecosystem.${ENVIRONMENT}.config.js"
APP_NAME="spr-backend-${ENVIRONMENT}"

echo "Deploying SPR backend in ${ENVIRONMENT} environment..."

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Load environment variables if .env file exists
if [ -f ".env.${ENVIRONMENT}" ]; then
    echo "Loading environment variables from .env.${ENVIRONMENT}"
    export $(cat .env.${ENVIRONMENT} | xargs)
fi

# Stop existing application if running
if pm2 list | grep -q "$APP_NAME"; then
    echo "Stopping existing $APP_NAME..."
    pm2 stop "$APP_NAME"
    pm2 delete "$APP_NAME"
fi

# Start application with new configuration
echo "Starting $APP_NAME with config $CONFIG_FILE..."
pm2 start "$CONFIG_FILE"

# Save PM2 process list
pm2 save

# Show application status
pm2 show "$APP_NAME"
pm2 logs "$APP_NAME" --lines 20

echo "Deployment completed successfully!"
echo "Application status: $(pm2 jlist | jq -r '.[] | select(.name=="'$APP_NAME'") | .pm2_env.status')"