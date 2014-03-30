(function() {
  var forwardGoogleTCP, getGoogleStream, getRequest, libDNS, tcp;

  tcp = require("net");

  libDNS = require("./dns");

  getGoogleStream = function(cb) {
    var google;
    google = tcp.createConnection({
      port: 53,
      host: "8.8.8.8"
    });
    return google.on("connect", function() {
      return cb(null, google);
    });
  };

  forwardGoogleTCP = function(client, cb) {
    var google;
    return google = tcp.createConnection({
      port: 53,
      host: "8.8.8.8"
    }, function() {
      return client.pipe(google).pipe(client);
    });
  };

  getRequest = function(client, cb) {
    var clean, lengthExpected, received;
    received = [];
    lengthExpected = null;
    clean = function(err, req) {
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
      return clean("getRequestClientClosedConnection");
    });
  };

  module.exports = {
    getGoogleStream: getGoogleStream,
    forwardGoogleTCP: forwardGoogleTCP,
    getRequest: getRequest
  };

}).call(this);
