(function() {
  var forwardUDP, sendUDP, settings, udp;

  udp = require("dgram");

  settings = require("../settings");

  sendUDP = function(socket, ip, port, data, cb) {
    var clean1, clean2, timeoutSend;
    if (!(data != null ? data.length : void 0) > 0) {
      throw new Error("Packet can't be sent: " + data);
    }
    if (socket == null) {
      socket = udp.createSocket("udp4");
      clean1 = function(err, data, info) {
        clean1 = function() {};
        clearTimeout(timeoutSend);
        socket.close();
        return cb(err, data, info);
      };
      timeoutSend = setTimeout(function() {
        return clean1(new Error("Time exceeded"));
      }, 4000);
      socket.on("error", function(err) {
        return clean1(err);
      });
      socket.on("close", function() {
        return clean1(new Error("UDP send socket closed"));
      });
      socket.on("message", function(data, info) {
        return clean1(null, data, info);
      });
      return socket.send(data, 0, data.length, port, ip, function(err) {
        if (err != null) {
          return clean1(err);
        }
      });
    } else {
      clean2 = function(err) {
        clean2 = function() {};
        clearTimeout(timeoutSend);
        return cb(err);
      };
      timeoutSend = setTimeout(function() {
        return clean2(new Error("Send time exceeded"));
      }, 4000);
      return socket.send(data, 0, data.length, port, ip, function(err) {
        return clean2(err);
      });
    }
  };

  forwardUDP = function(data, cb) {
    var clean, nbErrors, timeoutDown;
    nbErrors = 0;
    clean = function(err, data, info) {
      clean = function() {};
      clearTimeout(timeoutDown);
      return cb(err, data, info);
    };
    timeoutDown = setTimeout(function() {
      return clean(new Error("Time exceeded (" + nbErrors + " errors)"));
    }, 4500);
    return sendUDP(null, settings.forwardDNS, settings.forwardDNSPort, data, function(err, resData, resInfo) {
      if (err != null) {
        nbErrors++;
      }
      return clean(err, resData, resInfo);
    });
  };

  module.exports = {
    sendUDP: sendUDP,
    forwardUDP: forwardUDP
  };

}).call(this);
