cluster = require "cluster"
cpus = require("os").cpus().length
Bottleneck = require "bottleneck"
limiter = new Bottleneck 3, 3000


workers = {}
timeouts = {}
createWorker = () ->
	worker = cluster.fork()
	id = worker.id

	timeout = setTimeout () ->
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
	for i in [1..(Math.min 4, cpus)]
		createWorker()
else
	require "./worker"
