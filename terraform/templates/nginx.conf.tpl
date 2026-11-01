server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html;

    # Static frontend served directly
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Everything under /api/ is proxied to the App tier's private IP
    location /api/ {
        proxy_pass http://${app_private_ip}:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
