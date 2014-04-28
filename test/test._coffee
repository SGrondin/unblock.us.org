udp = require "dgram"

socket = udp.createSocket "udp4"

times = []
buf = new Buffer [1..180]
[1..300].forEach_ _, -1, (_, i) ->
	t1 = Date.now()
	bytes = socket.send buf[..], 0, buf.length, 55, "127.0.0.1", _
	times.push (Date.now() - t1)
	console.log i, bytes
socket.close()
console.log times
