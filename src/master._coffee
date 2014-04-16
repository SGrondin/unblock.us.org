cluster = require "cluster"
cpus = require("os").cpus().length
redis = require "redis"
settings = require "../settings"
nbWorkers = Math.min 4, cpus
Bottleneck = require "bottleneck"
limiter = new Bottleneck nbWorkers, 3000

#########
# STATS #
#########

redisClient = redis.createClient()
redisClient.select settings.redisDB
statsStart = ["https.fail.start", "https.start",
	"udp.fail.start", "udp.start",
	"tcp.fail.start", "tcp.start"]
stats = ["https.fail", "https",
	"udp.fail", "udp",
	"tcp.fail", "tcp"]
resetKeys = (keys, _) ->
	keys.forEach_ _, -1, (_, k) ->
		redisClient.set k, 0
resetKeys statsStart.concat(stats), ->

setInterval ->
	resetKeys stats, ->
, (60 * 1000)


###########
# CLUSTER #
###########

workers = {}
timeouts = {}
createWorker = ->
	worker = cluster.fork()
	id = worker.id

	timeout = setTimeout ->
		console.log "worker "+id+" took too long to start, killing it"
		worker?.kill()
	, 3000

	worker.on "message", (message) ->
		if message.cmd and message.cmd == "online"
			clearTimeout timeout
			workers[id] = worker
			console.log "online "+id

	console.log "forked "+id
	worker.on "exit", (code, signal) ->
		worker = null
		console.log "worker crashed "+id+"\nCode: "+code+"\nSignal: "+signal+"\nRestarting it..."
		limiter.submit createWorker, null

if cluster.isMaster
	for i in [1..nbWorkers]
		createWorker()
else
	require "./worker"
