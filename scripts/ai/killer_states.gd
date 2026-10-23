class_name KillerStates
extends RefCounted
## Killer FSM states (spec section 7).

enum State { PREPARE, PATROL, CHASE, LAST_SEEN, INVESTIGATE, SEARCH, ATTACK }


static func name_of(s: int) -> String:
	return State.keys()[s]
