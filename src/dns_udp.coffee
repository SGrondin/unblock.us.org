udp = require "dgram"
bitconcat = require "bitconcat"

sendUDP = (socket, ip, port, data, cb) ->
	if not socket?
		socket = udp.createSocket "udp4"
		timeoutSend = setTimeout () ->
			clean new Error "Time exceeded"
		, 800
		clean = (err, data, info) ->
			clean = ->
			clearTimeout timeoutSend
			socket.removeAllListeners()
			socket.close()
			cb err, data, info
		socket.on "error", (err) -> clean err
		socket.on "message", (data, info) -> clean null, data, info
		socket.send data, 0, data.length, port, ip, (err) -> if err? then clear err
	else
		clean = (err) ->
			clean = ->
			clearTimeout timeoutSend
			cb err
		timeoutSend = setTimeout () ->
			clean new Error "Send time exceeded"
		, 3000
		socket.send data, 0, data.length, port, ip, (err) -> clean err
forwardGoogleUDP = (data, limiterUDP, cb) ->
	# start = Date.now()
	nbErrors = 0
	clean = (err, data, info) ->
		clean = ->
		clearTimeout timeoutAlt
		clearTimeout timeoutDown
		cb err, data, info
	timeoutDown = setTimeout () ->
		clean new Error "Time exceeded ("+nbErrors+" errors)"
	, 800

	timeoutAlt = setTimeout () ->
		limiterUDP.submit sendUDP, null, "8.8.4.4", 53, data, (err, resData, resInfo) ->
			if err?
				con "ALT", err
				nbErrors++
			# console.log (Date.now()-start), "8.8.4.4"
			clean err, resData, resInfo
	, 80

	limiterUDP.submit sendUDP, null, "8.8.8.8", 53, data, (err, resData, resInfo) ->
		if err?
			con "MAIN", err
			nbErrors++
		# console.log (Date.now()-start), "8.8.8.8"
		clean err, resData, resInfo

module.exports = {sendUDP, forwardGoogleUDP}
