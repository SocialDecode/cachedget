fs = require "fs"
IsJsonString = (str)->
	try
		JSON.parse(str)
	catch e
		return false;
	return true

module.exports = (requestobj)->
	requestobj.cachedget = (args...)->
		if args?[0]?.method?.toLowerCase() is "get"
			newargs = JSON.parse(JSON.stringify(args[0]))
			newargs.method ="HEAD"
			requestobj newargs,(e,r,b)->
				return requestobj(args...) if e? or !r?.statusCode is 200
				#console.log "cachedo META last-modified:#{r.headers["last-modified"]} content-length:#{r.headers["content-length"]} etag:#{r.headers.etag}"
				newargs["last-modified"] = r.headers["last-modified"]
				newargs["content-length"] = r.headers["content-length"]
				newargs["etag"] = r.headers.etag.replace(/\"/g,"") if r.headers.etag?
				filepath = require('os').tmpdir()+require('crypto').createHash('md5').update(JSON.stringify(newargs)).digest("hex")
				noCache = ->
					#CACHE MISS
					console.log "cachedo MISS"
					#get it and generate cache
					requestobj args[0], (e2,r2,b2)->
						if e2? or !r2?.statusCode is 200
							args[1](e2,r2,b2)
						else
							#delete both files ... just in case
							fs.unlink filepath, ->
								fs.unlink filepath+"_response.json", ->
									ws1 = fs.createWriteStream(filepath)
									ws1.write b2
									ws1.end()
									ws1.on 'finish', ->
										ws2 = fs.createWriteStream(filepath+"_response.json")
										ws2.write JSON.stringify(r2)
										ws2.end()
										args[1](e2,r2,b2)
				fs.exists filepath, (e1)->
					return noCache() if !e1
					fs.exists filepath+"_response.json", (e2)->
						return noCache() if !e2
						#return cache copy
						fs.readFile filepath, 'utf8', (err, contents)->
							if err? or !contents?
								#CACHE ERR
								console.log "cachedo ERR"
								#can't read .. lets delete
								return noCache()
							else
								fs.readFile filepath+"_response.json", (err2,contents2)->
									if !err2? and IsJsonString(contents2)
										#CACHE HIT
										console.log "cachedo HIT"
										args[1] null,JSON.parse(contents2), contents
									else
										#CACHE ERR
										console.log "cachedo ERR"
										return noCache()


		else
			return requestobj(args...)
	return requestobj