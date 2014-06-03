udp = require "dgram"
settings = require "../settings"
libDNS = require "./dns"

toDNSserver = (DNSlistenServer, redisClient, data, info, version, parsed, _) ->
	keyName = libDNS.parse2Bytes(parsed.ID)+"-"+parsed.QUESTION.TYPE+"-"+parsed.QUESTION.NAME.join(".")
	keys = [keyName+"-port", keyName+"-IP", keyName+"-version"]
	values = [info.port, info.address, version]
	keys.forEach_ _, -1, (_, k, i) ->
		redisClient.set [k, values[i]], _
		redisClient.expire k, 12, _ # node-redis doesn't support the new SET yet

	DNSlistenServer.send data, 0, data.length, settings.forwardDNSport, settings.forwardDNS

toClient = (UDPservers, redisClient, data, _) ->
	parsed = libDNS.parseDNS data
	keyName = libDNS.parse2Bytes(parsed.ID)+"-"+parsed.QUESTION.TYPE+"-"+parsed.QUESTION.NAME.join(".")
	[port, ip, version] = redisClient.mget [keyName+"-port", keyName+"-IP", keyName+"-version"], _
	if not (port? and ip? and version?) then throw new Error "Took too long for: "+parsed.QUESTION.NAME.join(".")
	UDPservers["udp"+version].send data, 0, data.length, port, ip
	[port, ip, version]

module.exports = {toDNSserver, toClient}
