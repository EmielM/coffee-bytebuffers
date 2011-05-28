###
Unsigned byte buffer implementation.

Includes push/grab methods for common data structures (short,
int, string), making the class suitable for simple packet
generation or parsing.

The current implementation uses a simple javascript array as
backend, containing only unsigned bytes. In the future, we
might want to experiment with other backends (e.g. native
Uint8Buffers or maybe even strings).

(C) Emiel Mols, 2010. Released under the Simplified BSD License.
    Attribution is very much appreciated.
###
class ByteBuffer
	
	constructor: (obj) ->
		if (obj instanceof Array)
			@array = obj
		else if (typeof obj == "number")
			@array = new Array(obj)
		else
			@array = new Array

	get: (offset) -> @array[offset]
	set: (offset, byt) -> @array[offset] = byt
			
	splice: -> new ByteBuffer(@array.splice.apply(@array, arguments))
	slice: -> new ByteBuffer(@array.slice.apply(@array, arguments))

	unshift: -> @array.unshift.apply(@array, arguments)

	push: -> @array.push.apply(@array, arguments)
	
	pushBuf: (bytes, pad) ->
		bytes = bytes.array if bytes.array?
		
		if pad? and bytes.length < pad
			padArray = new Array(bytes.length-pad)
			i = 0; padArray[i++] = 0x00 while i < bytes.length-pad
			@array.push.apply(@array, padArray)
		else if pad? and bytes.length > pad
			bytes.splice(0, bytes.length-pad)
		
		@array.push.apply(@array, bytes)
		return
			
	pushString: (string, encoding) ->
		i = 0
		beforeLen = @array.length
		if encoding is "binary"
			while i < string.length
				@array.push (string.charCodeAt(i++) & 0xff)
		else
			# utf8 per default
			while i < string.length
				chr = string.charCodeAt(i++)
				if chr < 128
					@array.push chr
				else if 128 <= chr < 2048
					@array.push (chr>>6)|192, (chr&63)|128
				else
					@array.push (chr>>12)|224, ((chr>>6)&63)|128, (chr&63)|128
		
		return @array.length - beforeLen
	
	pushShort: (shrt) ->
		@array.push (shrt & 0xff00) >> 8, (shrt & 0xff)
		
	pushInt: (integer) ->
		@array.push (integer >> 24) & 0xff,
			(integer >> 16) & 0xff,
			(integer >> 8) & 0xff,
			integer & 0xff
	
	setShort: (offset, shrt) ->
		@array[offset] = (shrt & 0xff00) >> 8
		@array[offset+1] = (shrt & 0xff)
		return
		
	setInt: (offset, integer) ->
		@array[offset] = (integer & 0xff000000) >> 24
		@array[offset+1] = (integer & 0xff0000) >> 16
		@array[offset+2] = (integer & 0xff00) >> 8
		@array[offset+3] = (integer & 0xff)
		return
		
	length: -> @array.length
	
	grabOffset: 0
	
	ungrabbed: -> @array.length - @grabOffset
	
	grab: ->
		return false if @grabOffset+1 > @array.length
		return @array[@grabOffset++]
	
	discard: (size) ->
		return false if @grabOffset+size > @array.length
		@grabOffset += size
		return true
		
	grabBuf: (size) ->
		size = @array.length - @grabOffset if not size? # allow fetching remainder
		return false if @grabOffset+size > @array.length
		
		b = new ByteBuffer(@array.slice(@grabOffset, @grabOffset+size))
		@grabOffset += size
		return b
		
	grabBufNPush: (toBuf, size, pad) ->
		size = @array.length - @grabOffset if not size? # allow fetching remainder
		return false if @grabOffset+size > @array.length
		
		# todo: I have a hunch this can be optimized in some way :)
		toBuf.pushBuf @array.slice(@grabOffset, @grabOffset+size), pad
		@grabOffset += size
		return true
	
	grabString: (size, encoding) ->
		size = @array.length - @grabOffset if not size? # allow fetching remainder
		return false if @grabOffset+size > @array.length
		
		str = ''
		i = @grabOffset
		
		if encoding is "binary"
			while i < @grabOffset+size
				str += String.fromCharCode(@array[i++]) 
		else
			# utf8 per default
			while i < @grabOffset+size
				chr = @array[i++]
				if 192 <= chr < 224
					chr = ((chr&31)<<6) | ((@array[i++]||0x00) & 63)
				else if chr >= 128
					chr = ((chr&15)<<12) | (((@array[i++]&63)||0x00)<<6) | ((@array[i++]|0x00)&63)
				str += String.fromCharCode(chr)
			
		@grabOffset += size
		return str
		
	grabShort: ->
		return false if @grabOffset+2 > @array.length
		
		s = (@array[@grabOffset] << 8) | @array[@grabOffset+1]
		@grabOffset += 2
		return s
		
	grabInt: ->
		return false if @grabOffset+4 > @array.length
		
		s = (@array[@grabOffset] << 32) | (@array[@grabOffset+1] << 16) |
			(@array[@grabOffset+2] << 8) | @array[@grabOffset+3]
		@grabOffset += 4
		return s
	
	toHex: -> (('0'+byt.toString(16)).slice(-2) for byt in @array).join('')
	
#stringToBytes = (string, encoding) ->
#	array = []
#	i = 0; array.push (string.charCodeAt(i++) & 0xff) while i < string.length
#	return array
	# only 'binary' charset for now
	
intToBytes = (integer) -> [
	(integer & 0xff000000) >> 24,
	(integer & 0xff0000) >> 16,
	(integer & 0xff00) >> 8,
	(integer & 0xff) ]

hexToBytes = (string) ->
	string = "0#{string}" if (string.length % 2) # pad left when uneven length
	parseInt(string.substring(i, i+2), 16) for i in [0...string.length] by 2

