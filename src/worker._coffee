udp = require "dgram"
tcp = require "net"
http = require "http"
rawCreateServer = require "http-raw"
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
libHTTP = require "./http"
limiterUDP = new Bottleneck 250, 0
limiterTCP = new Bottleneck 150, 0
limiterHTTPS = new Bottleneck 150, 0
limiterHTTP = new Bottleneck 250, 0

setInterval ->
	if limiterUDP._nbRunning > 130 or limiterTCP._nbRunning > 20 or limiterHTTPS._nbRunning > 75 or limiterHTTP._nbRunning > 75
		con "NBRUNNING: UDP", limiterUDP._nbRunning, "TCP", limiterTCP._nbRunning, "HTTPS", limiterHTTPS._nbRunning
, 3000

shutdown = (cause, _) ->
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
			con "ZZ: "+ip
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
		if services.udp and services.tcp and services.https and services.http
			process.setuid "nobody"
			con "Server ready", process.pid
			process.send {cmd:"online"}
	catch err
		con err
		con err.message

###############
# SETUP REDIS #
###############
redisClient = redis.createClient()
redisClient.on "error", (err) ->
	shutdown "Redis client error: "+err, ->
redisClient.select settings.redisDB, _

#################
# SETUP DNS UDP #
#################
UDPserver = udp.createSocket "udp4"
UDPserver.on "error", (err) ->
	shutdown "UDPserver error "+util.inspect(err)+" "+err.message, ->
UDPserver.on "listening", -> serverStarted "udp"
UDPserver.on "close", ->
	shutdown "UDPserver closed", ->

handlerUDP = (data, info, _) ->
	try
		redisClient.incr "udp"
		redisClient.incr "udp.start"
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed
		if answer?
			resData = answer
		else
			[resData, resInfo] = libUDP.forwardGoogleUDP data, limiterUDP, [_]
		libUDP.sendUDP UDPserver, info.address, info.port, resData, _
		stats info.address, "dns", ->
	catch err
		redisClient.incr "udp.fail", _
		redisClient.incr "udp.fail.start", _
		try
			libUDP.sendUDP UDPserver, info.address, info.port, libDNS.makeDNS(parsed, libDNS.SERVERFAILURE), _
		catch e
		con err.stack

UDPserver.on "message", (data, info) ->
	try
		handlerUDP data, info, (err) -> if err? then throw err
	catch err
		con err
UDPserver.bind 53

#################
# SETUP DNS TCP #
#################
handlerTCP = (c, _) ->
	try
		redisClient.incr "tcp"
		redisClient.incr "tcp.start"
		data = libTCP.getRequest c, _
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed, true
		if answer?
			c.end answer
		else
			google = limiterTCP.submit libTCP.getGoogleStream, _
			google.pipe c
			google.write libDNS.prependLength data
		stats c.remoteAddress, "dns", ->
	catch err
		con err
		redisClient.incr "tcp.fai", _
		redisClient.incr "tcp.fail.start", _
		c.destroy()


TCPserver = tcp.createServer((c) ->
	handlerTCP c, ->
).listen 53, -> serverStarted "tcp"
TCPserver.on "error", (err) ->
	shutdown "TCPserver error "+util.inspect(err)+" "+err.message, ->
TCPserver.on "close", ->
	shutdown "TCPserver closed", ->

######################
# SETUP HTTPS TUNNEL #
######################

handlerHTTPS = (c, _) ->
	# try
	con "HTTPS!!"
	redisClient.incr "https"
	redisClient.incr "https.start"
	[host, received] = libHTTPS.getRequest c, [_]
	if not libDNS.hijackedDomain(host.split("."))? then throw new Error "HTTPS Domain not found: "+host
	con host+"!!"
	stream = limiterHTTPS.submit libHTTPS.getHTTPSstream, host, _
	stream.write received
	c.pipe(stream).pipe(c)
	c.resume()
	stats c.remoteAddress, "https", ->
	# catch err
	# 	con err.message
	# 	redisClient.incr "https.fail", _
	# 	redisClient.incr "https.fail.start", _
	# 	c?.destroy?()
	# 	stream?.destroy?()

HTTPSserver = tcp.createServer((c) ->
	handlerHTTPS c, ->
).listen settings.httpsSocket, -> serverStarted "https"
HTTPSserver.on "error", (err) ->
	shutdown "HTTPSserver error "+util.inspect(err)+" "+err.message, ->
HTTPSserver.on "close", ->
	shutdown "HTTPSserver closed", ->

#####################
# SETUP HTTP TUNNEL #
#####################

handlerHTTP = (req, res, _) ->
	# try
	con "HTTP!"
	if not libDNS.hijackedDomain(req.headers.host.split("."))? then throw new Error "HTTP domain not found"+req.headers.host
	con req.headers.host+"!"
	stream = libHTTP.getHTTPstream req.headers.host, _
	sreq = req.createRawStream()
	sres = res.createRawStream()
	sreq.pipe(stream).pipe(sres)
	# catch err
	# 	con err
	# 	s?.destroy?()
	# 	stream?.destroy?()

HTTPserver = rawCreateServer((req, res) ->
	handlerHTTP req, res, ->
).listen 15000, "::", null, -> serverStarted "http"
