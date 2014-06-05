udp = require "dgram"
tcp = require "net"
http = require "http"
httpProxy = require "http-proxy"
https = require "https"
fs = require "fs"
crypto = require "crypto"
url = require "url"
Bottleneck = require "bottleneck"
geoip = require "geoip-lite"
util = require "util"
redis = require "redis"
settings = require "../settings"
global.con = -> console.log Array::concat(new Date().toISOString(), Array::slice.call(arguments, 0)).map((a)->util.inspect a).join " "
md5 = (str) -> crypto.createHash("md5").update(str).digest("hex")
Buffer::toArray = -> Array::slice.call @, 0
Buffer::map = (f) -> new Buffer Array::map.call @, f
Buffer::reduce = (f) -> Array::reduce.call @, f
libUDP = require "./dns_udp"
libTCP = require "./dns_tcp"
libDNS = require "./dns"
libHTTPS = require "./https"
libHost = require "./host"
# TODO: Integrate next version of Bottleneck
# limiterUDP = new Bottleneck 250, 0
# limiterTCP = new Bottleneck 250, 0
# limiterHTTPS = new Bottleneck 250, 0
# limiterHTTP = new Bottleneck 250, 0

settings.hijacked[settings.hostTunnelingDomain] = settings.hostTunnelingDomain

process.on "uncaughtException", (err) ->
	con "!!! UNCAUGHT !!!"
	con err
	console.log err.stack

shutdown = (cause, _) ->
	shutdown = ->
	con "worker PID", process.pid, "is shutting down:", cause
	setTimeout process.exit, 10000
	TCPserver.close _
	hostTunnelServer.close _
	HTTPSserver.close _
	HTTPserver.close _
	(socket.close() for socket of UDPservers)
	DNSlistenServer.close()
	setTimeout _, 2500
	process.exit()
process.on "SIGTERM", -> shutdown "SIGTERM", ->

stats = (ip, type, _) ->
	try
		country = geoip.lookup(ip)?.country
		if not country?
			country = "ZZ"
		redisClient.hincrby "countries."+type, country, 1, _
		redisClient.sadd "ip."+type+".countries", country, _
		redisClient.sadd "ip."+type+"."+country, md5("thisisgonnaneedtobefixed"+ip), _
	catch err
		con err

####################
# PROCESS IS READY #
####################
services = {}
serverStarted = (service) ->
	try
		services[service] = true
		if services.udp4 and services.udp6 and services.tcp and services.host and services.https and services.http
			process.setuid "nobody"
			con "Server ready", process.pid
			process.send {cmd:"online"}
	catch err
		con err

###############
# SETUP REDIS #
###############
global.redisClient = redis.createClient()
redisClient.on "error", (err) ->
	shutdown "Redis client error: "+err, ->
redisClient.select settings.redisDB, _

#################
# SETUP DNS UDP #
#################

# TODO: Write blog post about why it has to be so complicated

##### FROM DNS SERVER TO CLIENT #####
handlerDNSlisten = (data, info, _) ->
	try
		[port, ip, version] = libUDP.toClient UDPservers, redisClient, data, _
		stats ip, "dns", ->
	catch err
		redisClient.incr "udp.fail"
		redisClient.incr "udp.fail.start"
		try
			failure = libDNS.makeDNS(parsed, libDNS.SERVERFAILURE, false)
			UDPservers["udp"+version].send failure, 0, failure.length, port, ip
		catch e
		con "handlerDNSlisten error", err, err.stack

DNSlistenServer = udp.createSocket "udp4"
DNSlistenServer.on "error", (err) -> shutdown "DNSlistenServer error "+util.inspect(err)+" "+err.message, ->
DNSlistenServer.on "message", (data, info) -> handlerDNSlisten data, info, ->

##### FROM CLIENT TO DNS SERVER #####
handlerUDP = (socket, version, data, info, _) ->
	try
		redisClient.incr "udp"
		redisClient.incr "udp.start"
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed, false
		if answer?
			socket.send answer, 0, answer.length, info.port, info.address
		else
			libUDP.toDNSserver DNSlistenServer, redisClient, data, info, version, parsed, _
	catch err
		redisClient.incr "udp.fail"
		redisClient.incr "udp.fail.start"
		try
			failure = libDNS.makeDNS parsed, libDNS.SERVERFAILURE, false
			socket.send failure, 0, failure.length, info.port, info.address
		catch e
		con "handlerUDP error", (parsed?.QUESTION?.NAME?.join(".") or ""), err, err.stack

UDPservers = {}
[{IPversion:4, listenTo:"0.0.0.0"}, {IPversion:6, listenTo:"::"}].map (ip) ->
	UDPserver = udp.createSocket "udp"+ip.IPversion
	UDPserver.on "error", (err) -> shutdown "UDPserver(IPv#{ip.IPversion}) error "+util.inspect(err)+" "+err.message, ->
	UDPserver.on "listening", -> serverStarted "udp"+ip.IPversion
	UDPserver.on "close", -> shutdown "UDPserver(IPv#{ip.IPversion}) closed", ->
	UDPserver.on "message", (data, info) ->
		handlerUDP UDPserver, ip.IPversion, data, info, (err) -> if err? then throw err
	UDPserver.bind 53, ip.listenTo
	UDPservers["udp"+ip.IPversion] = UDPserver


