require "fileutils"

desc "Setup application"
task :setup do
  puts "Setting up application..."

  # Create directories
  FileUtils.mkdir_p ["log", "tmp"]

  # Setup nginx config
  nginx_config = <<-CONF
server {
  listen 80;
  server_name localhost;
  root #{Dir.pwd}/public;

  location / {
    proxy_pass http://unix:/var/run/nhs.sock;
    proxy_set_header Host $host;
  }
}
  CONF

  File.write("/etc/nginx/sites-available/nhs", nginx_config)
  FileUtils.ln_sf("/etc/nginx/sites-available/nhs", "/etc/nginx/sites-enabled/")
end

desc "Start application"
task :start do
  sh "bundle exec puma -C config/puma.rb"
end

desc "Stop application"
task :stop do
  sh "pkill -f puma"
end

desc "Restart nginx"
task :nginx_restart do
  sh "sudo service nginx restart"
end

desc "Deploy application"
task deploy: [:setup, :start, :nginx_restart]