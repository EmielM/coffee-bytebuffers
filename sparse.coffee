###
Sparse data buffer

Allows efficient storage of arrays of which some ranges are still
unset. Usable as playback buffer for streaming audio or video.

Pretty complete implementation, allowing efficient overwrites or
updates. Fetching data should preferably be done on the offsets
of the backed store (using ::firstOffset and ::get).

Transparent to the type of data stored in the buffer.

(C) Emiel Mols, 2010. Released under the Simplified BSD License.
    Attribution is very much appreciated.
###
class SparseBuffer
	
	constructor: ->
		@buffers = []
	
	bisect: (offset, lower, upper) ->
		# bisects to the buffer that currently contains byte offset,
		# or the buffer following if the byte is not contained (is sparse)

		return lower if lower >= upper
		
		mid = Math.floor((lower+upper)/2)
		if offset >= @buffers[mid].offset + @buffers[mid].buf.length
			@bisect(offset, mid+1, upper)
		else
			@bisect(offset, lower, mid)
	
	firstOffset: -> @buffers[0].offset
	
	get: (offset) ->
		idx = @bisect(offset, 0, @buffers.length)
		b = @buffers[idx]
		if not b or b.offset > offset
			return []
		else if offset-b.offset > 0
			console.debug "SparseBuf: misalignment, preferably to be prevented"
			return b.buf.slice(offset-b.offset)
		else
			# alignment! we like
			return b.buf
		
	set: (offset, buf) ->
		idx = @bisect(offset, 0, @buffers.length)
		
		prev = @buffers[idx]
		if prev and prev.offset < offset
			idx++
			if prev.offset + prev.buf.length > offset + buf.length
				# split buffer situation (should not happen often)
				@buffers.splice idx, 0, {offset: offset+buf.length, buf: prev.buf.slice(offset-prev.offset+buf.length)}
			
			prev.buf.splice offset-prev.offset, prev.buf.length-(offset-prev.offset)
		
		removeFollowing = 0
		while lookAt = @buffers[idx+removeFollowing]
			if lookAt.offset + lookAt.buf.length > offset+buf.length
				# lookAt is not to be removed
				if lookAt.offset < offset+buf.length
					# but is to be adjusted
					lookAt.buf.splice 0, buf.length-(lookAt.offset-offset)
					lookAt.offset = offset+buf.length
				break
			removeFollowing++
		
		@buffers.splice idx, removeFollowing, {offset: offset, buf: buf}
		return
	
	available: (offset) ->
		offset = 0 if not offset?
		available = 0
		idx = @bisect(offset, 0, @buffers.length)
		return 0 if not @buffers[idx] or @buffers[idx].offset > offset
		
		available -= offset - @buffers[idx].offset
		offset = @buffers[idx].offset
		
		while @buffers[idx] and @buffers[idx].offset == offset
			len = @buffers[idx].buf.length
			offset += len
			available += len
			idx++
		return available
