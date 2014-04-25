(function() {
  var CLASSES, NAMEERROR, SERVERFAILURE, TYPES, bitconcat, getAnswer, getClass, getType, hijackedDomain, make2Bytes, makeDNS, parse2Bytes, parse3Bytes, parseDNS, prependLength, redirected_types, redirection, settings;

  bitconcat = require("bitconcat");

  TYPES = require("../defs/types");

  CLASSES = require("../defs/classes");

  settings = require("../settings");

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

  redirected_types = {
    "A": "A",
    "AAAA": "AAAA"
  };

  redirection = {
    "A": {
      RCODE: 0,
      ANCOUNT: [0, 1],
      NSCOUNT: [0, 0],
      ARCOUNT: [0, 0],
      ANSWER: [0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 4, 0, 4].concat(settings.IPv4)
    },
    "AAAA": {
      RCODE: 0,
      ANCOUNT: [0, 1],
      NSCOUNT: [0, 0],
      ARCOUNT: [0, 0],
      ANSWER: [0xc0, 0x0c, 0, 0x1c, 0, 1, 0, 0, 0, 4, 0, 16].concat(settings.IPv6)
    }
  };

  parse2Bytes = function(buf) {
    return (buf[0] << 8) | buf[1];
  };

  parse3Bytes = function(buf) {
    return (buf[0] << 16) | (buf[1] << 8) | buf[2];
  };

  make2Bytes = function(i) {
    return [(i & 0xFF00) >>> 8, i & 0xFF];
  };

  prependLength = function(buf) {
    return Buffer.concat([new Buffer(make2Bytes(buf.length)), buf]);
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

  parseDNS = function(packet) {
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
      while (len !== 0 && nb++ < 15) {
        name.push(packet.slice(pos + 1, +(pos + len) + 1 || 9e9).toArray().map(function(a) {
          return String.fromCharCode(a);
        }).join("").toLowerCase());
        pos += len + 1;
        len = packet[pos];
      }
      res.QUESTION = {
        NAME: name,
        TYPE: getType(packet.slice(pos + 1, +(pos + 2) + 1 || 9e9)),
        CLASS: getClass(packet.slice(pos + 3, +(pos + 4) + 1 || 9e9)),
        raw: packet.slice(12, +(pos + 4) + 1 || 9e9)
      };
      if (!(res.QUESTION.NAME.length > 0 && res.QUESTION.CLASS.length === 2)) {
        throw new Error("Invalid QUESTION.NAME\n" + packet.toArray());
      }
      return res;
    } catch (_error) {
      err = _error;
      con(err);
      return null;
    }
  };

  makeDNS = function(parsed, redirect, isTCP) {
    var flags, ret;
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
    ret = Array.prototype.concat.call(parsed.ID.toArray(), flags.getData(), [0, 1], redirect.ANCOUNT, redirect.NSCOUNT, redirect.ARCOUNT, parsed.QUESTION.raw.toArray(), redirect.ANSWER);
    if (isTCP != null) {
      return new Buffer(make2Bytes(ret.length).concat(ret));
    } else {
      return new Buffer(ret);
    }
  };

  hijackedDomain = function(name) {
    if ((name.slice(-1)[0] != null) && name.slice(-1)[0] === "tunnel") {
      name.pop();
    }
    return settings.hijacked[name.slice(-2).join(".")] || settings.hijacked[name.slice(-3).join(".")] || null;
  };

  getAnswer = function(parsed, isTCP) {
    var domain;
    if (!((redirected_types[parsed.QUESTION.TYPE] != null) && parsed.QUESTION.CLASS === "IN")) {
      return null;
    }
    domain = hijackedDomain(parsed.QUESTION.NAME.slice(0));
    if (domain != null) {
      return makeDNS(parsed, redirection[parsed.QUESTION.TYPE], isTCP);
    } else {
      return null;
    }
  };

  module.exports = {
    parse2Bytes: parse2Bytes,
    parse3Bytes: parse3Bytes,
    make2Bytes: make2Bytes,
    prependLength: prependLength,
    parseDNS: parseDNS,
    makeDNS: makeDNS,
    hijackedDomain: hijackedDomain,
    getAnswer: getAnswer,
    SERVERFAILURE: SERVERFAILURE,
    NAMEERROR: NAMEERROR
  };

}).call(this);
