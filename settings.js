module.exports = {
	"redisDB" : 0,
	//"IPv4" : [176, 58, 120, 112],
	//"IPv6" : [0x2a,0x01, 0x7e,0x00, 0,0,0,0, 0xf0,0x3c, 0x91,0xff, 0xfe,0xae, 0xe9,0x6e],
	"IPv4" : [192,168,1,101],
	"IPv6" : [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	"forwardDNS": "127.0.0.1",
	"forwardDNSPort": "53530",
	"httpPort" : 80,
	"httpsPort" : 443,
	"internalHostTunnelPort" : 15001,

	"wildcardKey": "./ssl/host.key",
	"wildcardCert": "./ssl/host.cert",

	"hijacked" : {
		"youtube.com" : "youtube.com",
		"ggpht.com" : "ggpht.com",
		"ytimg.com" : "ggpht.com",
		"youtube-nocookie.com" : "youtube-nocookie.com",
		"youtu.be" : "youtu.be",

		"twimg.com" : "twimg.com",
		"twitter.com" : "twimg.com",
		"t.co" : "t.co",

		"unblock.us.org": "unblock.us.org",
		"reddit.com" : "reddit.com",
		"redditmedia.com": "redditmedia.com",

		"failheap-challenge.com": "failheap-challenge.com"
	}
};
