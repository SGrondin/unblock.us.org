dns-uncensor
============

This is a work in progress.

It works by forwarding all DNS lookups to Google (8.8.8.8 or 8.8.4.4). There's some advanced manual UDP management to make it faster than most other DNS servers. It also supports TCP for long/signed responses.

There's no logging/history whatsoever, except for how many requests/second it serves.

TODO:

* Resolve Twitter domains to the server's IP and then tunnel all twitter data.
* Make it easy to tunnel more domains.

# Install

### Dependencies
```
npm install bottleneck
npm -g install coffee-script
npm -g install streamline
```

### Compile
```
_coffee -c .
```

### Run
```
./start.sh
```
