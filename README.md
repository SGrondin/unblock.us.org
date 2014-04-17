[unblock.us.org](http://unblock.us.org)
==============


It uncensors the web by using the same tools that oppressive governments use to censor it in the first place.

It works by forwarding all DNS lookups to Google (8.8.8.8, 8.8.4.4). That unblocks all sites that were blocked at the DNS level.

Sites blocked at the IP level are DNS-hijacked and then tunneled through the server, in MITM fashion. SSL data obviously can't be decrypted nor tampered because only the legitimate site owners have the private key to do so. However, it can be passed through to evade an IP ban. Both encrypted and unencrypted data is only proxied, it's never analyzed nor logged.

HTTP traffic is routed using the HTTP Host header. HTTPS traffic is routed using the SSL SNI extension.

It supports TCP for long/signed DNS packets.

There's no logging/history whatsoever, other than traffic stats. No data that could be used to identify the source or content of a request is ever written to the hard drive.

###Limitations:

* IP-banned domains are only unblocked for the web (HTTP/HTTPS). However, DNS-banned domains are accessible using any protocol.
* HTTPS routing relies on SNI, which is not available on Windows XP and some very old browsers (IE 6, Firefox 1, etc.).


###TODO:

* Refresh settings without restarting the workers
* [Host tunneling](http://unblock.us.org/?p=61)


# Install

Create the user ```nobody``` with minimal permissions.

Compile and install [Node](https://github.com/joyent/node) 0.10.x.

Compile and install [nginx](http://nginx.org/en/download.html) 1.4.x with ```./configure --with-http_ssl_module --with-ipv6```

Install Redis 2.8.x, ```sudo apt-get install redis-server```. Edit redis.conf, ```daemonize``` must be set to ```yes```, port to ```6379``` and all ```save``` lines should be commented out.

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

Then run it.

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

Please reports bug here on Github, using the Issues system.

Pull requests are welcome.-
