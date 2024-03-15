; Boolean checks
DEF FALSE EQU 0
DEF TRUE  EQU 1

; flag operations
	const_def
	const FLAG_RESET ; 0
	const FLAG_SET   ; 1
	const FLAG_TEST  ; 2

; wOptions
DEF TEXT_DELAY_FAST   EQU %000 ; 0
DEF TEXT_DELAY_MEDIUM EQU %001 ; 1
DEF TEXT_DELAY_SLOW   EQU %011 ; 3

	const_def 6
	const BIT_GAME_SPEED       ; 6
	const BIT_BATTLE_ANIMATION ; 7

; wd732 flags
DEF BIT_DEBUG_MODE EQU 1
