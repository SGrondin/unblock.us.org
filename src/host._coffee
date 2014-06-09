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
rDomains = new RegExp "(.|^)(?:https://)?(?:(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
rLookbehind = new RegExp "^[^a-zA-Z0-9\-.]?$"
redirectAllURLs = (str, redisClient, limiter, clientIP, _) ->
	if Array.isArray str # Cookies are arrays
		return str.map_ _, -1, (_, s) ->
			redirectAllURLs s, redisClient, limiter, clientIP, _
	asyncReplace str, rDomains, ((found, lookbehind, position, text, _) ->
		if not rLookbehind.test(lookbehind) then return found # False positive. Javascript doesn't support real lookbehinds
		if lookbehind.length > 0 then found = found[1..]

		parsed = url.parse found
		parsed.path = ""
		parsed.pathname = ""
		if not parsed.host? or not parsed.hostname?
			parsed.hostname = parsed.href
		parsed.host = null # Force the url module to use hostname+port
		if parsed.protocol? then parsed.protocol = "https"
		hash = limiter.submit getHash, redisClient, parsed.hostname, clientIP, _
		parsed.hostname = hash+"."+settings.hostTunnelingDomain
		formatted = url.format parsed
		if formatted[0..1] == "//" then lookbehind+formatted[2..] else lookbehind+formatted
	), _

sendCuratedData = (res, pres, redisClient, limiter, clientIP, _) ->
	["access-control-allow-origin", "set-cookie"].forEach_ _, -1, (_, header) ->
		if pres.headers[header]?.length > 0
			pres.headers[header] = redirectAllURLs pres.headers[header], redisClient, limiter, clientIP, _

	res.writeHead pres.statusCode, pres.headers
	altered = isAltered pres.headers["content-type"]?.toLowerCase().split(";")[0].trim()
	if altered
		buffers = []
		pres.on "data", (data) ->
			buffers.push data
		pres.on "end", ->
			# TODO: Some kind of pumping mechanism instead of a giant buffer all at once
			redirectAllURLs (new Buffer Buffer.concat buffers).toString("utf8"), redisClient, limiter, clientIP, (err, curatedPage) ->
				if err? then throw err
				res.end curatedPage, "utf8"
	else
		pres.on "data", (data) ->
			res.write data
		pres.on "end", ->
			res.end()


module.exports = {getHash, redirectToHash, redirectAllURLs, sendCuratedData}
