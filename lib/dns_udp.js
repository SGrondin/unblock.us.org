(function() {
  var bitconcat, forwardGoogleUDP, parseUDP, sendUDP, udp;

  udp = require("dgram");

  bitconcat = require("bitconcat");

  parseUDP = function(packet) {
    var err, len, name, nb, pos, res;
    try {
      if (packet.length < 16) {
        throw new Error("Packet too short to be valid");
      }
      res = {};
      res.ID = packet.slice(0, 2).toArray();
      res.QR = packet[2] & 0x80;
      res.OPCODE = packet[2] & 0x78;
      res.AA = packet[2] & 0x4;
      res.TC = packet[2] & 0x2;
      res.RD = packet[2] & 0x1;
      res.RA = packet[3] & 0x80;
      res.Z = packet[3] & 0x70;
      res.RCODE = packet[3] & 0xf;
      res.QDCOUNT = packet.slice(4, 6).toArray();
      res.ANCOUNT = packet.slice(6, 8).toArray();
      res.NSCOUNT = packet.slice(8, 10).toArray();
      res.ARCOUNT = packet.slice(10, 12).toArray();
      res.QUESTION = {};
      nb = 0;
      pos = 12;
      len = packet[pos];
      name = [];
      while (len !== 0 && nb < 15) {
        name.push(packet.slice(pos + 1, +(pos + len) + 1 || 9e9).toArray().map(function(a) {
          return String.fromCharCode(a);
        }).reduce(function(a, b) {
          return a + b;
        }));
        pos += len + 1;
        len = packet[pos];
        nb++;
      }
      res.QUESTION = {
        NAME: name.join("."),
        TYPE: packet.slice(pos, +(pos + 1) + 1 || 9e9).toArray(),
        CLASS: packet.slice(pos + 2, +(pos + 3) + 1 || 9e9).toArray()
      };
      if (!(res.QUESTION.NAME.length > 0 && res.QUESTION.CLASS.length === 2)) {
        throw new Error("Invalid QUESTION.NAME");
      }
      return res;
    } catch (_error) {
      err = _error;
      con(err);
      return null;
    }
  };

  sendUDP = function(socket, ip, port, data, cb) {
    var clean, done, timeoutSend;
    if (socket == null) {
      done = false;
      socket = udp.createSocket("udp4");
      timeoutSend = setTimeout(function() {
        if (!done) {
          clean();
          return cb(new Error("Time exceeded"));
        }
      }, 800);
      clean = function() {
        clearTimeout(timeoutSend);
        done = true;
        return socket.close();
      };
      socket.on("error", function(err) {
        if (!done) {
          clean();
          return cb(err);
        }
      });
      socket.on("close", function() {
        if (!done) {
          clean();
          return cb(new Error("socket closed"));
        }
      });
      socket.on("message", function(data, info) {
        if (!done) {
          clean();
          return cb(null, data, info);
        }
      });
      return socket.send(data, 0, data.length, port, ip);
    } else {
      done = false;
      timeoutSend = setTimeout(function() {
        if (!done) {
          done = true;
          return cb("Send2 time exceeded");
        }
      }, 1000);
      return socket.send(data, 0, data.length, port, ip, function() {
        clearTimeout(timeoutSend);
        if (!done) {
          done = true;
          return cb(null);
        }
      });
    }
  };

  forwardGoogleUDP = function(data, limiterUDP, cb) {
    var done, nbErrors, start, timeoutAlt, timeoutDown;
    start = Date.now();
    nbErrors = 0;
    done = false;
    timeoutDown = setTimeout(function() {
      if (!done) {
        clearTimeout(timeoutAlt);
        done = true;
        return cb(new Error("Time exceeded (" + nbErrors + " errors)"));
      }
    }, 800);
    timeoutAlt = setTimeout(function() {
      return limiterUDP.submit(sendUDP, null, "8.8.4.4", 53, data, function(err, resData, resInfo) {
        if (err != null) {
          con("ALT", err);
          nbErrors++;
        }
        if (!done && (err == null)) {
          clearTimeout(timeoutDown);
          done = true;
          console.log(Date.now() - start, "8.8.4.4");
          return cb(null, resData, resInfo);
        }
      });
    }, 80);
    return limiterUDP.submit(sendUDP, null, "8.8.8.8", 53, data, function(err, resData, resInfo) {
      if (err != null) {
        con("MAIN", err);
        nbErrors++;
      }
      if (!done && (err == null)) {
        clearTimeout(timeoutAlt);
        clearTimeout(timeoutDown);
        done = true;
        console.log(Date.now() - start, "8.8.8.8");
        return cb(null, resData, resInfo);
      }
    });
  };

  module.exports = {
    parseUDP: parseUDP,
    sendUDP: sendUDP,
    forwardGoogleUDP: forwardGoogleUDP
  };

}).call(this);
