module.exports = {
  apps: [
    {
      name: 'spr-backend-staging',
      script: process.env.PYTHON_PATH || '/path/to/python/venv/bin/python',
      args: 'spr_backend_complete_fixed.py',
      cwd: process.env.APP_ROOT || '/home/app/spr/',
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '256M', // Reduced memory for staging
      env: {
        NODE_ENV: 'staging',
        PORT: process.env.STAGING_PORT || 3003,
        LOG_LEVEL: process.env.LOG_LEVEL || 'debug',
        DATABASE_URL: process.env.STAGING_DATABASE_URL,
        REDIS_URL: process.env.STAGING_REDIS_URL,
        JWT_SECRET: process.env.STAGING_JWT_SECRET,
        CORS_ORIGIN: process.env.STAGING_CORS_ORIGIN || 'https://staging.yourdomain.com'
      },
      log_file: process.env.LOG_PATH + '/staging-combined.log' || './logs/staging-combined.log',
      out_file: process.env.LOG_PATH + '/staging-out.log' || './logs/staging-out.log',
      error_file: process.env.LOG_PATH + '/staging-error.log' || './logs/staging-error.log',
      merge_logs: true,
      time: true,
      watch: true, // Enable watch for staging
      ignore_watch: [
        'node_modules',
        'logs',
        '*.log',
        '.git',
        'tmp'
      ],
      restart_delay: 2000, // Faster restart for staging
      min_uptime: '5s',
      max_restarts: 10, // More restarts allowed for staging
      kill_timeout: 3000
    }
  ]
};