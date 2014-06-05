(function() {
  var getRequest, libDNS;

  libDNS = require("./dns");

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
    getRequest: getRequest
  };

}).call(this);
