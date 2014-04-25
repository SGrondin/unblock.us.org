tcp = require "net"

getHTTPstream = (host, cb) ->
	clean = (err, s) ->
		clean = ->
		cb err, s
	s = tcp.createConnection {port:80, host}, ->
		clean null, s
	s.on "error", (err) ->
		s.destroy()
		clean err
	s.on "close", ->
		s.destroy()
		clean new Error "HTTP socket was closed"
	s.on "timeout", ->
		s.destroy()
		clean new Error "HTTP socket timeout"

module.exports = {getHTTPstream}