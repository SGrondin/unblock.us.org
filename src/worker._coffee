udp = require "dgram"
tcp = require "net"
Bottleneck = require "bottleneck"
util = require "util"
stream = require "stream"
global.con = () -> util.puts Array::slice.call(arguments, 0).map((a)->util.inspect a).join " "
Buffer::toArray = () -> Array::slice.call @, 0
Buffer::map = (f) -> new Buffer Array::map.call @, f
Buffer::reduce = (f) -> Array::reduce.call @, f
libUDP = require "./dns_udp"
libTCP = require "./dns_tcp"
libDNS = require "./dns"
limiterUDP = new Bottleneck 50, 0
limiterTCP = new Bottleneck 30, 0
stats = {
	nbRequestUDPStart : 0
	nbFailUDPStart : 0
	nbRequestUDP : 0
	nbFailUDP : 0
	nbRequestTCPStart : 0
	nbFailTCPStart : 0
	nbRequestTCP : 0
	nbFailTCP : 0
}

####################
# PROCESS IS READY #
####################
services = {}
serverStarted = (service) ->
	services[service] = true
	if services.udp and services.tcp and services.https and services.http
		console.log "Server ready", process.pid
		process.setuid "nobody"
		process.send {cmd:"online"}

#################
# SETUP DNS UDP #
#################
UDPserver = udp.createSocket "udp4"
UDPserver.on "error", (err) ->
	console.log "----------\n", util.inspect(err), "\n----------"
	process.exit()
UDPserver.on "listening", () -> serverStarted "udp"
UDPserver.on "close", () ->
	con "UDPserver closed"
	process.exit()

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
		libUDP.sendUDP UDPserver, info.address, info.port, libDNS.makeDNS(parsed, libDNS.SERVERFAILURE), _
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
).listen 53, () -> serverStarted "tcp"
TCPserver.on "error", (err) ->
	console.log "----------\n", util.inspect(err), "\n----------"
	process.exit()
TCPserver.on "close", () ->
	con "TCPserver closed"
	process.exit()

############################
# SETUP TWITTER HTTP/HTTPS #
############################
handlerHTTP_S = (c, port, _) ->
	google = tcp.createConnection {port:port, host:"199.59.149.198"}, ->
		con "PIPING!", port
		c.pipe(google).pipe(c)

HTTPSserver = tcp.createServer((c) ->
	handlerHTTP_S c, 443, ->
).listen 443, () -> serverStarted "https"
HTTPserver = tcp.createServer((c) ->
	handlerHTTP_S c, 80, ->
).listen 80, () -> serverStarted "http"
# ).listen "./socket/https-twitter.sock"

###################
# PRINT DNS STATS #
###################
setInterval () ->
	if limiterUDP._nbRunning > 40 or limiterTCP._nbRunning > 20
		con "NBRUNNING: UDP", limiterUDP._nbRunning, "TCP", limiterTCP._nbRunning
, 3000

setInterval () ->
	con(process.pid, "UDP", stats.nbFailUDP+"/"+stats.nbRequestUDP, "UDPStart", stats.nbFailUDPStart+"/"+stats.nbRequestUDPStart,
		"TCP", stats.nbFailTCP+"/"+stats.nbRequestTCP, "TCPStart", stats.nbFailTCPStart+"/"+stats.nbRequestTCPStart)
	stats.nbRequestUDP = 0
	stats.nbFailUDP = 0
	stats.nbRequestTCP = 0
	stats.nbFailTCP = 0
, 30000
