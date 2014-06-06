crypto = require "crypto"
url = require "url"
asyncReplace = require "async-replace"
settings = require "../settings"
Bottleneck = require "bottleneck"

getHash = (redisClient, host, clientIP, _) ->
	savedHashKey = "hash-"+clientIP+"-"+host
	hash = redisClient.get savedHashKey, _

	# That IP hasn't asked for that domain before
	if not hash?
		hash = (crypto.pseudoRandomBytes 16, _).toString "hex"
		keys = ["hostTunneling-"+hash, "xforwardedfor-"+hash, savedHashKey]
		values = [host, clientIP, hash]
		keys.forEach_ _, -1, (_, k, i) ->
			redisClient.set [k, values[i]], _
			redisClient.expire [k, settings.hostTunnelingCaching], _
	hash

redirectToHash = (res, hash, path) ->
	redirect = "https://"+hash+"."+settings.hostTunnelingDomain+path
	res.writeHead 302, {Location:redirect}
	res.end """<html><body>The unblock.us.org project<br /><br />Unblocked at <a href="#{redirect}">#{redirect}</a></body></html>"""

contentTypes = {
	"application/javascript", "application/xhtml+xml", "application/xml", "image/svg+xml", "text/css", "text/html", "text/javascript"
}
isAltered = (ct) -> contentTypes[ct]?


# This will probably need a lot of tweaking
# TODO: Document this monster
rDomains = new RegExp "(.|^)((?:https://)?(?:(?:[a-zA-Z0-9\-]+\\\\?[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "\\\\?[.]")+")" for a of settings.hijacked).join("|")+"))", "g"
rLookbehind = new RegExp "^[^a-zA-Z0-9\-.]?$"
rDots = new RegExp "[.]", "g"

redirectAllURLs = (str, redisClient, clientIP, _) ->
	limiter = new Bottleneck 1
	asyncReplace str, rDomains, ((whole, lookbehind, found, position, text, _) ->
		if not rLookbehind.test(lookbehind) then return found # False positive. Javascript doesn't support real lookbehinds

		backslashes = if found.indexOf("\\") > 0 then true else false

		parsed = url.parse found
		parsed.path = ""
		parsed.pathname = ""
		if not parsed.host? or not parsed.hostname?
			parsed.hostname = parsed.href
		parsed.host = null # Force the url module to use hostname+port
		if parsed.protocol? then parsed.protocol = "https"
		hash = limiter.submit getHash, redisClient, parsed.hostname, clientIP, _
		parsed.hostname = hash+"."+settings.hostTunnelingDomain

		# Final formatting
		formatted = url.format parsed
		if formatted[0..1] == "//" then formatted = formatted[2..]
		if backslashes then formatted = formatted.replace rDots, "\\."
		lookbehind+formatted
	), _

module.exports = {getHash, redirectToHash, isAltered, redirectAllURLs}
