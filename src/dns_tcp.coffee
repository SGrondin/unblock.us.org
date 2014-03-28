tcp = require "net"
libDNS = require "./dns"

getGoogleStream = (cb) ->
	google = tcp.createConnection {port:53, host:"8.8.8.8"}
	google.on "connect", () ->
		cb null, google


forwardGoogleTCP = (client, cb) ->
	google = tcp.createConnection {port:53, host:"8.8.8.8"}, ->
		client.pipe(google).pipe(client)

getRequest = (client, cb) ->
	received = []
	lengthExpected = null
	done = false
	clean = (err, req) ->
		if not done
			done = true
			client.removeAllListeners()
			if err?
				cb err
			else
				cb null, req
	client.on "error", (err) ->	clean err
	client.on "timeout", () -> clean new Error "getRequestClientTimeout"
	client.on "data", (chunk) -> # Callback as soon as all the data has arrived
		received.push chunk
		if not lengthExpected? and client.bytesRead >= 2
			lengthExpected = libDNS.parse2Bytes Buffer.concat(received)[0..1]
		if lengthExpected? and lengthExpected >= client.bytesRead-2
			clean null, Buffer.concat(received)[2..lengthExpected+1]
	client.on "end", () -> clean "getRequestClientClosedConnection"

module.exports = {getGoogleStream, forwardGoogleTCP, getRequest}
