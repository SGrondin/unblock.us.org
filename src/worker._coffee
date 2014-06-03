udp = require "dgram"
tcp = require "net"
http = require "http"
httpProxy = require "http-proxy"
https = require "https"
fs = require "fs"
crypto = require "crypto"
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
#limiterUDP = new Bottleneck 250, 0
#limiterTCP = new Bottleneck 250, 0
#limiterHTTPS = new Bottleneck 250, 0
#limiterHTTP = new Bottleneck 250, 0

process.on "uncaughtException", (err) ->
	con "!!! UNCAUGHT !!!"
	con err
	console.log err.stack

shutdown = (cause, _) ->
	# TODO: Update this
	shutdown = ->
	con "worker PID", process.pid, "is shutting down:", cause
	f1 = TCPserver.close !_
	f2 = HTTPSserver.close !_
	UDPserver.close()
	setTimeout process.exit, 10000
	f1 _
	f2 _
	process.exit()
process.on "SIGTERM", -> shutdown "SIGTERM", ->

stats = (ip, type, _) ->
	try
		country = geoip.lookup(ip)?.country
		if not country?
			country = "ZZ"
			# con "ZZ: "+ip
		redisClient.hincrby "countries."+type, country, 1, _
		redisClient.sadd "ip."+type+".countries", country
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
		con err.message

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

##### FROM DNS SERVER #####
handlerDNSlisten = (data, info, _) ->
	try
		ip = libUDP.toClient UDPservers, redisClient, data, _
		stats ip, "dns", ->
	catch err
		redisClient.incr "udp.fail"
		redisClient.incr "udp.fail.start"
		try
			failure = libDNS.makeDNS(parsed, libDNS.SERVERFAILURE, false)
			socket.send failure, 0, failure.length, info.port, info.address
		catch e
		console.log err

DNSlistenServer = udp.createSocket "udp4"
DNSlistenServer.on "error", (err) -> shutdown "DNSlistenServer error "+util.inspect(err)+" "+err.message, ->
DNSlistenServer.on "message", (data, info) -> handlerDNSlisten data, info, ->

##### TO DNS SERVER #####
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
			failure = libDNS.makeDNS(parsed, libDNS.SERVERFAILURE, false)
			socket.send failure, 0, failure.length, info.port, info.address
		catch e
		console.log err+" "+parsed?.QUESTION?.NAME?.join "."

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
		c.on "error", (err) -> throw new Error "DNS TCP error: "+err.message
		c.on "close", -> throw new Error "DNS TCP closed"
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed, true
		if answer?
			c.end answer
		else
			stream = libTCP.getDNSstream _
			stream.pipe c
			stream.write libDNS.prependLength data
		stats c.remoteAddress, "dns", ->
	catch err
		con err
		redisClient.incr "tcp.fail"
		redisClient.incr "tcp.fail.start"
		c.destroy()

TCPserver = tcp.createServer((c) ->
	handlerTCP c, ->
).listen 53, "::", -> serverStarted "tcp"
TCPserver.on "error", (err) ->
	con "TCPserver error "+util.inspect(err)+" "+err.message
	console.log err.stack
TCPserver.on "close", -> shutdown "TCPserver closed", ->

#####################
# SETUP HOST TUNNEL #
#####################

handlerHostTunnel = (req, res, _) ->
	con "!!"
	con req.connection.address()
	con req.headers
	con "!!"
	res.writeHead 200
	res.end "hello world!"

hostTunnelServer = https.createServer({
	key:	fs.readFileSync(settings.wildcardKey),
	cert:	fs.readFileSync(settings.wildcardCert)
	}, (req, res) ->
	handlerHostTunnel req, res, ->
).listen settings.internalHostTunnelPort, "127.0.0.1", null, -> serverStarted "host"
hostTunnelServer.on "error", (err) ->
	con "hostTunnelServer error "+util.inspect(err)+" "+err.message
	console.log err.stack
hostTunnelServer.on "close", ->
	shutdown "hostTunnelServer closed", ->

######################
# SETUP HTTPS TUNNEL #
######################

handlerHTTPS = (c, _) ->
	try
		redisClient.incr "https"
		redisClient.incr "https.start"
		[host, received] = libHTTPS.getRequest c, [_]

		analyzed = libDNS.hijackedDomain(host.split("."))
		if not analyzed.domain? then throw new Error "HTTPS Domain not found: "+host

		stream = libHTTPS.getHTTPSstream host, _
		stream.write received
		c.pipe(stream).pipe(c)
		c.resume()
		stats c.remoteAddress, "http", ->
	catch err
		con err.message
		redisClient.incr "https.fail"
		redisClient.incr "https.fail.start"
		c?.destroy?()
		stream?.destroy?()

HTTPSserver = tcp.createServer((c) ->
	handlerHTTPS c, ->
).listen settings.httpsPort, "::", -> serverStarted "https"
HTTPSserver.on "error", (err) ->
	con "HTTPSserver error "+util.inspect(err)+" "+err.message
	console.log err.stack
HTTPSserver.on "close", ->
	shutdown "HTTPSserver closed", ->

#####################
# SETUP HTTP TUNNEL #
#####################

handlerHTTP = (req, res, _) ->
	try
		if not req.headers.host? or not libDNS.hijackedDomain(req.headers.host.split(".")).domain?
			res.writeHead 500
			res.end()
			return
		redisClient.incr "http"
		redisClient.incr "http.start"
		proxy.web req, res, {target:"http://"+req.headers.host, secure:false}
		stats req.connection?.address?(), "http", ->
	catch err
		con err
		redisClient.incr "http.fail"
		redisClient.incr "http.fail.start"

proxy = httpProxy.createProxyServer {}
proxy.on "error", (err, req, res) ->
	con req.headers.host+" "+err.message
	res.writeHead 500
	res.end()

HTTPserver = http.createServer((req, res) ->
	handlerHTTP req, res, ->
).listen settings.httpPort, "::", null, -> serverStarted "http"
HTTPserver.on "error", (err) -> con "HTTPserver error "+util.inspect(err)+" "+err.message
HTTPserver.on "close", ->
	shutdown "HTTPserver closed", ->
