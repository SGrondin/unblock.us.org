util = require "util"
settings = require "../settings.js"
global.con = -> console.log Array::concat(new Date().toISOString(), Array::slice.call(arguments, 0)).map((a)->util.inspect a).join " "
redis = require "redis"
redisClient = redis.createClient()
redisClient.select settings.redisDB, _

counters = [
	"udp.fail", "udp", "udp.fail.start", "udp.start"
	"tcp.fail", "tcp", "tcp.fail.start", "tcp.start"
	"http.fail", "http", "http.fail.start", "http.start"
	"https.fail", "https", "https.fail.start", "https.start"
]

showStats = (_) ->
	countersStats = (v or 0 for v in redisClient.mget counters, _)
	console.log new Date().toISOString()+" "+
				"UDP "+countersStats[0]+"/"+countersStats[1]+"_"+countersStats[2]+"/"+countersStats[3]+
				" TCP "+countersStats[4]+"/"+countersStats[5]+"_"+countersStats[6]+"/"+countersStats[7]+
				" HTTP "+countersStats[8]+"/"+countersStats[9]+"_"+countersStats[10]+"/"+countersStats[11]+
				" HTTPS "+countersStats[12]+"/"+countersStats[13]+"_"+countersStats[14]+"/"+countersStats[15]
	countriesDNS = redisClient.hgetall "countries.dns", _
	countriesHTTP = redisClient.hgetall "countries.http", _

	ipDNScountries = redisClient.smembers "ip.dns.countries", _
	ipHTTPcountries = redisClient.smembers "ip.http.countries", _


	ipDNScountries = ipDNScountries.map_ _, 10, (_, country) ->
		country+":"+(redisClient.scard "ip.dns."+country, _)

	ipHTTPcountries = ipHTTPcountries.map_ _, 10, (_, country) ->
		country+":"+(redisClient.scard "ip.http."+country, _)

	con "DNS", countriesDNS
	con "HTTP", countriesHTTP
	con "DNS", ipDNScountries
	con "HTTP", ipHTTPcountries

showStats ->
setInterval ->
	showStats ->
, (3 * 1000)
