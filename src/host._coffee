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

contentTypes = {
	"application/javascript", "application/xhtml+xml", "application/xml", "image/svg+xml", "text/css", "text/html", "text/javascript"
}
isAltered = (ct) -> contentTypes[ct]?


redirectAllURLs = (str) -> str.replace((new RegExp "ytimg[.]com", "g"), "ytimg.com.unblock")


module.exports = {redirectToHash, isAltered, redirectAllURLs}
