require "fileutils"
require "securerandom"

APP_DOMAIN       = ENV.fetch("APP_DOMAIN", "localhost")
PROJECT_ROOT     = Dir.pwd
PUBLIC_DIR       = File.join(PROJECT_ROOT, "public")
LOG_DIR          = File.join(PROJECT_ROOT, "log")
TMP_DIR          = File.join(PROJECT_ROOT, "tmp")
PIDS_DIR         = File.join(TMP_DIR, "pids")

NGINX_SITE_AVAILABLE = "/etc/nginx/sites-available/nhs.conf"
NGINX_SITE_ENABLE = "/etc/nginx/sites-enabled/nhs.conf"
PUMA_SOCKET_PATH = "/var/run/nhs.sock"
NGINX_SSL_CERT   = ENV.fetch("NGINX_SSL_CERT", "/etc/letsencrypt/live/#{ENV.fetch('APP_DOMAIN', 'localhost')}/fullchain.pem")
NGINX_SSL_KEY    = ENV.fetch("NGINX_SSL_KEY",  "/etc/letsencrypt/live/#{ENV.fetch('APP_DOMAIN', 'localhost')}/privkey.pem")

def assert_not_root!(action = "run this task")
  abort "Refusing to #{action} as root. Run as a non-root user." if Process.uid.zero?
end

def require_root!(task_name)
  abort "Run as root: sudo rake #{task_name}" unless Process.uid.zero?
end

def ensure_dirs
  FileUtils.mkdir_p [LOG_DIR, TMP_DIR, PIDS_DIR, PUBLIC_DIR]
end

def write_file_with_parents(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
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
  <<-CONF
server {
  listen 443 ssl http2;
  server_name #{APP_DOMAIN};
  root #{PUBLIC_DIR};

  ssl_certificate     #{NGINX_SSL_CERT};
  ssl_certificate_key #{NGINX_SSL_KEY};
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

# Core tasks

desc "Install gems (non-root)"
task :bundle do
  assert_not_root!("run bundler")
  ensure_dirs
  sh "bundle install"
end

desc "Generate SESSION_SECRET in .env if missing/short"
task :generate_session_secret do
  assert_not_root!("generate session secret")
  env_path = File.join(PROJECT_ROOT, ".env")
  FileUtils.touch(env_path) unless File.exist?(env_path)
  text = File.binread(env_path)
  line_re = /^\s*SESSION_SECRET\s*=\s*.*$/i
  current = text[line_re]&.sub(/^\s*SESSION_SECRET\s*=\s*/i, "")&.strip&.gsub(/\A['"]|['"]\z/, "")
  if current && current.bytesize >= 64
    puts "SESSION_SECRET OK"
  else
    secret = SecureRandom.hex(64)
    text = if text =~ line_re then text.gsub(line_re, "SESSION_SECRET=#{secret}")
           else (text.end_with?("\n") ? text : "#{text}\n") + "SESSION_SECRET=#{secret}\n" end
    File.binwrite(env_path, text)
    puts "SESSION_SECRET written"
  end
end

desc "Start Puma on unix socket (non-root)"
task :start do
  assert_not_root!("start Puma")
  sh "sudo mkdir -p /var/run"
  sh "sudo chown #{ENV['USER']}:www-data /var/run"
  sh "sudo chmod 0770 /var/run"
  sh "sudo rm -f #{PUMA_SOCKET_PATH} || true"
  sh "PUMA_BIND=unix://#{PUMA_SOCKET_PATH} bundle exec puma -C config/puma.rb"
end

desc "Stop Puma (best-effort)"
task :stop do
  sh "pkill -TERM -f 'puma .*config/puma.rb' || true"
  sh "sleep 1"
  sh "rm -f #{PUMA_SOCKET_PATH} || true"
end

desc "Restart Puma"
task :restart => [:stop, :start]

# Nginx install

desc "Install/refresh Nginx HTTP site (sudo)"
task :nginx_install_http do
  require_root!("nginx_install_http")
  ensure_dirs
  write_file_with_parents(NGINX_SITE_AVAILABLE, nginx_site_config_http)
  FileUtils.ln_sf(NGINX_SITE_AVAILABLE, NGINX_SITE_ENABLE)
  sh "nginx -t"
  sh "service nginx reload"
end

desc "Install/refresh Nginx HTTPS site (sudo)"
task :nginx_install_https do
  require_root!("nginx_install_https")
  ensure_dirs
  write_file_with_parents(NGINX_SITE_AVAILABLE, nginx_site_config_https)
  FileUtils.ln_sf(NGINX_SITE_AVAILABLE, NGINX_SITE_ENABLE)
  sh "nginx -t"
  sh "service nginx reload"
end

desc "Install/refresh Nginx site (sudo). NGINX_SSL=http|https"
task :nginx_install do
  require_root!("nginx_install")
  mode = ENV.fetch("NGINX_SSL", "http")
  Rake::Task[mode == "https" ? :nginx_install_https : :nginx_install_http].invoke
end

desc "Restart Nginx (sudo)"
task :nginx_restart do
  sh "sudo nginx -t && sudo service nginx restart"
end

# Flows

desc "Deploy: bundle, ensure secret, start, nginx restart"
task :deploy => [:bundle, :generate_session_secret, :start, :nginx_restart]

desc "Uninstall: stop app, remove Nginx site (sudo), clean socket/state"
task :uninstall do
  Rake::Task[:stop].invoke rescue nil
  if Process.uid.zero?
    sh "rm -f #{NGINX_SITE_ENABLE} #{NGINX_SITE_AVAILABLE}"
    sh "nginx -t"
    sh "service nginx reload"
  else
    puts "Nginx site not removed (run: sudo rake uninstall)."
  end
  puts "Uninstall done."
end

desc "Reinstall: uninstall then deploy"
task :reinstall => [:uninstall, :deploy]

desc "Obtain/renew Let's Encrypt certificate via webroot (sudo). Uses APP_DOMAIN and PUBLIC_DIR"
task :certbot do
  require_root!("certbot")
  ensure_dirs
  sh "certbot certonly --webroot -w #{PUBLIC_DIR} -d #{APP_DOMAIN} --agree-tos -n -m admin@#{APP_DOMAIN} || true"
  puts "Certbot finished. Certs (if issued): /etc/letsencrypt/live/#{APP_DOMAIN}/"
end

desc "Deploy full stack: bundle, ensure secret, install Nginx (HTTPS), run Certbot, start Puma, reload Nginx"
task :deploy_full => [:bundle, :generate_session_secret] do
  # 1) Obtain/renew certificate first (HTTP-01 uses port 80; avoids boot order issues)
  sh "sudo rake certbot"

  # 2) Install/refresh Nginx site for HTTPS (points to LE certs by default if env unset)
  sh "sudo rake nginx_install_https"

  # 3) Start Puma on the Unix socket
  Rake::Task[:start].invoke

  # 4) Reload Nginx to ensure it picks up current socket/certs
  Rake::Task[:nginx_restart].invoke

  puts "Deploy full completed."
end