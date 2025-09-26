require "fileutils"

APP_DOMAIN       = ENV.fetch("APP_DOMAIN", "localhost")
PROJECT_ROOT     = Dir.pwd
LOG_DIR          = File.join(PROJECT_ROOT, "log")
TMP_DIR          = File.join(PROJECT_ROOT, "tmp")
PIDS_DIR         = File.join(TMP_DIR, "pids")
PUBLIC_DIR       = File.join(PROJECT_ROOT, "public")

UWSGI_USER       = ENV.fetch("UWSGI_USER", "turbo-matron")
UWSGI_GROUP      = ENV.fetch("UWSGI_GROUP", "www-data")

UWSGI_SOCKET     = "/run/nhs/nhs.sock"
UWSGI_INI        = "/etc/uwsgi/apps-available/nhs.ini" # system path (needs sudo)
UWSGI_LINK       = "/etc/uwsgi/apps-enabled/nhs.ini"
UWSGI_LOG_FILE   = File.join(LOG_DIR, "uwsgi.log")
UWSGI_PIDFILE    = File.join(PIDS_DIR, "uwsgi.pid")

NGINX_SITE_AVAIL = "/etc/nginx/sites-available/nhs"
NGINX_SITE_ENABL = "/etc/nginx/sites-enabled/nhs"

def require_root!(task_name)
  abort "Run as root: sudo rake #{task_name}" unless Process.uid.zero?
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
  puts "sudo rake uwsgi_install && sudo rake nginx_install"
  puts "  "
end

def uwsgi_ini_content
  <<~INI
    [uwsgi]
    chdir = #{PROJECT_ROOT}
    plugin-dir = /usr/local/lib/uwsgi
    plugins = rack_plugin
    module = rack
    rack = config.ru
    master = true
    processes = #{ENV.fetch("UWSGI_PROCESSES", "2")}
    threads = #{ENV.fetch("UWSGI_THREADS", "4")}
    socket = #{UWSGI_SOCKET}
    vacuum = true
    chmod-socket = 660
    uid = #{UWSGI_USER}
    gid = #{UWSGI_GROUP}
    die-on-term = true
    lazy-apps = true
    pidfile = #{UWSGI_PIDFILE}
    daemonize = #{UWSGI_LOG_FILE}
  INI
end

def nginx_site_config_http
  <<-CONF
server {
  listen 80;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  location / {
    include uwsgi_params;
    uwsgi_pass unix://#{UWSGI_SOCKET};
    uwsgi_modifier1 7;
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
    include uwsgi_params;
    uwsgi_pass unix://#{UWSGI_SOCKET};
    uwsgi_modifier1 7;
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

desc "Install gems (never as root)"
task :bundle => :git_branch do
  assert_not_root!("run bundler")
  sh "bundle install"
end

desc "Setup (non-root): create dirs, ensure gems, verify groups. Print next sudo steps."
task :setup => [:git_branch, :bundle] do
  assert_not_root!("run setup")
  puts "Setting up for domain '#{APP_DOMAIN}' as user '#{UWSGI_USER}' (group '#{UWSGI_GROUP}')..."
  ensure_dirs
  warn_if_user_not_in_group
  sudo_hint
end

desc "Install uWSGI Rack plugin (Debian/Ubuntu) - root required"
task :uwsgi_plugin_install => :git_branch do
  require_root!("uwsgi_plugin_install")
  sh "apt-get update"
  sh "apt-get install -y uwsgi-plugin-rack-ruby"
end

desc "Install uWSGI ini to #{UWSGI_INI} and enable it (sudo required)"
task :uwsgi_install => [:git_branch, :uwsgi_plugin_install] do
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
task :nginx_install_http => :git_branch do
  require_root!("nginx_install_http")
  ensure_dirs
  write_file_with_parents(NGINX_SITE_AVAIL, nginx_site_config_http)
  FileUtils.ln_sf(NGINX_SITE_AVAIL, NGINX_SITE_ENABL)
  sh "nginx -t"
  sh "service nginx reload"
end

desc "Install/refresh nginx HTTPS site (sudo required)"
task :nginx_install_https => :git_branch do
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
task :nginx_install => :git_branch do
  require_root!("nginx_install")
  mode = ENV.fetch("NGINX_SSL", "http") # http | https
  case mode
  when "http"  then Rake::Task[:nginx_install_http].invoke
  when "https" then Rake::Task[:nginx_install_https].invoke
  else
    abort "Unknown NGINX_SSL mode: #{mode} (expected http|https)"
  end
end

desc "Start app with uWSGI using system ini (non-root)"
task :start => :git_branch do
  assert_not_root!("start uWSGI")
  ensure_dirs
  remove_stale_socket
  sh "uwsgi --ini #{UWSGI_INI}"
end

desc "Stop uWSGI (best-effort)"
task :stop => :git_branch do
  if File.exist?(UWSGI_PIDFILE)
    pid = File.read(UWSGI_PIDFILE).strip
    sh "kill -TERM #{pid} || true"
  else
    sh "pkill -TERM -f 'uwsgi .*#{UWSGI_INI}' || true"
  end
  sh "sleep 1"
  sh "rm -f #{UWSGI_PIDFILE} #{UWSGI_SOCKET}"
end

desc "Restart uWSGI (non-root)"
task :restart => [:git_branch, :stop, :start]

desc "Restart nginx"
task :nginx_restart => :git_branch do
  sh "sudo nginx -t && sudo service nginx restart"
end

desc "Full deploy (non-root steps + nginx restart via sudo)"
task :deploy => [:git_branch, :setup, :start, :nginx_restart]

# ... existing code ...
def nginx_site_config_http
  <<-CONF
server {
  listen 80;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  location / {
    include uwsgi_params;
    uwsgi_pass unix://#{UWSGI_SOCKET};
    uwsgi_modifier1 7;
  }

  access_log /var/log/nginx/nhs.access.log;
  error_log  /var/log/nginx/nhs.error.log;
}
  CONF
end

