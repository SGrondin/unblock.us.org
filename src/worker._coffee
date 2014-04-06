udp = require "dgram"
tcp = require "net"
Bottleneck = require "bottleneck"
util = require "util"
settings = require "../settings"
global.con = -> console.log Array::concat(new Date().toISOString(), Array::slice.call(arguments, 0)).map((a)->util.inspect a).join " "
Buffer::toArray = -> Array::slice.call @, 0
Buffer::map = (f) -> new Buffer Array::map.call @, f
Buffer::reduce = (f) -> Array::reduce.call @, f
libUDP = require "./dns_udp"
libTCP = require "./dns_tcp"
libDNS = require "./dns"
libHTTPS = require "./https"
limiterUDP = new Bottleneck 50, 0
limiterTCP = new Bottleneck 30, 0
limiterHTTPS = new Bottleneck 120, 0
stats = {
	nbRequestUDPStart : 0
	nbFailUDPStart : 0
	nbRequestUDP : 0
	nbFailUDP : 0

	nbRequestTCPStart : 0
	nbFailTCPStart : 0
	nbRequestTCP : 0
	nbFailTCP : 0

	nbRequestHTTPSStart : 0
	nbFailHTTPSStart : 0
	nbRequestHTTPS : 0
	nbFailHTTPS : 0
}
shutdown = (cause, _) ->
	shutdown = ->
	con "worker PID", process.pid, "is shutting down:", cause
	f1 = TCPserver.close !_
	f2 = HTTPSserver.close !_
	UDPserver.close()
	setTimeout (-> process.exit()), 10000
	f1 _
	f2 _
	process.exit()
process.on "SIGTERM", -> shutdown "SIGTERM", ->

####################
# PROCESS IS READY #
####################
services = {}
serverStarted = (service) ->
	try
		services[service] = true
		if services.udp and services.tcp and services.https
			process.setuid "nobody"
			console.log "Server ready", process.pid
			process.send {cmd:"online"}
	catch err
		con err
		con err.message

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
	stats.nbRequestUDP++
	stats.nbRequestUDPStart++
	try
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed
		if answer?
			resData = answer
		else
			[resData, resInfo] = libUDP.forwardGoogleUDP data, limiterUDP, [_]
		libUDP.sendUDP UDPserver, info.address, info.port, resData, _
	catch err
		stats.nbFailUDP++
		stats.nbFailUDPStart++
		try
			libUDP.sendUDP UDPserver, info.address, info.port, libDNS.makeDNS(parsed, libDNS.SERVERFAILURE), _
		catch e
		console.log err.message

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
	stats.nbRequestTCP++
	stats.nbRequestTCPStart++
	try
		data = libTCP.getRequest c, _
		parsed = libDNS.parseDNS data
		answer = libDNS.getAnswer parsed, true
		if answer?
			c.end answer
		else
			google = limiterTCP.submit libTCP.getGoogleStream, _
			google.on "error", (err) -> throw err
			google.on "close", (hadError) ->
				if hadError then throw new Error "GoogleStreamClosed"
				c.destroy()
			google.pipe c
			google.write libDNS.prependLength data
	catch err
		con err
		stats.nbFailTCP++
		stats.nbFailTCPStart++
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
	stats.nbRequestHTTPS++
	stats.nbRequestHTTPSStart++
	try
		[host, received] = libHTTPS.getRequest c, [_]
		if not settings.hijacked[host.split(".")[-2..].join(".")]? then throw new Error "Domain not found: "+host
		stream = limiterHTTPS.submit libHTTPS.getHTTPSstream, host, _
		stream.write received
		c.pipe(stream).pipe(c)
		c.resume()
	catch err
		con err.message
		stats.nbFailHTTPS++
		stats.nbFailHTTPSStart++
		c?.destroy?()
		stream?.destroy?()

HTTPSserver = tcp.createServer((c) ->
	handlerHTTPS c, ->
).listen 443, -> serverStarted "https"
HTTPSserver.on "error", (err) ->
	shutdown "HTTPSserver error "+util.inspect(err)+" "+err.message, ->
HTTPSserver.on "close", ->
	shutdown "HTTPSserver closed", ->

###############
# PRINT STATS #
###############
setInterval ->
	if limiterUDP._nbRunning > 40 or limiterTCP._nbRunning > 20 or limiterHTTPS._nbRunning > 100
		con "NBRUNNING: UDP", limiterUDP._nbRunning, "TCP", limiterTCP._nbRunning, "HTTPS", limiterHTTPS._nbRunning
, 3000

setInterval ->
	con(process.pid, "UDP", stats.nbFailUDP+"/"+stats.nbRequestUDP, "UDPStart", stats.nbFailUDPStart+"/"+stats.nbRequestUDPStart,
		"TCP", stats.nbFailTCP+"/"+stats.nbRequestTCP, "TCPStart", stats.nbFailTCPStart+"/"+stats.nbRequestTCPStart,
		"HTTPS", stats.nbFailHTTPS+"/"+stats.nbRequestHTTPS, "HTTPSStart", stats.nbFailHTTPSStart+"/"+stats.nbRequestHTTPSStart)
	stats.nbRequestUDP = 0
	stats.nbFailUDP = 0
	stats.nbRequestTCP = 0
	stats.nbFailTCP = 0
	stats.nbRequestHTTPS = 0
	stats.nbFailHTTPS = 0
, (60 * 1000)
