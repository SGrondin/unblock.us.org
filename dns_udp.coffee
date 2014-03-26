udp = require "dgram"
# bitconcat = require "bitconcat"

# http://tools.ietf.org/html/rfc1035
parseUDP = (packet) ->
	res = {}
	res.ID = packet[0..1].toArray()
	res.QR = packet[2] & 0x80 # 10000000
	res.OPCODE = packet[2] & 0x78 # 01111000
	res.AA = packet[2] & 0x4 # 00000100
	res.TC = packet[2] & 0x2 # 00000010
	res.RD = packet[2] & 0x1 # 00000001
	res.RA = packet[3] & 0x80 # 10000000
	res.Z = packet[3] & 0x70 # 01110000
	res.RCODE = packet[3] & 0xf # 00001111
	res.QDCOUNT = packet[4..5].toArray()
	res.ANCOUNT = packet[6..7].toArray()
	res.NSCOUNT = packet[8..9].toArray()
	res.ARCOUNT = packet[10..11].toArray()
	res

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
		socket.on "close", () ->
			if not done
				clean()
				cb new Error "socket closed"
		socket.on "message", (data, info) ->
			if not done
				clean()
				cb null, data, info
		socket.send data, 0, data.length, port, ip
	else
		socket.send data, 0, data.length, port, ip, cb
		# done = false
		# timeoutSend = setTimeout () ->
		# 	if not done
		# 		done = true
		# 		cb "Send2 time exceeded"
		# , 1000
		# socket.send data, 0, data.length, port, ip, () ->
		# 	clearTimeout timeoutSend
		# 	if not done
		# 		done = true
		# 		cb null

forwardGoogleUDP = (data, limiterUDP, cb) ->
	start = Date.now()
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
				console.log (Date.now()-start), "8.8.4.4"
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
			console.log (Date.now()-start), "8.8.8.8"
			cb null, resData, resInfo

module.exports = {sendUDP, forwardGoogleUDP}
