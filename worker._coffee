udp = require "dgram"
tcp = require "net"
Bottleneck = require "bottleneck"
util = require "util"
global.con = () -> util.puts Array::slice.call(arguments, 0).map((a)->util.inspect a).join " "
libUDP = require "./dns_udp"
libTCP = require "./dns_tcp"
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
services = {udp:false, tcp:false, https:false}
serverStarted = (service) ->
	services[service] = true
	if services.udp and services.tcp and services.https
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
		# console.log "NBRUNNING: "+limiterUDP._nbRunning
		[resData, resInfo] = libUDP.forwardGoogleUDP data, limiterUDP, [_]
		libUDP.sendUDP UDPserver, info.address, info.port, resData, _
	catch err
		stats.nbFailUDP++
		stats.nbFailUDPStart++
		console.log err.message

UDPserver.on "message", (data, info) -> handlerUDP data, info, ->
UDPserver.bind 53

#################
# SETUP DNS TCP #
#################
handlerTCP = (c, _) ->
	try
		stats.nbRequestTCP++
		stats.nbRequestTCPStart++
		limiterTCP.submit libTCP.forwardGoogleTCP, c, _
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

#######################
# SETUP TWITTER HTTPS #
#######################
handlerHTTPS = (c, _) ->


HTTPSserver = tcp.createServer((c) ->
	handlerHTTPS c, ->
).listen 443, () -> serverStarted "https"
# ).listen "./socket/https-twitter.sock"

###################
# PRINT DNS STATS #
###################
setInterval () ->
	if limiterUDP._nbRunning > 40 or limiterTCP._nbRunning > 20
		con "NBRUNNING: UDP", limiterUDP._nbRunning, "TCP", limiterTCP._nbRunning
, 1000

setInterval () ->
	con(process.pid, "UDP", stats.nbFailUDP+"/"+stats.nbRequestUDP, "UDPStart", stats.nbFailUDPStart+"/"+stats.nbRequestUDPStart,
		"TCP", stats.nbFailTCP+"/"+stats.nbRequestTCP, "TCPStart", stats.nbFailTCPStart+"/"+stats.nbRequestTCPStart)
	stats.nbRequestUDP = 0
	stats.nbFailUDP = 0
	stats.nbRequestTCP = 0
	stats.nbFailTCP = 0
, 20000
