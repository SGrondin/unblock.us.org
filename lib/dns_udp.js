(function() {
  var bitconcat, forwardGoogleUDP, sendUDP, udp;

  udp = require("dgram");

  bitconcat = require("bitconcat");

  sendUDP = function(socket, ip, port, data, cb) {
    var clean, timeoutSend;
    if (socket == null) {
      socket = udp.createSocket("udp4");
      timeoutSend = setTimeout(function() {
        return clean(new Error("Time exceeded"));
      }, 1500);
      clean = function(err, data, info) {
        clean = function() {};
        clearTimeout(timeoutSend);
        socket.removeAllListeners();
        socket.close();
        return cb(err, data, info);
      };
      socket.on("error", function(err) {
        return clean(err);
      });
      socket.on("message", function(data, info) {
        return clean(null, data, info);
      });
      return socket.send(data, 0, data.length, port, ip, function(err) {
        if (err != null) {
          return clear(err);
        }
      });
    } else {
      clean = function(err) {
        clean = function() {};
        clearTimeout(timeoutSend);
        return cb(err);
      };
      timeoutSend = setTimeout(function() {
        return clean(new Error("Send time exceeded"));
      }, 3000);
      return socket.send(data, 0, data.length, port, ip, function(err) {
        return clean(err);
      });
    }
  };

  forwardGoogleUDP = function(data, limiterUDP, cb) {
    var clean, nbErrors, timeoutAlt, timeoutDown;
    nbErrors = 0;
    clean = function(err, data, info) {
      clean = function() {};
      clearTimeout(timeoutAlt);
      clearTimeout(timeoutDown);
      return cb(err, data, info);
    };
    timeoutDown = setTimeout(function() {
      return clean(new Error("Time exceeded (" + nbErrors + " errors)"));
    }, 1500);
    timeoutAlt = setTimeout(function() {
      return limiterUDP.submit(sendUDP, null, "8.8.4.4", 53, data, function(err, resData, resInfo) {
        if (err != null) {
          con("ALT", err);
          nbErrors++;
        }
        return clean(err, resData, resInfo);
      });
    }, 80);
    return limiterUDP.submit(sendUDP, null, "8.8.8.8", 53, data, function(err, resData, resInfo) {
      if (err != null) {
        con("MAIN", err);
        nbErrors++;
      }
      return clean(err, resData, resInfo);
    });
  };

  module.exports = {
    sendUDP: sendUDP,
    forwardGoogleUDP: forwardGoogleUDP
  };

}).call(this);
