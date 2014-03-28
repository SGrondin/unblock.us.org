udp = require "dgram"
bitconcat = require "bitconcat"

sendUDP = (socket, ip, port, data, cb) ->
	if not socket?
		done = false
		socket = udp.createSocket "udp4"
		timeoutSend = setTimeout () ->
			if not done
				clean()
				cb new Error "Time exceeded"
		, 800
		clean = () ->
			clearTimeout timeoutSend
			done = true
			socket.close()
		socket.on "error", (err) ->
			if not done
				clean()
				cb err
		socket.on "message", (data, info) ->
			if not done
				clean()
				cb null, data, info
		socket.send data, 0, data.length, port, ip, (err) ->
			if err? and not done
				clean()
				cb err
	else
		# socket.send data, 0, data.length, port, ip, cb
		done = false
		timeoutSend = setTimeout () ->
			if not done
				done = true
				cb new Error "Send time exceeded"
		, 1000
		socket.send data, 0, data.length, port, ip, (err) ->
			clearTimeout timeoutSend
			if not done
				done = true
				if err?
					cb err
				else
					cb null

forwardGoogleUDP = (data, limiterUDP, cb) ->
	# start = Date.now()
	nbErrors = 0
	done = false
	timeoutDown = setTimeout () ->
		if not done
			clearTimeout timeoutAlt
			done = true
			cb new Error "Time exceeded ("+nbErrors+" errors)"
	, 800

	timeoutAlt = setTimeout () ->
		limiterUDP.submit sendUDP, null, "8.8.4.4", 53, data, (err, resData, resInfo) ->
			if err?
				con "ALT", err
				nbErrors++
			if not done and not err?
				clearTimeout timeoutDown
				done = true
				# console.log (Date.now()-start), "8.8.4.4"
				cb null, resData, resInfo
	, 80

	limiterUDP.submit sendUDP, null, "8.8.8.8", 53, data, (err, resData, resInfo) ->
		if err?
			con "MAIN", err
			nbErrors++
		if not done and not err?
			clearTimeout timeoutAlt
			clearTimeout timeoutDown
			done = true
			# console.log (Date.now()-start), "8.8.8.8"
			cb null, resData, resInfo

module.exports = {sendUDP, forwardGoogleUDP}
