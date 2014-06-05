crypto = require "crypto"
settings = require "../settings"

redirectToHash = (redisClient, res, host, path, clientIP, _) ->
	hash = (crypto.pseudoRandomBytes 16, _).toString "hex"
	keys = ["hostTunneling-"+hash, "xforwardedfor-"+hash]
	values = [host, clientIP]
	keys.forEach_ _, -1, (_, k, i) ->
		redisClient.set [k, values[i]], _
		redisClient.expire [k, settings.hostTunnelingCaching], _
	redirect = "https://"+hash+"."+settings.hostTunnelingDomain+path
	res.writeHead 302, {Location:redirect}
	res.end """<html><body>The unblock.us.org project<br /><br />Unblocked at <a href="#{redirect}">#{redirect}</a></body></html>"""

module.exports = {redirectToHash}