# config/puma.rb
require "fileutils"
FileUtils.mkdir_p(%w[tmp/pids log])
FileUtils.mkdir_p("/run/nhs") rescue nil

env = ENV.fetch("RACK_ENV", ENV.fetch("APP_ENV", "development"))

environment env

# Threads/workers (tunable via ENV)
threads_count = Integer(ENV.fetch("PUMA_THREADS", ENV.fetch("RAILS_MAX_THREADS", 5)))
threads threads_count, threads_count
workers Integer(ENV.fetch("WEB_CONCURRENCY", env == "production" ? 2 : 0))

preload_app! if ENV.fetch("PUMA_PRELOAD", env == "production" ? "1" : "0") == "1"

# Bind: prefer UNIX socket in production; port elsewhere
if ENV["PUMA_BIND"]
  bind ENV["PUMA_BIND"]
elsif env == "production"
  bind ENV.fetch("PUMA_SOCKET", "unix:///var/run/nhs.sock")
else
  port Integer(ENV.fetch("PORT", 9292))
end

# Files
directory ENV.fetch("PUMA_WORKDIR", Dir.pwd)
pidfile ENV.fetch("PUMA_PIDFILE", "tmp/pids/puma.pid")
state_path ENV.fetch("PUMA_STATE_PATH", "tmp/pids/puma.state")

# Logging
stdout_redirect ENV.fetch("PUMA_STDOUT", "log/puma.stdout.log"),
                ENV.fetch("PUMA_STDERR", "log/puma.stderr.log"),
                true

# Timeouts
worker_timeout Integer(ENV.fetch("PUMA_WORKER_TIMEOUT", env == "development" ? 120 : 60))
worker_shutdown_timeout Integer(ENV.fetch("PUMA_WORKER_SHUTDOWN_TIMEOUT", 30))

# Hooks
on_worker_boot do
  # Reconnect resources if needed
end

plugin :tmp_restart