#################
# SETUP DNS TCP #
#################
handlerTCP = (c, _) ->
	try
		redisClient.incr "tcp"
		redisClient.incr "tcp.start"
		data = libTCP.getRequest c, _
		c.on "error", (err) -> throw new Error "DNS TCP error: "+util.inspect(err)+" "+err.message
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed, true
		if answer?
			c.end answer
		else
			stream = libHTTPS.getStream settings.forwardDNS, settings.forwardDNSport, _
			stream.pipe c
			stream.write libDNS.prependLength data
		stats c.remoteAddress, "dns", ->
	catch err
		con "handlerTCP error", err
		redisClient.incr "tcp.fail"
		redisClient.incr "tcp.fail.start"
		c?.destroy()

TCPserver = tcp.createServer((c) ->
	handlerTCP c, ->
).listen 53, "::", -> serverStarted "tcp"
TCPserver.on "error", (err) ->
	con "TCPserver error ", err, err.stack
TCPserver.on "close", -> shutdown "TCPserver closed", ->

#####################
# SETUP HTTP TUNNEL #
#####################

close500 = (res, reason="") ->
	res.writeHead 500
	res.write reason
	res.end()

handlerHTTP = (req, res, _) ->
	try
		analyzed = libDNS.hijackedDomain(req.headers.host.split("."))
		if not req.headers.host? or not analyzed.domain? then return close500 res

		if analyzed.hostTunneling
			host = req.headers.host.split(".")[..-2].join(".")
			clientIP = req.connection.remoteAddress
			libHost.redirectToHash redisClient, res, host, req.url, clientIP, _
		else
			redisClient.incr "http"
			redisClient.incr "http.start"
			proxy.web req, res, {target:"http://"+req.headers.host, secure:false}
			stats req.connection.remoteAddress, "http", ->
	catch err

		con "HTTP error", err, err.stack
		redisClient.incr "http.fail"
		redisClient.incr "http.fail.start"

proxy = httpProxy.createProxyServer {}
proxy.on "error", (err, req, res) ->
	con "HTTPproxy error", req.headers.host+" "+err.message
	res.writeHead 500
	res.end()

HTTPserver = http.createServer((req, res) ->
	handlerHTTP req, res, ->
).listen settings.httpPort, "::", null, -> serverStarted "http"
HTTPserver.on "error", (err) -> con "HTTPserver error", err
HTTPserver.on "close", -> shutdown "HTTPserver closed", ->

######################
# SETUP HTTPS TUNNEL #
######################

handlerHTTPS = (c, _) ->
	try
		redisClient.incr "https"
		redisClient.incr "https.start"
		[host, received] = libHTTPS.getRequest c, [_]

		hostArr = host.split "."
		analyzed = libDNS.hijackedDomain(hostArr)
		if not analyzed.domain? then return c.destroy()

		if hostArr[1..].join(".") == settings.hostTunnelingDomain
			[target, port] = ["127.0.0.1", port = settings.internalHostTunnelPort]
		else
			[target, port] = [host, 443]
		stream = libHTTPS.getStream target, port, _
		stream.write received
		c.pipe(stream).pipe(c)
		c.resume()
		stats c.remoteAddress, "http", ->
	catch err
		con "handlerHTTPS error", err, err.stack
		redisClient.incr "https.fail"
		redisClient.incr "https.fail.start"
		c?.destroy()
		stream?.destroy()

HTTPSserver = tcp.createServer((c) ->
	handlerHTTPS c, ->
).listen settings.httpsPort, "::", -> serverStarted "https"
HTTPSserver.on "error", (err) ->
	con "HTTPSserver error", err, err.stack
HTTPSserver.on "close", -> shutdown "HTTPSserver closed", ->

#####################
# SETUP HOST TUNNEL #
#####################

handlerHostTunnel = (req, res, _) ->
	try
		host = req.headers.host
		hash = host.split(".")[0]
		keys = ["hostTunneling-"+hash, "xforwardedfor-"+hash]
		[wantedDomain, clientIP] = redisClient.mget keys, _
		if not wantedDomain? then return close500 res, "Expired link. Try entering the address with '.unblock' again"

		keys.forEach_ _, -1, (_, k) ->
			redisClient.expire [k, settings.hostTunnelingCaching], _
		req.headers.host = wantedDomain
		req.headers["X-Forwarded-For"] = clientIP

		options = {hostname:wantedDomain, port:443, path:req.url, method:req.method, headers:req.headers}
		delete options.headers["accept-encoding"] # TODO: Add gzip support

		preq = https.request options, (pres) ->

			if pres.statusCode in [301, 302]
				host = (url.parse (pres.headers.Location or pres.headers.location))?.hostname
				libHost.redirectToHash redisClient, res, host, req.url, clientIP, ->
			else
				res.writeHead pres.statusCode, pres.headers
				isAltered = libHost.isAltered (pres.headers["Content-Type"] or pres.headers["content-type"])?.toLowerCase().split(";")[0].trim()
				buffers = []
				pres.on "data", (data) ->
					if isAltered
						buffers.push data
					else
						res.write data
				pres.on "end", ->
					if isAltered
						# TODO: Some kind of pumping mechanism instead of a giant buffer all at once
						str = libHost.redirectAllURLs (new Buffer Buffer.concat buffers).toString "utf8"
						res.end str, "utf8"
					else
						res.end()

		preq.end()

	catch err
		con "handlerHostTunnel error", err, err.stack
		close500 res


hostTunnelServer = https.createServer({
	key:	fs.readFileSync(settings.wildcardKey),
	cert:	fs.readFileSync(settings.wildcardCert)
	}, (req, res) ->
	handlerHostTunnel req, res, ->
).listen settings.internalHostTunnelPort, "127.0.0.1", null, -> serverStarted "host"
hostTunnelServer.on "error", (err) ->
	con "hostTunnelServer error "+util.inspect(err)+" "+err.message
	console.log err.stack
hostTunnelServer.on "close", -> shutdown "hostTunnelServer closed", ->

