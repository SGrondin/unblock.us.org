tcp = require "net"
libDNS = require "./dns"

# http://tools.ietf.org/html/rfc5246#section-7.4.1
# http://stackoverflow.com/questions/17832592/extract-server-name-indication-sni-from-tls-client-hello
parseHTTPS = (packet) ->
	res = {}
	res.contentType = packet[0]
	res.recordVersion = packet[1..2]
	res.recordLength = libDNS.parse2Bytes packet[3..4]

	res.handshakeType = packet[5]
	res.handshakeLength = libDNS.parse3Bytes packet[6..8]
	res.handshakeVersion = packet[9..10]
	res.random = packet[11..42]

	res.sessionIDlength = packet[43]
	pos = res.sessionIDlength + 43 + 1

	res.cipherSuitesLength = libDNS.parse2Bytes packet[pos..(pos+1)]
	pos += res.cipherSuitesLength + 2

	res.compressionMethodsLength = packet[pos]
	pos += res.compressionMethodsLength + 1

	res.extensionsLength = libDNS.parse2Bytes packet[pos..(pos+1)]
	pos += 2

	extensionsEnd = pos + res.extensionsLength - 1
	res.type = -1
	res.length = 0
	while res.type != 0 and pos < extensionsEnd
		pos += res.length
		res.type = libDNS.parse2Bytes packet[pos..(pos+1)]
		res.length = libDNS.parse2Bytes packet[(pos+2)..(pos+3)]


	res.SNIlength = libDNS.parse2Bytes packet[(pos+4)..(pos+5)]
	res.serverNameType = packet[(pos+6)]
	pos += 7
	if res.type == 0 and res.SNIlength >= 4
		res.hostLength = libDNS.parse2Bytes packet[pos..(pos+1)]
		pos += 2
		res.host = packet[pos..(pos+res.hostLength-1)].toString "utf8"
		res
	else
		null


getHTTPSstream = (host, cb) ->
	s = tcp.createConnection {port:443, host}, () ->
		cb null, s
	s.on "error", (err) -> throw err
	s.on "close", () -> throw new Error "HTTPS upstream closed"
	s.on "timeout", () -> throw new Error "HTTPS upstream timeout"

getRequest = (c, cb) ->
	received = []
	buf = new Buffer []
	clean = (err, host, buf) ->
		c.removeAllListeners("data")
		clean = ->
		cb err, host, buf
	c.on "data", (data) ->
		c.pause()
		received.push data
		buf = Buffer.concat received
		ssl = parseHTTPS buf
		if ssl?.host?
			clean null, ssl.host, buf
		else
			c.resume()
	c.on "timeout", () -> clean new Error "HTTPS getRequest timeout"
	c.on "error", (err) -> clean err
	c.on "close", () -> clean new Error "HTTPS socket closed"
	c.on "end", () -> clean new Error "HTTPS getRequest socket closed"

module.exports = {getHTTPSstream, getRequest}
