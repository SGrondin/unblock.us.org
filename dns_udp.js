(function() {
  var forwardGoogleUDP, parseUDP, sendUDP, udp;

  udp = require("dgram");

  parseUDP = function(packet) {};

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
      }, 600);
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
      return socket.send(data, 0, data.length, port, ip, cb);
    }
  };

  forwardGoogleUDP = function(data, limiterUDP, cb) {
    var done, nbErrors, timeoutAlt, timeoutDown;
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
          nbErrors++;
        }
        if (!done && (err == null)) {
          clearTimeout(timeoutDown);
          done = true;
          return cb(null, resData, resInfo);
        }
      });
    }, 80);
    return limiterUDP.submit(sendUDP, null, "8.8.8.8", 53, data, function(err, resData, resInfo) {
      if (err != null) {
        nbErrors++;
      }
      if (!done && (err == null)) {
        clearTimeout(timeoutAlt);
        clearTimeout(timeoutDown);
        done = true;
        return cb(null, resData, resInfo);
      }
    });
  };

  module.exports = {
    sendUDP: sendUDP,
    forwardGoogleUDP: forwardGoogleUDP
  };

}).call(this);
