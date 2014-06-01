cluster = require "cluster"
cpus = require("os").cpus().length
redis = require "redis"
settings = require "../settings"
nbWorkers = Math.min 4, cpus

#########
# STATS #
#########

if cluster.isMaster
	redisClient = redis.createClient()
	redisClient.select settings.redisDB
	redisClient.flushdb _

	resetEveryInterval = [
		"udp", "udp.fail", "tcp", "tcp.fail"
		"http", "http.fail", "https", "https.fail"
	]

	interval = (_) ->
		resetEveryInterval.forEach_ _, -1, (_, k) ->
			redisClient.set k, 0, _

	setInterval ->
		interval ->
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
		createWorker()

if cluster.isMaster
	for i in [1..nbWorkers]
		createWorker()
else
	require "./worker"
