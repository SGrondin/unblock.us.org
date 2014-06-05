(function() {
  var getRequest, getStream, libDNS, parseHTTPS, tcp;

  tcp = require("net");

  libDNS = require("./dns");

  parseHTTPS = function(packet) {
    var extensionsEnd, pos, res;
    res = {};
    res.contentType = packet[0];
    res.recordVersion = packet.slice(1, 3);
    res.recordLength = libDNS.parse2Bytes(packet.slice(3, 5));
    res.handshakeType = packet[5];
    res.handshakeLength = libDNS.parse3Bytes(packet.slice(6, 9));
    res.handshakeVersion = packet.slice(9, 11);
    res.random = packet.slice(11, 43);
    res.sessionIDlength = packet[43];
    pos = res.sessionIDlength + 43 + 1;
    res.cipherSuitesLength = libDNS.parse2Bytes(packet.slice(pos, +(pos + 1) + 1 || 9e9));
    pos += res.cipherSuitesLength + 2;
    res.compressionMethodsLength = packet[pos];
    pos += res.compressionMethodsLength + 1;
    res.extensionsLength = libDNS.parse2Bytes(packet.slice(pos, +(pos + 1) + 1 || 9e9));
    pos += 2;
    extensionsEnd = pos + res.extensionsLength - 1;
    res.type = -1;
    res.length = 0;
    while (res.type !== 0 && pos < extensionsEnd) {
      pos += res.length;
      res.type = libDNS.parse2Bytes(packet.slice(pos, +(pos + 1) + 1 || 9e9));
      res.length = libDNS.parse2Bytes(packet.slice(pos + 2, +(pos + 3) + 1 || 9e9));
    }
    res.SNIlength = libDNS.parse2Bytes(packet.slice(pos + 4, +(pos + 5) + 1 || 9e9));
    res.serverNameType = packet[pos + 6];
    pos += 7;
    if (res.type === 0 && res.SNIlength >= 4) {
      res.hostLength = libDNS.parse2Bytes(packet.slice(pos, +(pos + 1) + 1 || 9e9));
      pos += 2;
      res.host = packet.slice(pos, +(pos + res.hostLength - 1) + 1 || 9e9).toString("utf8");
      return res;
    } else {
      return null;
    }
  };

  getStream = function(host, port, cb) {
    var err, s;
    try {
      s = tcp.createConnection({
        host: host,
        port: port
      }, function() {
        return cb(null, s);
      });
      s.on("error", function(err) {
        return s.destroy();
      });
      s.on("close", function() {
        return s.destroy();
      });
      return s.on("timeout", function() {
        return s.destroy();
      });
    } catch (_error) {
      err = _error;
      return con("HTTPS TRY CATCH", err, err.stack);
    }
  };

  getRequest = function(c, cb) {
    var buf, clean, received;
    received = [];
    buf = new Buffer([]);
    clean = function(err, host, buf) {
      c.removeAllListeners("data");
      clean = function() {};
      return cb(err, host, buf);
    };
    c.on("data", function(data) {
      var ssl;
      c.pause();
      received.push(data);
      buf = Buffer.concat(received);
      ssl = parseHTTPS(buf);
      if ((ssl != null ? ssl.host : void 0) != null) {
        return clean(null, ssl.host, buf);
      } else {
        return c.resume();
      }
    });
    c.on("timeout", function() {
      c.destroy();
      return clean(new Error("HTTPS getRequest timeout"));
    });
    c.on("error", function(err) {
      c.destroy();
      return clean(err);
    });
    return c.on("close", function() {
      c.destroy();
      return clean(new Error("HTTPS socket closed"));
    });
  };

  module.exports = {
    getStream: getStream,
    getRequest: getRequest
  };

}).call(this);
