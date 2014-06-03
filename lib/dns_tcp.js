(function() {
  var getDNSstream, getRequest, libDNS, settings, tcp;

  tcp = require("net");

  settings = require("../settings");

  libDNS = require("./dns");

  getDNSstream = function(cb) {
    var stream;
    stream = tcp.createConnection({
      port: settings.forwardDNSport,
      host: settings.forwardDNS
    }, function() {
      return cb(null, stream);
    });
    stream.on("error", function(err) {
      return stream.destroy();
    });
    stream.on("close", function() {
      return stream.destroy();
    });
    return stream.on("timeout", function() {
      return stream.destroy();
    });
  };

  getRequest = function(client, cb) {
    var clean, lengthExpected, received;
    received = [];
    lengthExpected = null;
    clean = function(err, req) {
      clean = function() {};
      client.removeAllListeners();
      return cb(err, req);
    };
    client.on("error", function(err) {
      return clean(err);
    });
    client.on("timeout", function() {
      return clean(new Error("getRequestClientTimeout"));
    });
    client.on("data", function(chunk) {
      received.push(chunk);
      if ((lengthExpected == null) && client.bytesRead >= 2) {
        lengthExpected = libDNS.parse2Bytes(Buffer.concat(received).slice(0, 2));
      }
      if ((lengthExpected != null) && lengthExpected >= client.bytesRead - 2) {
        return clean(null, Buffer.concat(received).slice(2, +(lengthExpected + 1) + 1 || 9e9));
      }
    });
    return client.on("end", function() {
      return clean("TCPgetRequestClientClosedConnection");
    });
  };

  module.exports = {
    getDNSstream: getDNSstream,
    getRequest: getRequest
  };

}).call(this);
