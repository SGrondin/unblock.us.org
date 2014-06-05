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

# This will probably need a lot of tweaking
# Creates something like ((https)://([a-zA-Z0-9\-]+[.]{1})*?)?((youtube[.]com)|(ggpht[.]com)|(ytimg[.]com)|(youtube-nocookie[.]com)|(youtu[.]be)
rDomains = new RegExp "((https)://([a-zA-Z0-9\-]+[.]{1})*?)?("+("("+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
redirectAllURLs = (str) ->
	# TODO: Reuse hashes to save a whole HTTP round-trip
	str.replace rDomains, (e) ->
		if e[0..4] == "https"
			"http"+e[5..]+".unblock"
		else
			e+".unblock"


module.exports = {redirectToHash, isAltered, redirectAllURLs}
