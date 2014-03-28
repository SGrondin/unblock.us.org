dns-uncensor
============

This is a work in progress.

It works by forwarding all DNS lookups to Google (8.8.8.8 or 8.8.4.4). There's some advanced manual UDP management to make it faster than most other DNS servers. It also supports TCP for long/signed responses.

There's no logging/history whatsoever, except for how many requests/second it serves.

All Twitter requests are hijacked and then tunnelled to Twitter's servers.

TODO: Support hijacking for more than 1 domain.

# Install

#### Recompile
```
./recompile.sh
```

#### Run
```
sudo ./start.sh &
```

Only the master process runs as root, the workers use user `nobody` (make sure it exists).
