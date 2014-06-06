url = require "url"
util = require "util"
con = (v) -> util.puts util.inspect v
settings = {
	"hijacked" : {
		"youtube.com" : "youtube.com",
		"ggpht.com" : "ggpht.com",
		"ytimg.com" : "ggpht.com",
		"youtube-nocookie.com" : "youtube-nocookie.com",
		"youtu.be" : "youtu.be",

		"twimg.com" : "twimg.com",
		"twitter.com" : "twitter.com",
		"t.co" : "t.co"
	}
}


# rDomains = new RegExp "(.|^)(?:https://)?(?:(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
rDomains = new RegExp "(.|^)((?:https://)?(?:(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+"))", "g"
rLookbehind = new RegExp "^[^a-zA-Z0-9\-.]?$"
rDots = new RegExp "[.]", "g"
str = """t.co t.co<li><a href="//support.twitter.com">Help</a>i1.ytimg.com<spat.con class="dot divider"> &middot;</span>support.twitter\\.com</li>"""

console.log rDomains
# console.log str+"\n"
console.log str.replace rDomains, (whole, lookbehind, found) ->
	if not rLookbehind.test(lookbehind) then return found

	backslashes = if found.indexOf("\\") > 0 then true else false
	con found
	con lookbehind

	parsed = url.parse found
	parsed.path = ""
	parsed.pathname = ""
	if not parsed.host? or not parsed.hostname?
		parsed.hostname = parsed.href
	parsed.host = null # Force the url module to use hostname+port
	if parsed.protocol? then parsed.protocol = "https"
	hash = "ABCDEF"
	parsed.hostname = hash+".unblock.us.org"

	# Final formatting
	formatted = url.format parsed
	if formatted[0..1] == "//" then formatted = formatted[2..]
	if backslashes then formatted = formatted.replace rDots, "\\."
	lookbehind+formatted
