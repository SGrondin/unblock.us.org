tcp = require "net"

forwardGoogleTCP = (client, cb) ->
	done = false
	clean = (err, client, google) ->
		if not done
			done = true
			google.destroy()
			client.destroy()
			cb err
		cb err
	google = tcp.createConnection {port:53, host:"8.8.8.8"}, ->
		client.pipe(google).pipe(client)
		client.on "error", (err) -> clean err, client, google
		google.on "error", (err) -> clean err, client, google
	client.on "end", () ->
		if not done
			clean null, client, google

module.exports = {forwardGoogleTCP}
