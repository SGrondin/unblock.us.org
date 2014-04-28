bitconcat = require "bitconcat"
TYPES = require "../defs/types"
CLASSES = require "../defs/classes"
settings = require "../settings"

# http://tools.ietf.org/html/rfc1035
SERVERFAILURE = {
	RCODE	: 2
	ANCOUNT	: 0
	NSCOUNT	: 0
	ARCOUNT	: 0
	ANSWER	: []
}
NAMEERROR = {
	RCODE	: 3
	ANCOUNT	: 0
	NSCOUNT	: 0
	ARCOUNT	: 0
	ANSWER	: []
}
redirected_types = {"A", "AAAA"}
redirection = {
	"A" : {
		RCODE	: 0
		ANCOUNT : [0, 1]
		NSCOUNT : [0, 0]
		ARCOUNT : [0, 0]
		ANSWER  : [0xc0,0x0c, 0,1, 0,1,		# c0 0c A IN
			0, 0, 0, 4,						# TTL
			0, 4,].concat settings.IPv4		# IP
	}
	"AAAA" : {
		RCODE	: 0
		ANCOUNT : [0, 1]
		NSCOUNT : [0, 0]
		ARCOUNT : [0, 0]
		ANSWER  : [0xc0,0x0c, 0,0x1c, 0,1,	# c0 0c AAAA IN
			0, 0, 0, 4,						# TTL
			0, 16].concat settings.IPv6		# IP
	}
}

parse2Bytes = (buf) -> (buf[0] << 8) | buf[1]
parse3Bytes = (buf) -> (buf[0] << 16) | (buf[1] << 8) | buf[2]
make2Bytes = (i) -> [((i & 0xFF00) >>> 8), (i & 0xFF)]
prependLength = (buf) -> Buffer.concat [(new Buffer make2Bytes buf.length), buf]
getType = (buf) ->
	p = parse2Bytes buf
	if TYPES[p]? then TYPES[p] else "INVALID"
getClass = (buf) ->
	p = parse2Bytes buf
	if CLASSES[p]? then CLASSES[p] else "INVALID"

parseDNS = (packet) ->
	try
		if packet.length < 16 then throw new Error "Packet too short to be valid"
		res = {}
		res.ID      = packet[0..1]
		res.QR      = (packet[2] & 0x80) >>> 7 # 10000000
		res.OPCODE  = (packet[2] & 0x78) >>> 3 # 01111000
		res.AA      = (packet[2] & 0x4 ) >>> 2 # 00000100
		res.TC      = (packet[2] & 0x2 ) >>> 1 # 00000010
		res.RD      = (packet[2] & 0x1 )       # 00000001
		res.RA      = (packet[3] & 0x80) >>> 7 # 10000000
		res.Z       = (packet[3] & 0x70) >>> 4 # 01110000
		res.RCODE   = (packet[3] & 0xf )       # 00001111
		res.QDCOUNT = packet[4..5]
		res.ANCOUNT = packet[6..7]
		res.NSCOUNT = packet[8..9]
		res.ARCOUNT = packet[10..11]

		res.QUESTION = {}
		nb = 0
		pos = 12
		len = packet[pos]
		name = []
		while len != 0 and nb < 15
			name.push packet[(pos+1)..(pos+len)].toArray().map((a) -> String.fromCharCode a).reduce((a,b) -> a+b).toLowerCase()
			pos += len+1
			len = packet[pos]
			nb++
		res.QUESTION = {
			NAME	: name
			TYPE	: getType packet[(pos+1)..(pos+2)]
			# typeraw	: packet[(pos+1)..(pos+2)]
			CLASS	: getClass packet[(pos+3)..(pos+4)]
			# classraw: packet[(pos+3)..(pos+4)]
			raw		: packet[12..(pos+4)]
		}
		if not (res.QUESTION.NAME.length > 0 and res.QUESTION.CLASS.length == 2) then throw new Error "Invalid QUESTION.NAME"
		res
	catch err
		con err
		null

makeDNS = (parsed, redirect, isTCP) ->
	flags = new bitconcat
	flags.append 1,				1		# QR
	flags.append parsed.OPCODE,	4		# OPCODE
	flags.append 1,				1		# AA
	flags.append 0,				1		# TC
	flags.append parsed.RD,		1		# RD
	flags.append 1,				1		# RA
	flags.append 0,				1		# Z
	flags.append 0,				1		# AD
	flags.append 0,				1		# CD
	flags.append redirect.RCODE,4		# RCODE

	ret = Array::concat.call(
		parsed.ID.toArray(),			# ID
		flags.getData(),				# Flags
		[0, 1],							# QDCOUNT
		redirect.ANCOUNT,				# ANCOUNT
		redirect.NSCOUNT,				# NSCOUNT
		redirect.ARCOUNT,				# ARCOUNT
		parsed.QUESTION.raw.toArray()	# QUESTION
		redirect.ANSWER
	)
	if isTCP
		new Buffer make2Bytes(ret.length).concat ret
	else
		new Buffer ret

getAnswer = (parsed, isTCP) ->
	domain = parsed.QUESTION.NAME[-2..].join "." # Fails on .co.uk, will fix when the need arises

	if settings.hijacked[domain]? and redirected_types[parsed.QUESTION.TYPE]? and parsed.QUESTION.CLASS == "IN"
		makeDNS parsed, redirection[parsed.QUESTION.TYPE], isTCP
	else
		null

module.exports = {parse2Bytes, parse3Bytes, make2Bytes, prependLength, parseDNS, makeDNS, getAnswer, SERVERFAILURE, NAMEERROR}
