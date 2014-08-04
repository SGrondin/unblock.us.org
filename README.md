[unblock.us.org](http://unblock.us.org)
==============


It uncensors the web by using the same tools that oppressive governments use to censor it in the first place.

It works by forwarding all DNS lookups to Google (8.8.8.8, 8.8.4.4). That unblocks all sites that were blocked at the DNS level.

Sites blocked at the IP level are DNS-hijacked and then tunneled through the server, in MITM fashion. SSL data obviously can't be decrypted nor tampered with because only the legitimate site owners have the private key to do so. However, it can be passed through to evade an IP ban. Both encrypted and unencrypted data is only proxied, it's never analyzed nor logged.

HTTP traffic is routed using the HTTP Host header. HTTPS traffic is routed using the SSL SNI extension.

It supports TCP for long/signed DNS packets.

There's no logging/history whatsoever, other than traffic stats. No data that could be used to identify the source or content of a request is ever written to the hard drive.

###Limitations:

* IP-banned domains are only unblocked for the web (HTTP/HTTPS). However, DNS-banned domains are accessible using any protocol.
* HTTPS routing relies on SNI, which is not available on Windows XP, Android 2.3 and some very old browsers (IE 6, Firefox 1, etc.).


###TODO:

* Refresh settings without restarting the workers
* [Host tunneling](http://unblock.us.org/?p=61)


# Install

TODO: Improve this.

Here are the detailed instructions to install it on Debian 6 or higher.

Create the user ```nobody``` with minimal permissions if it doesn't already exist: ```adduser nobody```

Compile and install [Node](https://github.com/joyent/node) 0.10.28 or higher.

Install Redis 2.8.x, ```sudo apt-get install redis-server redis-tools```. Edit ```/etc/redis/redis.conf```: ```daemonize``` must be set to ```yes```, port to ```6379``` and all ```save``` lines should be commented out.

Install bind9 ```sudo apt-get install bind9``` and edit your config.

On Debian, ```/etc/bind/named.conf``` contains 3 includes, ```/etc/bind/named.conf.local``` and ```/etc/bind/named.conf.default-zones``` must be empty and ```/etc/bind/named.conf.options``` must contain the following code:

```
options {
    directory "/var/cache/bind";
    dnssec-validation auto; # Comment this line if you're having issues starting bind!

    auth-nxdomain no;    # conform to RFC1035
    listen-on port 53530 { 127.0.0.1; };
    listen-on-v6 port 53530 { ::1; };

    forwarders {8.8.8.8; 8.8.4.4;};
    forward only;
};

controls { };
```

Then restart bind: ```/etc/init.d/bind9 restart```


Fill out the unblock.us.org config file: ```settings.js```.

Then run it.

#### Run
```
npm start
```

#### Recompile

Modifications to ```.coffee``` and ```._coffee``` files require recompilation.
```
npm run make
```

Only the master process runs as root, the workers use user ```nobody```.

Please reports bug here on Github, using the Issues system.

Pull requests are welcome.-
