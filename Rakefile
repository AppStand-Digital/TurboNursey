require "fileutils"
require "securerandom"

APP_DOMAIN       = ENV.fetch("APP_DOMAIN", "localhost")
PROJECT_ROOT     = Dir.pwd
LOG_DIR          = File.join(PROJECT_ROOT, "log")
TMP_DIR          = File.join(PROJECT_ROOT, "tmp")
PIDS_DIR         = File.join(TMP_DIR, "pids")
PUBLIC_DIR       = File.join(PROJECT_ROOT, "public")

UWSGI_USER       = ENV.fetch("UWSGI_USER", "turbo-matron")
UWSGI_GROUP      = ENV.fetch("UWSGI_GROUP", "www-data")

UWSGI_SOCKET     = "/run/nhs/nhs.sock"
UWSGI_INI        = "/etc/uwsgi/apps-available/nhs.ini"
UWSGI_LINK       = "/etc/uwsgi/apps-enabled/nhs.ini"
UWSGI_LOG_FILE   = File.join(LOG_DIR, "uwsgi.log")
UWSGI_PIDFILE    = File.join(PIDS_DIR, "uwsgi.pid")

RAKE_STDOUT_LOG  = File.join(LOG_DIR, "rake_stdout.log")
RAKE_ERROR_LOG   = File.join(LOG_DIR, "rake_error.log")

NGINX_SITE_AVAIL = "/etc/nginx/sites-available/nhs"
NGINX_SITE_ENABL = "/etc/nginx/sites-enabled/nhs"

PUMA_SOCKET_PATH = "/var/run/nhs.sock"

def setup_rake_logging
  begin
    FileUtils.mkdir_p(LOG_DIR)
    File.open(RAKE_STDOUT_LOG, "a") {}
    File.open(RAKE_ERROR_LOG, "a")  {}
    $stdout.reopen(RAKE_STDOUT_LOG, "a")
    $stdout.sync = true
    $stderr.reopen(RAKE_ERROR_LOG, "a")
    $stderr.sync = true
  rescue => e
    warn "Skipping Rake file logging (#{e.class}: #{e.message})"
  end
end

setup_rake_logging

# Use Puma everywhere (drop uWSGI start)
desc "Start app with Puma using UNIX socket (non-root)"
task :start do
  assert_not_root!("start Puma")
  # Ensure socket dir exists and is accessible to Nginx
  sh "sudo mkdir -p /var/run"
  sh "sudo touch #{PUMA_SOCKET_PATH} || true"
  sh "sudo chown #{ENV['USER']}:www-data /var/run"
  sh "sudo chmod 0770 /var/run"
  sh "sudo rm -f #{PUMA_SOCKET_PATH} || true"
  # Bind Puma to the shared socket path for Nginx
  sh "PUMA_BIND=unix://#{PUMA_SOCKET_PATH} bundle exec puma -C config/puma.rb"
end

desc "Stop app (Puma) best-effort"
task :stop do
  sh "pkill -TERM -f 'puma .*config/puma.rb' || true"
  sh "sleep 1"
  sh "rm -f #{PUMA_SOCKET_PATH} || true"
end

desc "Restart app (Puma)"
task :restart => [:stop, :start]

# Keep a single set of nginx install tasks; ensure they emit Puma proxy config
def inx_site_config_http
  <<-CONF
server {
  listen 80;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_redirect off;
    proxy_pass http://unix:#{PUMA_SOCKET_PATH}:
  }

  access_log /var/log/nginx/nhs.access.log;
  error_log  /var/log/nginx/nhs.error.log;
}
  CONF
