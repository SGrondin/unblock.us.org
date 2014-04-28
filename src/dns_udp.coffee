udp = require "dgram"

sendUDP = (socket, ip, port, data, cb) ->
	if not socket?
		socket = udp.createSocket "udp4"
		clean1 = (err, data, info) ->
			clean1 = ->
			clearTimeout timeoutSend
			socket.removeAllListeners()
			socket.close()
			cb err, data, info
		timeoutSend = setTimeout ->
			clean1 new Error "Time exceeded"
		, 3000
		socket.on "error", (err) -> clean1 err
		socket.on "close", -> clean1 new Error "UDP socket closed"
		socket.on "message", (data, info) -> clean1 null, data, info
		socket.send data, 0, data.length, port, ip, (err) -> if err? then clean1 err
	else
		clean2 = (err) ->
			clean2 = ->
			clearTimeout timeoutSend
			cb err
		t1 = Date.now()
		timeoutSend = setTimeout ->
			redisClient.rpush "udp.diag.timeout", (Date.now() - t1)
			clean2 new Error "Send time exceeded"
		, 3000
		t2 = Date.now()
		socket.send data, 0, data.length, port, ip, (err) ->
			redisClient.rpush "udp.diag.callback", (Date.now() - t2)
			clean2 err

forwardGoogleUDP = (data, limiterUDP, cb) ->
	# start = Date.now()
	nbErrors = 0
	clean = (err, data, info) ->
		clean = ->
		clearTimeout timeoutAlt
		clearTimeout timeoutDown
		cb err, data, info
	timeoutDown = setTimeout ->
		clean new Error "Time exceeded ("+nbErrors+" errors)"
	, 3500

	timeoutAlt = setTimeout ->
		limiterUDP.submit sendUDP, null, "8.8.4.4", 53, data, (err, resData, resInfo) ->
			if err?
				# con "ALT", err
				nbErrors++
			# console.log (Date.now()-start), "8.8.4.4"
			clean err, resData, resInfo
	, 80

	limiterUDP.submit sendUDP, null, "8.8.8.8", 53, data, (err, resData, resInfo) ->
		if err?
			# con "MAIN", err
			nbErrors++
		# console.log (Date.now()-start), "8.8.8.8"
		clean err, resData, resInfo

module.exports = {sendUDP, forwardGoogleUDP}
