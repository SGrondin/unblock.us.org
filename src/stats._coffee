util = require "util"
settings = require "../settings.js"
global.con = -> console.log Array::concat(new Date().toISOString(), Array::slice.call(arguments, 0)).map((a)->util.inspect a).join " "
redis = require "redis"
redisClient = redis.createClient()
redisClient.select settings.redisDB, _

counters = ["https.fail.start", "https.start", "https.fail", "https",
	"udp.fail.start", "udp.start", "udp.fail", "udp",
	"tcp.fail.start", "tcp.start", "tcp.fail", "tcp"]

showStats = (_) ->
	countersStats = redisClient.mget counters, _
	console.log new Date().toISOString()+" "+
				"UDP "+countersStats[6]+"/"+countersStats[7]+" "+countersStats[4]+"/"+countersStats[5]+
				" TCP "+countersStats[10]+"/"+countersStats[11]+" "+countersStats[8]+"/"+countersStats[9]+
				" HTTPS "+countersStats[2]+"/"+countersStats[3]+" "+countersStats[0]+"/"+countersStats[1]
	countriesDNS = redisClient.hgetall "countries.dns", _
	countriesHTTPS = redisClient.hgetall "countries.https", _

	ipDNScountries = redisClient.smembers "ip.dns.countries", _
	ipHTTPScountries = redisClient.smembers "ip.https.countries", _


	ipDNScountries = ipDNScountries.map_ _, 10, (_, country) ->
		country+":"+(redisClient.scard "ip.dns."+country, _)

	ipHTTPScountries = ipHTTPScountries.map_ _, 10, (_, country) ->
		country+":"+(redisClient.scard "ip.https."+country, _)

	con countriesDNS
	con countriesHTTPS
	con ipDNScountries
	con ipHTTPScountries

showStats ->
setInterval ->
	showStats ->
, (30 * 1000)
