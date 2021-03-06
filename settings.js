module.exports = {
	"redisDB" : 0,
	//"IPv4" : [176, 58, 120, 112],
	//"IPv6" : [0x2a,0x01, 0x7e,0x00, 0,0,0,0, 0xf0,0x3c, 0x91,0xff, 0xfe,0xae, 0xe9,0x6e],
	"IPv4" : [192,168,1,101],
	"IPv6" : [0,0,0,0,0,0,0,0,255,255,255,255,0,0,0,1],
	"forwardDNS": "127.0.0.1",
	"forwardDNSport": 53530,
	"httpPort" : 80,
	"httpsPort" : 443,

	"hostTunnelingEnabled": false,
	"internalHostTunnelPort" : 15001,
	"hostTunnelingCaching" : 1800,
	// "wildcardKey": "/home/don/REAL_SSL_WILDCARD/star_unblock_us_org.key",
	// "wildcardCert": "/home/don/REAL_SSL_WILDCARD/ssl/unblock.us.org.crt",
	"wildcardKey": "",
	"wildcardCert": "",
	"hostTunnelingDomain": "unblock.us.org",

	"hijacked" : {
		"youtube.com" : "youtube.com",
		"ggpht.com" : "ggpht.com",
		"ytimg.com" : "ggpht.com",
		"youtube-nocookie.com" : "youtube-nocookie.com",
		"youtu.be" : "youtu.be",

		"twimg.com" : "twimg.com",
		"twitter.com" : "twitter.com",
		"t.co" : "t.co"
	}
};
