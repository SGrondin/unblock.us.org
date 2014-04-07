(function() {
  var Bottleneck, cluster, cpus, createWorker, i, limiter, nbWorkers, timeouts, workers, _i;

  cluster = require("cluster");

  cpus = require("os").cpus().length;

  nbWorkers = Math.min(4, cpus);

  Bottleneck = require("bottleneck");

  limiter = new Bottleneck(nbWorkers, 3000);

  workers = {};

  timeouts = {};

  createWorker = function() {
    var id, timeout, worker;
    worker = cluster.fork();
    id = worker.id;
    timeout = setTimeout(function() {
      console.log("worker " + id + " took too long to start, killing it");
      return worker != null ? worker.kill() : void 0;
    }, 3000);
    worker.on("message", function(message) {
      if (message.cmd && message.cmd === "online") {
        clearTimeout(timeout);
        workers[id] = worker;
        return console.log("online " + id);
      }
    });
    console.log("forked " + id);
    return worker.on("exit", function(code, signal) {
      worker = null;
      console.log("worker crashed " + id + "\nCode: " + code + "\nSignal: " + signal + "\nRestarting it...");
      return limiter.submit(createWorker, null);
    });
  };

  if (cluster.isMaster) {
    for (i = _i = 1; 1 <= nbWorkers ? _i <= nbWorkers : _i >= nbWorkers; i = 1 <= nbWorkers ? ++_i : --_i) {
      createWorker();
    }
  } else {
    require("./worker");
  }

}).call(this);
