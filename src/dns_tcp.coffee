tcp = require "net"
libDNS = require "./dns"

getGoogleStream = (cb) ->
	google = tcp.createConnection {port:53, host:"8.8.8.8"}
	google.on "connect", () ->
		cb null, google


getRequest = (client, cb) ->
	received = []
	lengthExpected = null
	clean = (err, req) ->
		client.removeAllListeners()
		cb err, req
	client.on "error", (err) ->	clean err
	client.on "timeout", () -> clean new Error "getRequestClientTimeout"
	client.on "data", (chunk) -> # Callback as soon as all the data has arrived
		received.push chunk
		if not lengthExpected? and client.bytesRead >= 2
			lengthExpected = libDNS.parse2Bytes Buffer.concat(received)[0..1]
		if lengthExpected? and lengthExpected >= client.bytesRead-2
			clean null, Buffer.concat(received)[2..lengthExpected+1]
	client.on "end", () -> clean "TCPgetRequestClientClosedConnection"

module.exports = {getGoogleStream, getRequest}
