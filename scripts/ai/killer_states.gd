class_name KillerStates
extends RefCounted
## Killer behaviour states (spec v2.0, section 6.3). Door opening and window
## vaulting are motor actions and are shown in debug as OPEN_DOOR / VAULT.

enum State {
	PREPARE,
	PATROL,
	TRAVEL_TO_POI,
	SWEEP_INTERIOR,
	CHECK_HIDING_SPOT,
	INVESTIGATE_SOUND,
	CHASE,
	GO_TO_LAST_SEEN,
	LOCAL_SEARCH,
	ATTACK,
	FINISH,
	RETURN_TO_PATROL,
}


static func name_of(s: int) -> String:
	return State.keys()[s]
