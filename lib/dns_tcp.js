(function() {
  var forwardGoogleTCP, tcp;

  tcp = require("net");

  forwardGoogleTCP = function(client, cb) {
    var clean, done, google;
    done = false;
    clean = function(err, client, google) {
      if (!done) {
        done = true;
        google.destroy();
        client.destroy();
        cb(err);
      }
      return cb(err);
    };
    google = tcp.createConnection({
      port: 53,
      host: "8.8.8.8"
    }, function() {
      client.pipe(google).pipe(client);
      client.on("error", function(err) {
        return clean(err, client, google);
      });
      return google.on("error", function(err) {
        return clean(err, client, google);
      });
    });
    return client.on("end", function() {
      if (!done) {
        return clean(null, client, google);
      }
    });
  };

  module.exports = {
    forwardGoogleTCP: forwardGoogleTCP
  };

}).call(this);