end
# Generate a secure SESSION_SECRET and persist into .env if missing or invalid (<64 bytes)
desc "Generate a secure SESSION_SECRET in .env (non-root)"
task :generate_session_secret do
  assert_not_root!("generate session secret")
  env_path = File.join(PROJECT_ROOT, ".env")
  FileUtils.touch(env_path) unless File.exist?(env_path)

  text = File.binread(env_path)
  # Match SESSION_SECRET on its own line, ignoring comments/whitespace
  line_re = /^\s*SESSION_SECRET\s*=\s*.*$/i

  # Extract current value if present
  current = if text =~ line_re
              text[line_re].sub(/^\s*SESSION_SECRET\s*=\s*/i, "").strip.gsub(/\A['"]|['"]\z/, "")
            end

  def valid_secret?(s)
    s && s.bytesize >= 64
  end

  if valid_secret?(current)
    puts "SESSION_SECRET already valid in .env"
  else
    new_secret = SecureRandom.hex(64) # 64 bytes -> 128 hex chars
    if text =~ line_re
      text = text.gsub(line_re, "SESSION_SECRET=#{new_secret}")
    else
      sep = text.end_with?("\n") ? "" : "\n"
      text = "#{text}#{sep}SESSION_SECRET=#{new_secret}\n"
    end
    File.binwrite(env_path, text)
    puts "SESSION_SECRET written to .env"
  end
end

# Puma control
desc "Start app with Puma using UNIX socket (non-root)"
task :start do
  assert_not_root!("start Puma")
  sh "sudo mkdir -p /var/run"
  sh "sudo chown #{ENV['USER']}:www-data /var/run"
  sh "sudo chmod 0770 /var/run"
  sh "sudo rm -f #{PUMA_SOCKET_PATH} || true"
  sh "PUMA_BIND=unix://#{PUMA_SOCKET_PATH} bundle exec puma -C config/puma.rb"
end

def assert_not_root!(action = "run this task")
  abort "Refusing to #{action} as root. Please run as a non-root user." if Process.uid.zero?
end

def ensure_dirs
  FileUtils.mkdir_p [LOG_DIR, TMP_DIR, PIDS_DIR, PUBLIC_DIR]
  begin
    FileUtils.mkdir_p File.dirname(UWSGI_SOCKET)
  rescue
    # ignore; created via sudo step
  end
end

def write_file_with_parents(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

def user_in_group?(user, group)
  groups = `id -nG #{user} 2>/dev/null`.split
  groups.include?(group)
end

def warn_if_user_not_in_group
  unless user_in_group?(UWSGI_USER, UWSGI_GROUP)
    warn "WARNING: User '#{UWSGI_USER}' is not in group '#{UWSGI_GROUP}'. "\
         "Nginx may see 502/permission errors on #{UWSGI_SOCKET}. "\
         "Consider: sudo usermod -aG #{UWSGI_GROUP} #{UWSGI_USER} && newgrp #{UWSGI_GROUP}"
  end
end

def sudo_hint
  puts "\nNext steps (run as root):"
  puts "sudo rake nginx_install"
  puts "  "
end
    plugin-dir = /usr/local/lib/uwsgi
    plugins = rack_plugin
    module = rack
    rack = config.ru
    master = true
    processes = #{ENV.fetch("UWSGI_PROCESSES", "2")}
    threads = 1
    socket = #{UWSGI_SOCKET}
    vacuum = true
    chmod-socket = 660
    uid = #{UWSGI_USER}
    gid = #{UWSGI_GROUP}
    die-on-term = true
    lazy-apps = true
    pidfile = #{UWSGI_PIDFILE}
    daemonize = #{UWSGI_LOG_FILE}
end

def nginx_site_config_http
  <<-CONF
server {
  listen 80;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_redirect off;

    proxy_pass http://unix:#{PUMA_SOCKET_PATH}:
  }

  access_log /var/log/nginx/nhs.access.log;
  error_log  /var/log/nginx/nhs.error.log;
}
  CONF
end

def nginx_site_config_https
  cert = ENV.fetch("NGINX_SSL_CERT", "/etc/ssl/certs/ssl-cert-snakeoil.pem")
  key  = ENV.fetch("NGINX_SSL_KEY",  "/etc/ssl/private/ssl-cert-snakeoil.key")
  <<-CONF
server {
  listen 443 ssl http2;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  ssl_certificate     #{cert};
  ssl_certificate_key #{key};
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:10m;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;

  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;
    proxy_redirect off;

    proxy_pass http://unix:#{PUMA_SOCKET_PATH}:
  }

  access_log /var/log/nginx/nhs.access.ssl.log;
  error_log  /var/log/nginx/nhs.error.ssl.log;
}
  CONF
end

def remove_stale_socket
  begin
    File.delete(UWSGI_SOCKET) if File.exist?(UWSGI_SOCKET) && !File.socket?(UWSGI_SOCKET)
  rescue
    # best-effort
  end
end

desc "Create and switch to the env-domain branch"
task :git_branch do
  branch = "env-domain"
  current = `git rev-parse --abbrev-ref HEAD`.strip
  if current != branch
    exists = `git branch --list #{branch}`.strip
    sh(exists.empty? ? "git checkout -b #{branch}" : "git checkout #{branch}")
  end
  puts "On branch #{branch}"
end

# ... existing code ...
desc "Install gems (never as root)"
task :bundle do
  assert_not_root!("run bundler")
  sh "bundle install"
end

desc "Setup (non-root): create dirs, ensure gems, verify groups. Print next sudo steps."
task :setup => [:bundle] do
  assert_not_root!("run setup")
  puts "Setting up for domain '#{APP_DOMAIN}' as user '#{UWSGI_USER}' (group '#{UWSGI_GROUP}')..."
  ensure_dirs
  warn_if_user_not_in_group
  sudo_hint
end

desc "Install uWSGI Rack plugin (Debian/Ubuntu) - root required"
task :uwsgi_plugin_install do
  require_root!("uwsgi_plugin_install")
  sh "apt-get update"
  sh "apt-get install -y uwsgi-plugin-rack-ruby"
end

desc "Install uWSGI ini to #{UWSGI_INI} and enable it (sudo required)"
task :uwsgi_install => [:uwsgi_plugin_install] do
  require_root!("uwsgi_install")
  ensure_dirs
  FileUtils.mkdir_p File.dirname(UWSGI_LOG_FILE)
  write_file_with_parents(UWSGI_INI, uwsgi_ini_content)
  FileUtils.ln_sf(UWSGI_INI, UWSGI_LINK)

  dir = File.dirname(UWSGI_SOCKET)
  FileUtils.mkdir_p dir
  sh "chown #{UWSGI_USER}:#{UWSGI_GROUP} #{dir}"
  sh "chmod 0770 #{dir}"

  warn_if_user_not_in_group
  puts "Installed uWSGI ini and enabled."
end

desc "Install/refresh nginx HTTP site (sudo required)"
task :nginx_install_http do
  require_root!("nginx_install_http")
  ensure_dirs
  write_file_with_parents(NGINX_SITE_AVAIL, nginx_site_config_http)
  FileUtils.ln_sf(NGINX_SITE_AVAIL, NGINX_SITE_ENABL)
  sh "nginx -t"
  sh "service nginx reload"
end

desc "Install/refresh nginx HTTPS site (sudo required)"
task :nginx_install_https do
  require_root!("nginx_install_https")
  ensure_dirs
  cert = ENV.fetch("NGINX_SSL_CERT", "/etc/ssl/certs/ssl-cert-snakeoil.pem")
  key  = ENV.fetch("NGINX_SSL_KEY",  "/etc/ssl/private/ssl-cert-snakeoil.key")
  warn "WARNING: SSL cert not found at #{cert}" unless File.exist?(cert)
  warn "WARNING: SSL key not found at #{key}"   unless File.exist?(key)
  write_file_with_parents(NGINX_SITE_AVAIL, nginx_site_config_https)
  FileUtils.ln_sf(NGINX_SITE_AVAIL, NGINX_SITE_ENABL)
  sh "nginx -t"
  sh "service nginx reload"
end

desc "Install/refresh nginx site (NGINX_SSL=http|https) (sudo required)"
task :nginx_install do
  require_root!("nginx_install")
  mode = ENV.fetch("NGINX_SSL", "http") # http | https
  case mode
  when "http"  then Rake::Task[:nginx_install_http].invoke
  when "https" then Rake::Task[:nginx_install_https].invoke
  else
    abort "Unknown NGINX_SSL mode: #{mode} (expected http|https)"
  end
end

desc "Restart nginx"
task :nginx_restart do
  sh "sudo nginx -t && sudo service nginx restart"
end

desc "Full deploy (Puma + Nginx reload)"
task :deploy => [:setup, :generate_session_secret, :start, :nginx_restart]

desc "Uninstall: stop app, remove Nginx site, remove socket and state (sudo required for Nginx/system paths)"
task :uninstall do
  # Stop Puma (non-root)
  Rake::Task[:stop].invoke rescue nil

  # Remove Nginx site (root)
  begin
    require_root!("uninstall (nginx cleanup)")
  rescue SystemExit
    puts "Skipping Nginx cleanup (not root). Run: sudo rake uninstall to fully remove Nginx site."
  else
    begin
      sh "rm -f #{NGINX_SITE_ENABL}"
      sh "rm -f #{NGINX_SITE_AVAIL}"
      sh "nginx -t"
      sh "service nginx reload"
    rescue => e
      warn "Nginx cleanup warning: #{e}"
    end
  end

  # Remove sockets/state/log symlinks (best-effort)
  begin
    sh "rm -f #{PUMA_SOCKET_PATH} || true"
  rescue
  end

  # Project-local cleanup (non-root)
  begin
    FileUtils.rm_f(File.join(PIDS_DIR, "puma.pid"))
    FileUtils.rm_f(File.join(TMP_DIR, "puma.state"))
  rescue => e
    warn "Local cleanup warning: #{e}"
  end

  puts "Uninstall completed (app stopped; Nginx site removed if run as root)."
end

desc "Reinstall: uninstall then deploy"
task :reinstall => [:uninstall, :deploy]
