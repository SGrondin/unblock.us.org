dns-uncensor
============

This is a work in progress.

It works by forwarding all DNS lookups to Google (8.8.8.8 or 8.8.4.4). There's some advanced manual UDP management to make it faster than most other DNS servers. It also supports TCP for long/signed responses.

There's no logging/history whatsoever, except for how many requests/second it serves.

All requests for domains listed in settings.js are tunneled instead, to avoid the IP ban.

TODO:

* Cleaner restart/reload
* Support subdomain wildcard


# Install

Create the user ```nobody``` with minimal permissions.

Compile and install [Node](https://github.com/joyent/node) 0.10.x.

Compile and install [nginx](http://nginx.org/en/download.html) 1.4.x with ```./configure --with-http_ssl_module --with-ipv6```

Create the following ```server``` block inside of the main ```http``` block in ```nginx.conf```:
```
server {
    listen [::]:80 default_server;
    listen 80 default_server;
    server_name _;
    access_log off;
    location / {
        resolver 8.8.8.8;
        proxy_pass http://$http_host$request_uri;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Edit ```settings.js``` with the IPv4 and IPv6 addresses of your server and the domains you want to tunnel.

Then start the server.

#### Run
```
sudo ./start.sh &
```

#### Recompile

Modifications to ```.coffee``` and ```._coffee``` files require recompilation.
```
./recompile.sh
```

Only the master process runs as root, the workers use user ```nobody```.
