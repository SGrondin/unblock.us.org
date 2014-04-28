(function() {
  var forwardGoogleUDP, sendUDP, udp;

  udp = require("dgram");

  sendUDP = function(socket, ip, port, data, cb) {
    var clean1, clean2, t1, t2, timeoutSend;
    if (socket == null) {
      socket = udp.createSocket("udp4");
      clean1 = function(err, data, info) {
        clean1 = function() {};
        clearTimeout(timeoutSend);
        socket.removeAllListeners();
        socket.close();
        return cb(err, data, info);
      };
      timeoutSend = setTimeout(function() {
        return clean1(new Error("Time exceeded"));
      }, 3000);
      socket.on("error", function(err) {
        return clean1(err);
      });
      socket.on("close", function() {
        return clean1(new Error("UDP socket closed"));
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
      t1 = Date.now();
      timeoutSend = setTimeout(function() {
        redisClient.rpush("udp.diag.timeout", Date.now() - t1);
        return clean2(new Error("Send time exceeded"));
      }, 3000);
      t2 = Date.now();
      return socket.send(data, 0, data.length, port, ip, function(err) {
        redisClient.rpush("udp.diag.callback", Date.now() - t2);
        return clean2(err);
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
    }, 3500);
    timeoutAlt = setTimeout(function() {
      return limiterUDP.submit(sendUDP, null, "8.8.4.4", 53, data, function(err, resData, resInfo) {
        if (err != null) {
          nbErrors++;
        }
        return clean(err, resData, resInfo);
      });
    }, 80);
    return limiterUDP.submit(sendUDP, null, "8.8.8.8", 53, data, function(err, resData, resInfo) {
      if (err != null) {
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
