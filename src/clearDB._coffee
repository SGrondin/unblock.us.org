util = require "util"
settings = require "../settings.js"
global.con = -> console.log Array::concat(new Date().toISOString(), Array::slice.call(arguments, 0)).map((a)->util.inspect a).join " "
redis = require "redis"
redisClient = redis.createClient()
redisClient.select settings.redisDB, _

redisClient.flushdb _
redisClient.quit()
con "Done!"
