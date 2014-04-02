(function() {
  var getHTTPSstream, getRequest, libDNS, parseHTTPS, tcp;

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
    } else {
      throw new Error("No SNI found.");
    }
    return res;
  };

  getHTTPSstream = function(domain, cb) {
    var s;
    s = tcp.createConnection({
      port: 443,
      host: "74.125.226.137"
    });
    return s.on("connect", function() {
      return cb(null, s);
    });
  };

  getRequest = function(c, cb) {
    var clean, received;
    received = new Buffer([]);
    clean = function(err, host) {
      c.removeAllListeners();
      return cb(err, host, received);
    };
    c.on("data", function(data) {
      var ssl;
      received = Buffer.concat([received, data]);
      ssl = parseHTTPS(received);
      if ((ssl != null ? ssl.host : void 0) != null) {
        return clean(null, ssl.host, received);
      }
    });
    c.on("timeout", function() {
      return clean(new Error("HTTPS getRequest timeout"));
    });
    c.on("error", function(err) {
      return clean(err);
    });
    c.on("close", function() {
      return clean(new Error("HTTPS socket closed"));
    });
    return c.on("end", function() {
      return clean(new Error("HTTPS getRequest socket closed"));
    });
  };

  module.exports = {
    getHTTPSstream: getHTTPSstream,
    getRequest: getRequest
  };

}).call(this);
