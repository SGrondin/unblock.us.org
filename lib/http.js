(function() {
  var getHTTPstream, tcp;

  tcp = require("net");

  getHTTPstream = function(host, cb) {
    var clean, s;
    clean = function(err, s) {
      clean = function() {};
      return cb(err, s);
    };
    s = tcp.createConnection({
      port: 80,
      host: host
    }, function() {
      return clean(null, s);
    });
    s.on("error", function(err) {
      s.destroy();
      return clean(err);
    });
    s.on("close", function() {
      s.destroy();
      return clean(new Error("HTTP socket was closed"));
    });
    return s.on("timeout", function() {
      s.destroy();
      return clean(new Error("HTTP socket timeout"));
    });
  };

  module.exports = {
    getHTTPstream: getHTTPstream
  };

}).call(this);
