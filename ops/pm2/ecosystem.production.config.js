module.exports = {
  apps: [
    {
      name: 'spr-backend-production',
      script: process.env.PYTHON_PATH || '/path/to/python/venv/bin/python',
      args: 'spr_backend_complete_fixed.py',
      cwd: process.env.APP_ROOT || '/home/app/spr/',
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: process.env.BACKEND_PORT || 3002,
        LOG_LEVEL: process.env.LOG_LEVEL || 'info',
        DATABASE_URL: process.env.DATABASE_URL,
        REDIS_URL: process.env.REDIS_URL,
        JWT_SECRET: process.env.JWT_SECRET,
        CORS_ORIGIN: process.env.CORS_ORIGIN || 'https://yourdomain.com'
      },
      log_file: process.env.LOG_PATH + '/combined.log' || './logs/combined.log',
      out_file: process.env.LOG_PATH + '/out.log' || './logs/out.log',
      error_file: process.env.LOG_PATH + '/error.log' || './logs/error.log',
      merge_logs: true,
      time: true,
      watch: false,
      ignore_watch: [
        'node_modules',
        'logs',
        '*.log',
        '.git',
        'tmp'
      ],
      restart_delay: 4000,
      min_uptime: '10s',
      max_restarts: 5,
      kill_timeout: 5000,
      // Health check configuration
      health_check_endpoint: 'http://localhost:' + (process.env.BACKEND_PORT || 3002) + '/health',
      // Graceful shutdown
      listen_timeout: 3000,
      kill_retry_time: 100
    }
  ]
};