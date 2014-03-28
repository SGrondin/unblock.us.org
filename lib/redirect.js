(function() {
  var CLASSES, IPv4, NAMEERROR, SERVERFAILURE, TYPES, bitconcat, getAnswer, getClass, getType, makeUDP, parse2Bytes, parseUDP, redirects;

  bitconcat = require("bitconcat");

  TYPES = require("../defs/types");

  CLASSES = require("../defs/classes");

  IPv4 = "176.58.120.112";

  SERVERFAILURE = {
    RCODE: 2,
    ANCOUNT: 0,
    NSCOUNT: 0,
    ARCOUNT: 0,
    ANSWER: []
  };

  NAMEERROR = {
    RCODE: 3,
    ANCOUNT: 0,
    NSCOUNT: 0,
    ARCOUNT: 0,
    ANSWER: []
  };

  redirects = {
    "twitter.com": {
      "A": {
        RCODE: 0,
        ANCOUNT: [0, 1],
        NSCOUNT: [0, 0],
        ARCOUNT: [0, 0],
        ANSWER: [0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 4, 0, 4, 127, 0, 0, 1]
      },
      "AAAA": {
        RCODE: 0,
        ANCOUNT: [0, 1],
        NSCOUNT: [0, 0],
        ARCOUNT: [0, 0],
        ANSWER: [0xc0, 0x0c, 0, 0x1c, 0, 1, 0, 0, 0, 4, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
      }
    }
  };

  parse2Bytes = function(buf) {
    return (buf[0] << 8) | buf[1];
  };

  getType = function(buf) {
    var p;
    p = parse2Bytes(buf);
    if (TYPES[p] != null) {
      return TYPES[p];
    } else {
      return "INVALID";
    }
  };

  getClass = function(buf) {
    var p;
    p = parse2Bytes(buf);
    if (CLASSES[p] != null) {
      return CLASSES[p];
    } else {
      return "INVALID";
    }
  };

  parseUDP = function(packet) {
    var err, len, name, nb, pos, res;
    try {
      if (packet.length < 16) {
        throw new Error("Packet too short to be valid");
      }
      res = {};
      res.ID = packet.slice(0, 2);
      res.QR = (packet[2] & 0x80) >>> 7;
      res.OPCODE = (packet[2] & 0x78) >>> 3;
      res.AA = (packet[2] & 0x4) >>> 2;
      res.TC = (packet[2] & 0x2) >>> 1;
      res.RD = packet[2] & 0x1;
      res.RA = (packet[3] & 0x80) >>> 7;
      res.Z = (packet[3] & 0x70) >>> 4;
      res.RCODE = packet[3] & 0xf;
      res.QDCOUNT = packet.slice(4, 6);
      res.ANCOUNT = packet.slice(6, 8);
      res.NSCOUNT = packet.slice(8, 10);
      res.ARCOUNT = packet.slice(10, 12);
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
        }).toLowerCase());
        pos += len + 1;
        len = packet[pos];
        nb++;
      }
      res.QUESTION = {
        NAME: name,
        TYPE: getType(packet.slice(pos + 1, +(pos + 2) + 1 || 9e9)),
        CLASS: getClass(packet.slice(pos + 3, +(pos + 4) + 1 || 9e9)),
        raw: packet.slice(12, +(pos + 4) + 1 || 9e9)
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

  makeUDP = function(parsed, redirect) {
    var flags;
    flags = new bitconcat;
    flags.append(1, 1);
    flags.append(parsed.OPCODE, 4);
    flags.append(1, 1);
    flags.append(0, 1);
    flags.append(parsed.RD, 1);
    flags.append(1, 1);
    flags.append(0, 1);
    flags.append(0, 1);
    flags.append(0, 1);
    flags.append(redirect.RCODE, 4);
    return new Buffer(Array.prototype.concat.call(parsed.ID.toArray(), flags.getData(), [0, 1], redirect.ANCOUNT, redirect.NSCOUNT, redirect.ARCOUNT, parsed.QUESTION.raw.toArray(), redirect.ANSWER));
  };

  getAnswer = function(parsed) {
    var domain, _ref;
    domain = parsed.QUESTION.NAME.slice(-2).join(".");
    con(domain, parsed.QUESTION.CLASS, parsed.QUESTION.TYPE);
    if ((((_ref = redirects[domain]) != null ? _ref[parsed.QUESTION.TYPE] : void 0) != null) && parsed.QUESTION.CLASS === "IN") {
      return makeUDP(parsed, redirects[domain][parsed.QUESTION.TYPE]);
    } else {
      return null;
    }
  };

  module.exports = {
    parseUDP: parseUDP,
    makeUDP: makeUDP,
    getAnswer: getAnswer,
    SERVERFAILURE: SERVERFAILURE,
    NAMEERROR: NAMEERROR
  };

}).call(this);
