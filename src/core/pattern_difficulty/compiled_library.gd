## The compiled chunk library: per-tier superset pools (RAMP includes INTRO, FULL includes all).
## Built by `ChunkLibraryCompiler.compile`, resident for the session, never written to afterwards.
class_name CompiledLibrary
extends RefCounted

var _pools: Array[Array] = [[], [], []]


## Adds `chunk` to its own tier pool and every higher tier pool (compile time only).
func add(chunk: CompiledChunk) -> void:
	for t: int in range(chunk.tier, ChunkDef.Tier.FULL + 1):
		_pools[t].append(chunk)


## The pool of `tier` in authoring order.
func pool(tier: ChunkDef.Tier) -> Array[CompiledChunk]:
	var out: Array[CompiledChunk] = []
	out.assign(_pools[tier])
	return out


## Number of chunks in the pool of `tier`.
func pool_size(tier: ChunkDef.Tier) -> int:
	return _pools[tier].size()
