#!/bin/bash
# PM2 Startup Script for SPR System
# This script configures PM2 to automatically start on system boot

set -e

echo "Setting up PM2 for automatic startup..."

# Generate PM2 startup script
pm2 startup

echo "PM2 startup configuration completed."
echo "Run 'pm2 save' after starting your applications to save the current process list."

# Optional: Configure log rotation
pm2 install pm2-logrotate

# Configure log rotation settings
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 30
pm2 set pm2-logrotate:compress false
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss
pm2 set pm2-logrotate:workerInterval 30
pm2 set pm2-logrotate:rotateInterval 0 0 * * *

echo "PM2 log rotation configured successfully."
echo "Logs will be rotated daily and kept for 30 days."