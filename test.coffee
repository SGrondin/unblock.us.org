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
# rDomains = new RegExp "(?:https://)?(?:(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
rDomains = new RegExp "(?:https://(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
url = require "url"
str = """ <li><a href="//support.twitter.com">Help</a><span class="dot divider"> &middot;</span></li>"""

console.log str.replace rDomains, (found) ->
	con (Object.keys arguments).length
	parsed = url.parse found, false, false
	con found
	con parsed
	parsed.path = ""
	parsed.pathname = ""
	if not parsed.host? or not parsed.hostname?
		parsed.hostname = parsed.href
	parsed.host = null # Force the url module to use hostname+port
	if parsed.protocol? then parsed.protocol = "https"
	hash = "ABCDEF"
	parsed.hostname = hash+".unblock.us.org"

	con parsed
	con url.format parsed
	formatted = url.format parsed
	if formatted[0..1] == "//" then formatted[2..] else formatted
