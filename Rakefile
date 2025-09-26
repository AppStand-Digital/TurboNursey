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

# ... existing code ...