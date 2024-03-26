; creates a set of moves that may be used and returns its address in hl
; unused slots are filled with 0, all used slots may be chosen with equal probability
AIEnemyTrainerChooseMoves:
	ld a, 10
	ld hl, wBuffer ; init temporary move selection array. Only the moves with the lowest numbers are chosen in the end
	ld [hli], a   ; move 1
	ld [hli], a   ; move 2
	ld [hli], a   ; move 3
	ld [hl], a    ; move 4
	ld a, [wEnemyDisabledMove] ; forbid disabled move (if any)
	swap a
	and $f
	jr z, .noMoveDisabled
	ld hl, wBuffer
	dec a
	ld c, a
	ld b, $0
	add hl, bc    ; advance pointer to forbidden move
	ld [hl], 50  ; forbid (highly discourage) disabled move
.noMoveDisabled
	ld hl, TrainerClassMoveChoiceModifications
	ld a, [wTrainerClass]
	ld b, a
.loopTrainerClasses
	dec b
	jr z, .readTrainerClassData
.loopTrainerClassData
	ld a, [hli]
	and a
	jr nz, .loopTrainerClassData
	jr .loopTrainerClasses
.readTrainerClassData
	ld a, [hl]
	and a
	jp z, .useOriginalMoveSet
	push hl
.nextMoveChoiceModification
	pop hl
	ld a, [hli]
	and a
	jr z, .loopFindMinimumEntries
	push hl
	ld hl, AIMoveChoiceModificationFunctionPointers
	dec a
	add a
	ld c, a
	ld b, 0
	add hl, bc    ; skip to pointer
	ld a, [hli]   ; read pointer into hl
	ld h, [hl]
	ld l, a
	ld de, .nextMoveChoiceModification  ; set return address
	push de
	jp hl         ; execute modification function
.loopFindMinimumEntries ; all entries will be decremented sequentially until one of them is zero
	ld hl, wBuffer  ; temp move selection array
	ld de, wEnemyMonMoves  ; enemy moves
	ld c, NUM_MOVES
	ld b, $ff						; store minimum value at b
.loopDecrementEntries
	ld a, [de]
	inc de
	and a
	jr z, .alreadyLess				; end of wEnemyMonMoves array
	ld a, [hl]
	cp b 							; a - b
	jr nc, .alreadyLess				; if a >= b check next entry
	ld b, a 						; if a <  b store new min
.alreadyLess
	inc hl
	dec c
	jr nz, .loopDecrementEntries	; loop moves
.minimumEntriesFound				; b has the minimum value
	ld hl, wBuffer  ; temp move selection array
	ld de, wEnemyMonMoves  ; enemy moves
	ld c, NUM_MOVES
.filterMinimalEntries
	ld a, [de]
	and a
	jr nz, .moveExisting
	ld [hl], a
.moveExisting
	ld a, [hl]
	cp b
	jr z, .slotWithMinimalValue
	xor a
	ld [hli], a     ; disable move slot
	jr .next
.slotWithMinimalValue
	ld a, [de]
	ld [hli], a     ; enable move slot
.next
	inc de
	dec c
	jr nz, .filterMinimalEntries
	ld hl, wBuffer    ; use created temporary array as move set
	ret
.useOriginalMoveSet
	ld hl, wEnemyMonMoves    ; use original move set
	ret

AIMoveChoiceModificationFunctionPointers:
	dw AIMoveChoiceModification1
	dw AIMoveChoiceModification2
	dw AIMoveChoiceModification3
	dw AIMoveChoiceModification4 ; unused, does nothing

; discourages moves that cause no damage but only a status ailment if player's mon already has one
AIMoveChoiceModification1:
	ld a, [wBattleMonStatus]
	and a
	ret z ; return if no status ailment on player's mon
	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
	ld de, wEnemyMonMoves ; enemy moves
	ld b, NUM_MOVES + 1
.nextMove
	dec b
	ret z ; processed all 4 moves
	inc hl
	ld a, [de]
	and a
	ret z ; no more moves in move set
	inc de
	call ReadMove
	ld a, [wEnemyMovePower]
	and a
	jr nz, .nextMove
	ld a, [wEnemyMoveEffect]
	push hl
	push de
	push bc
	ld hl, StatusAilmentMoveEffects
	ld de, 1
	call IsInArray
	pop bc
	pop de
	pop hl
	jr nc, .nextMove
	ld a, [hl]
	add $5 ; heavily discourage move
	ld [hl], a
	jr .nextMove

StatusAilmentMoveEffects:
	db EFFECT_01 ; unused sleep effect
	db SLEEP_EFFECT
	db POISON_EFFECT
	db PARALYZE_EFFECT
	db -1 ; end

; slightly encourage moves with specific effects.
; in particular, stat-modifying moves and other move effects
; that fall in-between
AIMoveChoiceModification2:
	ret
;	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
;	ld de, wEnemyMonMoves ; enemy moves
;	ld b, NUM_MOVES + 1
;.nextMove
;	dec b
;	ret z ; processed all 4 moves
;	inc hl
;	ld a, [de]
;	and a
;	ret z ; no more moves in move set
;	inc de
;	call ReadMove
;	ld a, [wEnemyMoveEffect]
;	cp ATTACK_UP1_EFFECT
;	jr z, .nextMove
;	cp BIDE_EFFECT
;	jr z, .preferMove
;	cp ATTACK_UP2_EFFECT
;	jr z, .nextMove
;	cp POISON_EFFECT
;	jr z, .preferMove
;	cp PARALYZE_EFFECT
;	jr z, .preferMove2
;	cp SLEEP_EFFECT
;	jr z, .preferMove2
;; Confusion is last since it needs somewhat special handling
;	cp CONFUSION_EFFECT
;	jr nz, .nextMove
;	ld a, [wPlayerBattleStatus1]
;	bit 7, a
;	jr z, .preferMove2
;	inc [hl] ; slightly discourage this move
;	jr .nextMove
;.preferMove
;	dec [hl] ; slightly encourage this move
;	jr .nextMove
;.preferMove2
;	dec [hl] ; encourage this move
;	dec [hl] ; encourage this move
;	jr .nextMove

; encourages moves that are effective against the player's mon (even if non-damaging).
; discourage damaging moves that are ineffective or not very effective against the player's mon,
; unless there's no damaging move that deals at least neutral damage
AIMoveChoiceModification3:
	ret
;	ld hl, wBuffer - 1 ; temp move selection array (-1 byte offset)
;	ld de, wEnemyMonMoves ; enemy moves
;	ld b, NUM_MOVES + 1
;.nextMove
;	dec b
;	ret z ; processed all 4 moves
;	inc hl
;	ld a, [de]
;	and a
;	ret z ; no more moves in move set
;	inc de
;	call ReadMove
;	push hl
;	push bc
;	push de
;	callfar AIGetTypeEffectiveness
;	pop de
;	pop bc
;	pop hl
;; Discourage healing moves if at full HP	
;	ld a, [wEnemyMoveEffect]
;	cp HEAL_EFFECT
;	jr nz, .notHealing
;	push bc
;	push de
;; Division by 3
;	xor a
;	ldh [hDividend], a
;	ldh [hDividend + 1], a
;	ld a, [wEnemyMonMaxHP]
;	ldh [hDividend + 2], a
;	ld a, [wEnemyMonMaxHP + 1]
;	ldh [hDividend + 3], a
;	ld a, 3
;	ldh [hDivisor], a
;	ld b, 4
;	call Divide
;; Compare results
;	ld a, [wEnemyMonHP]
;	ld d, a
;	ld a, [wEnemyMonHP + 1]
;	ld e, a
;	ldh a, [hQuotient + 2]
;	cp d
;	jr c, .discourageMove			; current HP is more than 1/3 of total
;	jr nz, .encourageMove			; current HP is less than 1/3 of total
;	ldh a, [hQuotient + 3]
;	cp e
;	jr c, .discourageMove			; current HP is more than 1/3 of total
;.encourageMove
;	pop de
;	pop bc
;	dec [hl] 						; encourage this move
;	dec [hl] 						; encourage this move
;	dec [hl] 						; encourage this move
;	dec [hl] 						; encourage this move
;	jr .nextMove
;.discourageMove
;	pop de
;	pop bc
;	ld a, [hl]
;	add $4 ; heavily discourage move
;	ld [hl], a
;	jr .notEffectiveMove
;.notHealing
;	ld a, [wTypeEffectiveness]
;	cp 10
;	jr z, .nextMove
;	jr c, .notEffectiveMove
;	dec [hl] ; slightly encourage this move
;	cp 20
;	jr nz, .nextMove
;;	dec [hl] ; encourage more if super effective
;	jr .nextMove
;.notEffectiveMove
;	inc [hl] ; slightly discourage this move
;	jp .nextMove

MACRO OPP_MOV_DMG      
	wPrinterTileBuffer
ENDM
MACRO OPP_MOV_CAT      
	wPrinterTileBuffer + 8
ENDM
MACRO OPP_MOV_DMG_SETS 
	wPrinterTileBuffer + 12
ENDM
MACRO OPP_MOV_DMG_BEST 
	wPrinterTileBuffer + 43
ENDM
MACRO OUR_HEALTH 		 
	wPrinterTileBuffer + 47
ENDM
MACRO OUR_TURNS 		 
	wPrinterTileBuffer + 51
ENDM
MACRO OUR_MOV_DMG     
	wPrinterTileBuffer + 55
ENDM
MACRO OUR_MOV_CAT     
	wPrinterTileBuffer + 63
ENDM
MACRO OUR_MOV_DMG_SETS
	wPrinterTileBuffer + 67
ENDM
MACRO OUR_MOV_DMG_BEST
	wPrinterTileBuffer + 99
ENDM
MACRO OPP_TURNS 		
	wPrinterTileBuffer + 103
ENDM

AIMoveChoiceModification4:
;-------------------------------------------------------------------------------
; Note: Assumes we can freely use all registers
;
; wPrinterTileBuffer usage:
; bytes [  0:  7] 	opponet move avg dmg
; bytes [  8: 11]  	opponent move categories
; bytes [ 12: 43]  	opponent move dmg sets for stat changing moves
; bytes [ 43: 46]   best opponent move dmg for each set from above
; bytes [ 47: 50]   our health after healing/recoil/explode moves
; bytes [ 51: 54]   our remaining turns
;
; bytes [ 55: 62]   our move avg dmg
; bytes [ 63: 66]   our move categories
; bytes [ 67: 98]  	our move dmg sets for stat changing moves
; bytes [ 99:102]   our best move dmg for each set from above
; bytes [103:106]   opponent remaining turns
;
; wBuffer usage:
; bytes [ 0: 3] 	final move score (lower is better)
; bytes [23:29]     temp register storage
;
;-------------------------------------------------------------------------------
; Function summary:
; - Calc opponent move avg dmg 								( 8 bytes)
; - Store opponent move category 							( 4 bytes)
; - Update opponent move dmg for our stat changing moves 	(32 bytes)
; - Pick max for each set from above						( 8 bytes)
; - Store our health after each healing/recoil/explode move	( 8 bytes)
; - Calc our remaining turns based on stored health 		( 4 bytes)
;
; - Calc our move avg dmg 									( 8 bytes)
; - Store each move category 								( 4 bytes)
; - Update our move dmg for our stat changing moves  		(32 bytes)
; - Pick max for each set from above						( 8 bytes)
; - Calc opponent remaining turns 							( 4 bytes)
;
; - For each healing, stat changing & status inducing move dec our remaining turns
; - For PRZ, SLP, FRZ, update our remaining turns
; - If WE are PRZ, SLP, FRZ, update opponent turns
; - Update turns for fly/dig/clamp/wrap
;
; - Compute final score as (opponent remaining moves) - (remaining moves)
;--------------------------------------------------
; Calculate score
;--------------------------------------------------
	; TODO: Handle super fang & psybeam
	; ld a, [wEnemyMoveEffect]
	; TODO: Handle counter
	; TODO: Handle bide
	; TODO: Handle clamp/wrap
	; TODO: Handle multiple attacks (eg. double kick)
	; TODO: Handle charging moves + fly/dig
	; TODO: Handle recoil moves
	; TODO: Handle self-destruct/explosion

	; TODO: Handle healing moves
	; TODO: Handle non-volatile status
	; TODO: Handle volatile status
	; TODO: Handle stat changes

;--------------------------------------------------
; End Calculate Score
;--------------------------------------------------
;-----------------------------
; Store hWhoseTurn on stack and set to AI
	ldh a, [hWhoseTurn]
	push af
	ld a, 1
	ldh [hWhoseTurn], a
;-----------------------------
	ld de, wEnemyMonMoves
	ld hl, CalculateDamageAI
	call ForEachMoveInDECallHL
	ld de, wEnemyMonMoves
	ld hl, CalculateRemainingRoundsAI
	call ForEachMoveInDECallHL
;-----------------------------
; Restore hWhoseTurn
	pop af
	ldh [hWhoseTurn], a
;-----------------------------
	ret

ForEachMoveInDECallHL:
	ld c, -1
	ld b, 0
.next
	inc c
	ld a, c
	cp NUM_MOVES
	ret z ; processed all 4 moves
	ld a, [de]
	and a
	ret z ; no more moves in move set
	call ReadMove
	inc de
	call StoreRegisters
	ld hl, .retPoint
	push hl
	call LoadRegisters
	jp hl
.retPoint
	jp .next



;--------------------------------------------------
; Calculate Damage for AI purposes
; Inputs: 
;	a, [de]: the move id
;   c: move index
; Outputs: 
;	wDamage
;--------------------------------------------------
CalculateDamageAI:
	call StoreRegisters
;-----------------------------
; Base dmg calculation
	ld a, c
	ld [wEnemySelectedMove], a
; Base dmg - no crit
	ld a, 0
	ld [wCriticalHitOrOHKO], a
	call GetDamageVarsForEnemyAttackAlt
	call CalculateDamageAlt
	callfar AdjustDamageForMoveType
	call LoadRegisters
	call WDamageWeightFactor
; Store dmg on stack temporarily
	ld a, [wDamage]
	ld b, a
	ld a, [wDamage + 1]
	ld c, a
	push bc
; Compute critical hit dmg as well
	ld a, 1
	ld [wCriticalHitOrOHKO], a
	call LoadRegisters
	call GetDamageVarsForEnemyAttackAlt
	call CalculateDamageAlt
	callfar AdjustDamageForMoveType
	call LoadRegisters
; Update dmg accounting for crit rate
	call WDamageWeightFactor
; Compute weighted sum
; - weighted base dmg is on stack
; - weighted crit dmg is on wDamage
	ld a, [wDamage]
	ld b, a
	ld a, [wDamage + 1]
	ld c, a
	pop hl 		; hl: weighted base dmg
	add hl, bc
; Store back to wDamage
	ld a, h
	ld [wDamage], a
	ld a, l
	ld [wDamage + 1], a
;-----------------------------
; Correct for avg damage
; multiply by 236
	xor a
	ldh [hMultiplicand], a
	ld a, [wDamage]
	ldh [hMultiplicand + 1], a
	ld a, [wDamage + 1]
	ldh [hMultiplicand + 2], a
	ld a, 236
	ldh [hMultiplier], a
	call Multiply
; divide by 255
	ld a, 255
	ldh [hDivisor], a
	ld b, 4
	call Divide
;-----------------------------
; Correct for move accuracy wEnemyMoveAccuracy
	ld a, [wEnemyMoveAccuracy]
	ldh [hMultiplier], a
	call Multiply
	ld a, 255
	ldh [hDivisor], a
	ld b, 4
	call Divide
;-----------------------------
; Store to wBuffer + 2 * bc, wBuffer + 2 * bc + 1
	call LoadRegisters
	ld hl, wBuffer
	sla c
	add hl, bc
	ldh a, [hQuotient + 2]
	ld [hli], a
	ldh a, [hQuotient + 3]
	ld [hl], a
	call LoadRegisters
	ret

;--------------------------------------------------
; Update wDamage accounting for crit rate
; Inputs: 
;	the move id on stack
;   wCriticalHitOrOHKO
;	wDamage
; Outputs:
;   [if high crit move and computing crit]
;	wDamage = wDamage * speed / 64
;   [if non-high crit move and computing crit]
;	wDamage = wDamage * speed / 512
;   [if high crit move and computing normal hit]
;	wDamage = wDamage * (512 - speed) / 64
;   [if non-high crit move and computing normal hit]
;	wDamage = wDamage * (512 - speed) / 512
;--------------------------------------------------
WDamageWeightFactor:
; Account for crit rate
	ld a, [wEnemyMonSpecies]
	ld [wd0b5], a
	callfar GetMonHeader
; Move from wDamage to hMultiplicand
	xor a
	ldh [hMultiplicand], a
	ld a, [wDamage]
	ldh [hMultiplicand + 1], a
	ld a, [wDamage + 1]
	ldh [hMultiplicand + 2], a
; crit dmg = wDamage * speed / 512
; which will happen in steps
; aka 
	ld a, [wCriticalHitOrOHKO]
	and a
	jr z, .notCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	jr .goOn
.notCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	cpl 					; 255 - a
.goOn
	ldh [hMultiplier], a
	call Multiply
; divide by 512 (or by 64 if it's a high crit move)
	ld a, [wEnemyMoveNum]
	cp KARATE_CHOP
	jr z, .highCrit
	cp RAZOR_LEAF
	jr z, .highCrit
	cp CRABHAMMER
	jr z, .highCrit
	cp SLASH
	jr z, .highCrit
	ld a, 255 				; should be 256, but it's ok
	jr .noHighCrit
.highCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	cp 32
	jr c, .stdDivisor
; if crit
	ld a, [wCriticalHitOrOHKO]
	and a
	jr z, .notCritForHighCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	jr .noHighCrit
; if no crit
.notCritForHighCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	cpl
	jr .noHighCrit
.stdDivisor
	ld a, 32
.noHighCrit
; Divide by 255 or 32
	ldh [hDivisor], a
	ld b, 4
	call Divide
; Move result back to wDamage
	ldh a, [hQuotient + 2]
	ld [wDamage], a
	ldh a, [hQuotient + 3]
	ld [wDamage + 1], a
	ret

;--------------------------------------------------
; Compute Opponnent Remaining Rounds
; Inputs:
; 	wBuffer + 2 * bc, wBuffer + 2 * bc + 1 (Damage)
; Output:
; 	a = min(ceil(wBattleMonHP / wDamage), 127)
;--------------------------------------------------
CalculateRemainingRoundsAI:
	push bc
	push de
	push hl
; Store from wBuffer to wDamage
	ld hl, wBuffer
	sla c
	add hl, bc
	ld a, [hli]
	ld [wDamage], a
	ld a, [hli]
	ld [wDamage + 1], a
; If wDamage == 0 skip to .clamp
	ld a, [wDamage]
	ld b, a
	ld a, [wDamage + 1]
	or b
	jr z, .clamp
; Now we can compute remaining rounds
	ld a, [wDamage]
	and a
; If wDamage <= 255 do a division
; If wDamage > 255 it's faster to just substract
	jr nz, .justDoLoopedSubstraction
; Read opponent HP
	xor a
	ldh [hDividend], a
	ldh [hDividend + 1], a
	ld a, [wBattleMonHP]
	ldh [hDividend + 2], a
	ld a, [wBattleMonHP + 1]
	ldh [hDividend + 3], a
; Read move dmg	
	ld a, [wDamage + 1]
	ldh [hDivisor], a
	ld b, 4
	call Divide
; Result on bc
	ldh a, [hQuotient + 2]
	ld b, a
	ldh a, [hQuotient + 3]
	ld c, a
; Does ceil modify results after division?
	ld a, [hRemainder]
	and a
	jr z, .shouldClamp
	inc bc
	jr .shouldClamp
.justDoLoopedSubstraction
; Note: This works because the quotient fits in a single byte (h)
;	  	when DMG > 255 (max HP is <= 2 ** 16 - 1, practically less than 1000)
; Load HP -> de, DMG -> bc, quotient in h
	ld a, [wBattleMonHP]
	ld d, a
	ld a, [wBattleMonHP + 1]
	ld e, a
	ld a, [wDamage]
	ld b, a
	ld a, [wDamage + 1]
	ld c, a
	ld h, 0
.loop
; Loop until de < bc
; Note: will overestimate ceil(wBattleMonHP / wDamage)
;       when bc divides de exactly, but we'll live with it
;       it's too much effort to do this right for an heuristic score
;		which depends on a badly written RNG
	inc h
	ld a, e
	sub c
	ld e, a
	ld a, d
	sbc b
	ld d, a
	jr c, .subDone
	jr .loop
.subDone
	ld b, 0
	ld c, h
.shouldClamp
	ld a, b
	and a
	jr nz, .clamp
	ld a, c
	cp 127					  ; Clamp at 127
	jr c, .noClamp
.clamp
	ld a, 127
.noClamp
	pop hl
	pop de
	pop bc
	push bc
	push de
	push hl
;-----------------------------
; Store to wBuffer + bc
	ld hl, wBuffer
	add hl, bc
	ld [hl], a
;-----------------------------
; Pop and ret
	pop hl
	pop de
	pop bc
	ret
;--------------------------------------------------
; End Compute Opponnent Remaining Rounds
;--------------------------------------------------

;--------------------------------------------------
; The stack is almomst full, but we also need to store
; variables somewhere temporarily :(
StoreRegisters:
	ld [wBuffer + 29], a
	ld a, b
	ld [wBuffer + 28], a
	ld a, c
	ld [wBuffer + 27], a
	ld a, d
	ld [wBuffer + 26], a
	ld a, e
	ld [wBuffer + 25], a
	ld a, h
	ld [wBuffer + 24], a
	ld a, l
	ld [wBuffer + 23], a
	ret

LoadRegisters:
	ld a, [wBuffer + 23]
	ld l, a
	ld a, [wBuffer + 24]
	ld h, a
	ld a, [wBuffer + 25]
	ld e, a
	ld a, [wBuffer + 26]
	ld d, a
	ld a, [wBuffer + 27]
	ld c, a
	ld a, [wBuffer + 28]
	ld b, a
	ld a, [wBuffer + 29]
	ret

; sets b, c, d, and e for the CalculateDamage routine in the case of an attack by the enemy mon
GetDamageVarsForEnemyAttackAlt:
	ld hl, wDamage ; damage to eventually inflict, initialise to zero
	xor a
	ld [hli], a
	ld [hl], a
	ld hl, wEnemyMovePower
	ld a, [hli]
	ld d, a ; d = move power
	and a
	ret z ; return if move power is zero
	ld a, [hl] ; a = [wEnemyMoveType]
	cp SPECIAL ; types >= SPECIAL are all special
	jr nc, .specialAttack
.physicalAttack
	ld hl, wBattleMonDefense
	ld a, [hli]
	ld b, a
	ld c, [hl] ; bc = player defense
	ld a, [wPlayerBattleStatus3]
	bit HAS_REFLECT_UP, a ; check for Reflect
	jr z, .physicalAttackCritCheck
; if the player has used Reflect, double the player's defense
	sla c
	rl b
.physicalAttackCritCheck
	ld hl, wEnemyMonAttack
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .scaleStats
; in the case of a critical hit, reset the player's defense and the enemy's attack to their base values
	ld hl, wPartyMon1Defense
	ld a, [wPlayerMonNumber]
	ld bc, wPartyMon2 - wPartyMon1
	call AddNTimes
	ld a, [hli]
	ld b, a
	ld c, [hl]
	push bc
	ld c, STAT_ATTACK
	callfar GetEnemyMonStat
	ld hl, hProduct + 2
	pop bc
	jr .scaleStats
.specialAttack
	ld hl, wBattleMonSpecial
	ld a, [hli]
	ld b, a
	ld c, [hl]
	ld a, [wPlayerBattleStatus3]
	bit HAS_LIGHT_SCREEN_UP, a ; check for Light Screen
	jr z, .specialAttackCritCheck
; if the player has used Light Screen, double the player's special
	sla c
	rl b
; reflect and light screen boosts do not cap the stat at MAX_STAT_VALUE, so weird things will happen during stats scaling
; if a Pokemon with 512 or more Defense has used Reflect, or if a Pokemon with 512 or more Special has used Light Screen
.specialAttackCritCheck
	ld hl, wEnemyMonSpecial
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .scaleStats
; in the case of a critical hit, reset the player's and enemy's specials to their base values
	ld hl, wPartyMon1Special
	ld a, [wPlayerMonNumber]
	ld bc, wPartyMon2 - wPartyMon1
	call AddNTimes
	ld a, [hli]
	ld b, a
	ld c, [hl]
	push bc
	ld c, STAT_SPECIAL
	callfar GetEnemyMonStat
	ld hl, hProduct + 2
	pop bc
; if either the offensive or defensive stat is too large to store in a byte, scale both stats by dividing them by 4
; this allows values with up to 10 bits (values up to 1023) to be handled
; anything larger will wrap around
.scaleStats
	ld a, [hli]
	ld l, [hl]
	ld h, a ; hl = enemy's offensive stat
	or b ; is either high byte nonzero?
	jr z, .next ; if not, we don't need to scale
; bc /= 4 (scale player's defensive stat)
	srl b
	rr c
	srl b
	rr c
; defensive stat can actually end up as 0, leading to a division by 0 freeze during damage calculation
; hl /= 4 (scale enemy's offensive stat)
	srl h
	rr l
	srl h
	rr l
	ld a, l
	or h ; is the enemy's offensive stat 0?
	jr nz, .next
	inc l ; if the enemy's offensive stat is 0, bump it up to 1
.next
	ld b, l ; b = enemy's offensive stat (possibly scaled)
	        ; (c already contains player's defensive stat (possibly scaled))
	ld a, [wEnemyMonLevel]
	ld e, a
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .done
	sla e ; double level if it was a critical hit
.done
	ld a, $1
	and a
	and a
	ret

; sets b, c, d, and e for the CalculateDamage routine in the case of an attack by the player mon
GetDamageVarsForPlayerAttackAlt:
	xor a
	ld hl, wDamage ; damage to eventually inflict, initialise to zero
	ldi [hl], a
	ld [hl], a
	ld hl, wPlayerMovePower
	ld a, [hli]
	and a
	ld d, a ; d = move power
	ret z ; return if move power is zero
	ld a, [hl] ; a = [wPlayerMoveType]
	cp SPECIAL ; types >= SPECIAL are all special
	jr nc, .specialAttack
.physicalAttack
	ld hl, wEnemyMonDefense
	ld a, [hli]
	ld b, a
	ld c, [hl] ; bc = enemy defense
	ld a, [wEnemyBattleStatus3]
	bit HAS_REFLECT_UP, a ; check for Reflect
	jr z, .physicalAttackCritCheck
; if the enemy has used Reflect, double the enemy's defense
	sla c
	rl b
.physicalAttackCritCheck
	ld hl, wBattleMonAttack
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .scaleStats
; in the case of a critical hit, reset the player's attack and the enemy's defense to their base values
	ld c, STAT_DEFENSE
	call GetEnemyMonStat
	ldh a, [hProduct + 2]
	ld b, a
	ldh a, [hProduct + 3]
	ld c, a
	push bc
	ld hl, wPartyMon1Attack
	ld a, [wPlayerMonNumber]
	ld bc, wPartyMon2 - wPartyMon1
	call AddNTimes
	pop bc
	jr .scaleStats
.specialAttack
	ld hl, wEnemyMonSpecial
	ld a, [hli]
	ld b, a
	ld c, [hl] ; bc = enemy special
	ld a, [wEnemyBattleStatus3]
	bit HAS_LIGHT_SCREEN_UP, a ; check for Light Screen
	jr z, .specialAttackCritCheck
; if the enemy has used Light Screen, double the enemy's special
	sla c
	rl b
; reflect and light screen boosts do not cap the stat at MAX_STAT_VALUE, so weird things will happen during stats scaling
; if a Pokemon with 512 or more Defense has used Reflect, or if a Pokemon with 512 or more Special has used Light Screen
.specialAttackCritCheck
	ld hl, wBattleMonSpecial
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .scaleStats
; in the case of a critical hit, reset the player's and enemy's specials to their base values
	ld c, STAT_SPECIAL
	call GetEnemyMonStat
	ldh a, [hProduct + 2]
	ld b, a
	ldh a, [hProduct + 3]
	ld c, a
	push bc
	ld hl, wPartyMon1Special
	ld a, [wPlayerMonNumber]
	ld bc, wPartyMon2 - wPartyMon1
	call AddNTimes
	pop bc
; if either the offensive or defensive stat is too large to store in a byte, scale both stats by dividing them by 4
; this allows values with up to 10 bits (values up to 1023) to be handled
; anything larger will wrap around
.scaleStats
	ld a, [hli]
	ld l, [hl]
	ld h, a ; hl = player's offensive stat
	or b ; is either high byte nonzero?
	jr z, .next ; if not, we don't need to scale
; bc /= 4 (scale enemy's defensive stat)
	srl b
	rr c
	srl b
	rr c
; defensive stat can actually end up as 0, leading to a division by 0 freeze during damage calculation
; hl /= 4 (scale player's offensive stat)
	srl h
	rr l
	srl h
	rr l
	ld a, l
	or h ; is the player's offensive stat 0?
	jr nz, .next
	inc l ; if the player's offensive stat is 0, bump it up to 1
.next
	ld b, l ; b = player's offensive stat (possibly scaled)
	        ; (c already contains enemy's defensive stat (possibly scaled))
	ld a, [wBattleMonLevel]
	ld e, a ; e = level
	ld a, [wCriticalHitOrOHKO]
	and a ; check for critical hit
	jr z, .done
	sla e ; double level if it was a critical hit
.done
	ld a, 1
	and a
	ret

CalculateDamageAlt:
; input:
;   b: attack
;   c: opponent defense
;   d: base power
;   e: level

	ldh a, [hWhoseTurn] ; whose turn?
	and a
	ld a, [wPlayerMoveEffect]
	jr z, .effect
	ld a, [wEnemyMoveEffect]
.effect

; EXPLODE_EFFECT halves defense.
	cp EXPLODE_EFFECT
	jr nz, .ok
	srl c
	jr nz, .ok
	inc c ; ...with a minimum value of 1 (used as a divisor later on)
.ok

; Multi-hit attacks may or may not have 0 bp.
	cp TWO_TO_FIVE_ATTACKS_EFFECT
	jr z, .skipbp
	cp $1e
	jr z, .skipbp

; Calculate OHKO damage based on remaining HP.
	cp OHKO_EFFECT
	jp z, JumpToOHKOMoveEffect

; Don't calculate damage for moves that don't do any.
	ld a, d ; base power
	and a
	ret z
.skipbp

	xor a
	ld hl, hDividend
	ldi [hl], a
	ldi [hl], a
	ld [hl], a

; Multiply level by 2
	ld a, e ; level
	add a
	jr nc, .nc
	push af
	ld a, 1
	ld [hl], a
	pop af
.nc
	inc hl
	ldi [hl], a

; Divide by 5
	ld a, 5
	ldd [hl], a
	push bc
	ld b, 4
	call Divide
	pop bc

; Add 2
	inc [hl]
	inc [hl]

	inc hl ; multiplier

; Multiply by attack base power
	ld [hl], d
	call Multiply

; Multiply by attack stat
	ld [hl], b
	call Multiply

; Divide by defender's defense stat
	ld [hl], c
	ld b, 4
	call Divide

; Divide by 50
	ld [hl], 50
	ld b, 4
	call Divide

; Update wCurDamage.
; Capped at MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE: 999 - 2 = 997.
	ld hl, wDamage
	ld b, [hl]
	ldh a, [hQuotient + 3]
	add b
	ldh [hQuotient + 3], a
	jr nc, .dont_cap_1

	ldh a, [hQuotient + 2]
	inc a
	ldh [hQuotient + 2], a
	and a
	jr z, .cap

.dont_cap_1
	ldh a, [hQuotient]
	ld b, a
	ldh a, [hQuotient + 1]
	or a
	jr nz, .cap

	ldh a, [hQuotient + 2]
	cp HIGH(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1)
	jr c, .dont_cap_2

	cp HIGH(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) + 1
	jr nc, .cap

	ldh a, [hQuotient + 3]
	cp LOW(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1)
	jr nc, .cap

.dont_cap_2
	inc hl

	ldh a, [hQuotient + 3]
	ld b, [hl]
	add b
	ld [hld], a

	ldh a, [hQuotient + 2]
	ld b, [hl]
	adc b
	ld [hl], a
	jr c, .cap

	ld a, [hl]
	cp HIGH(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1)
	jr c, .dont_cap_3

	cp HIGH(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) + 1
	jr nc, .cap

	inc hl
	ld a, [hld]
	cp LOW(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1)
	jr c, .dont_cap_3

.cap
	ld a, HIGH(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE)
	ld [hli], a
	ld a, LOW(MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE)
	ld [hld], a

.dont_cap_3
; Add back MIN_NEUTRAL_DAMAGE (capping at 999).
	inc hl
	ld a, [hl]
	add MIN_NEUTRAL_DAMAGE
	ld [hld], a
	jr nc, .dont_floor
	inc [hl]
.dont_floor

; Returns nz and nc.
	ld a, 1
	and a
	ret

ReadMove:
	push hl
	push de
	push bc
	dec a
	ld hl, Moves
	ld bc, MOVE_LENGTH
	call AddNTimes
	ld de, wEnemyMoveNum
	call CopyData
	pop bc
	pop de
	pop hl
	ret

INCLUDE "data/trainers/move_choices.asm"

INCLUDE "data/trainers/pic_pointers_money.asm"

INCLUDE "data/trainers/names.asm"

INCLUDE "engine/battle/misc.asm"

INCLUDE "engine/battle/read_trainer_party.asm"

INCLUDE "data/trainers/special_moves.asm"

INCLUDE "data/trainers/parties.asm"

TrainerAI:
	ld a, [wIsInBattle]
	dec a
	jr z, .done ; if not a trainer, we're done here
	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	jr z, .done ; if in a link battle, we're done as well
	ld a, [wEnemyBattleStatus1]
	and 1 << CHARGING_UP | 1 << THRASHING_ABOUT | 1 << STORING_ENERGY
	jr nz, .done ; don't follow trainer ai if opponent is in a locked state
	ld a, [wEnemyBattleStatus2]
	and 1 << USING_RAGE
	jr nz, .done ; don't follow trainer ai if opponent is locked in rage
	             ; note that this doesn't check for hyper beam recharge which can cause problems
	ld a, [wTrainerClass] ; what trainer class is this?
	dec a
	ld c, a
	ld b, 0
	ld hl, TrainerAIPointers
	add hl, bc
	add hl, bc
	add hl, bc
	ld a, [wAICount]
	and a
	jr z, .done ; if no AI uses left, we're done here
	inc hl
	inc a
	jr nz, .getpointer
	dec hl
	ld a, [hli]
	ld [wAICount], a
.getpointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
	call Random
	jp hl 		; run TrainerAIPointers?
.done
	and a
	ret

INCLUDE "data/trainers/ai_pointers.asm"

JugglerAI:
	cp 25 percent + 1
	ret nc
	jp AISwitchIfEnoughMons

BlackbeltAI:
	cp 13 percent - 1
	ret nc
	jp AIUseXAttack

GiovanniAI:
	cp 25 percent + 1
	ret nc
	jp AIUseGuardSpec

CooltrainerMAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXAttack

CooltrainerFAI:
	; The intended 25% chance to consider switching will not apply.
	; Uncomment the line below to fix this.
	cp 25 percent + 1
	; ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	jp c, AIUseHyperPotion
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AISwitchIfEnoughMons

BrockAI:
; if his active monster has a status condition, use a full heal
	ld a, [wEnemyMonStatus]
	and a
	ret z
	jp AIUseFullHeal

MistyAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXDefend

LtSurgeAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXSpeed

ErikaAI:
	cp 50 percent + 1
	ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

KogaAI:
	cp 13 percent - 1
	ret nc
	jp AIUseXAttack

BlaineAI:
	cp 25 percent + 1
	ret nc
	ld a, 10
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

SabrinaAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXDefend

Rival2AI:
	cp 13 percent - 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUsePotion

Rival3AI:
	cp 13 percent - 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseFullRestore

LoreleiAI:
	cp 50 percent + 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

BrunoAI:
	cp 25 percent + 1
	ret nc
	jp AIUseXDefend

AgathaAI:
	cp 8 percent
	jp c, AISwitchIfEnoughMons
	cp 50 percent + 1
	ret nc
	ld a, 4
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseSuperPotion

LanceAI:
	cp 50 percent + 1
	ret nc
	ld a, 5
	call AICheckIfHPBelowFraction
	ret nc
	jp AIUseHyperPotion

GenericAI:
	and a ; clear carry
	ret

; end of individual trainer AI routines

DecrementAICount:
	ld hl, wAICount
	dec [hl]
	scf
	ret

AIPlayRestoringSFX:
	ld a, SFX_HEAL_AILMENT
	jp PlaySoundWaitForCurrent

AIUseFullRestore:
	call AICureStatus
	ld a, FULL_RESTORE
	ld [wAIItem], a
	ld de, wHPBarOldHP
	ld hl, wEnemyMonHP + 1
	ld a, [hld]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a
	inc de
	ld hl, wEnemyMonMaxHP + 1
	ld a, [hld]
	ld [de], a
	inc de
	ld [wHPBarMaxHP], a
	ld [wEnemyMonHP + 1], a
	ld a, [hl]
	ld [de], a
	ld [wHPBarMaxHP+1], a
	ld [wEnemyMonHP], a
	jr AIPrintItemUseAndUpdateHPBar

AIUsePotion:
; enemy trainer heals his monster with a potion
	ld a, POTION
	ld b, 20
	jr AIRecoverHP

AIUseSuperPotion:
; enemy trainer heals his monster with a super potion
	ld a, SUPER_POTION
	ld b, 50
	jr AIRecoverHP

AIUseHyperPotion:
; enemy trainer heals his monster with a hyper potion
	ld a, HYPER_POTION
	ld b, 200
	; fallthrough

AIRecoverHP:
; heal b HP and print "trainer used $(a) on pokemon!"
	ld [wAIItem], a
	ld hl, wEnemyMonHP + 1
	ld a, [hl]
	ld [wHPBarOldHP], a
	add b
	ld [hld], a
	ld [wHPBarNewHP], a
	ld a, [hl]
	ld [wHPBarOldHP+1], a
	ld [wHPBarNewHP+1], a
	jr nc, .next
	inc a
	ld [hl], a
	ld [wHPBarNewHP+1], a
.next
	inc hl
	ld a, [hld]
	ld b, a
	ld de, wEnemyMonMaxHP + 1
	ld a, [de]
	dec de
	ld [wHPBarMaxHP], a
	sub b
	ld a, [hli]
	ld b, a
	ld a, [de]
	ld [wHPBarMaxHP+1], a
	sbc b
	jr nc, AIPrintItemUseAndUpdateHPBar
	inc de
	ld a, [de]
	dec de
	ld [hld], a
	ld [wHPBarNewHP], a
	ld a, [de]
	ld [hl], a
	ld [wHPBarNewHP+1], a
	; fallthrough

AIPrintItemUseAndUpdateHPBar:
	call AIPrintItemUse_
	hlcoord 2, 2
	xor a
	ld [wHPBarType], a
	predef UpdateHPBar2
	jp DecrementAICount

AISwitchIfEnoughMons:
; enemy trainer switches if there are 2 or more unfainted mons in party
	ld a, [wEnemyPartyCount]
	ld c, a
	ld hl, wEnemyMon1HP

	ld d, 0 ; keep count of unfainted monsters

	; count how many monsters haven't fainted yet
.loop
	ld a, [hli]
	ld b, a
	ld a, [hld]
	or b
	jr z, .Fainted ; has monster fainted?
	inc d
.Fainted
	push bc
	ld bc, wEnemyMon2 - wEnemyMon1
	add hl, bc
	pop bc
	dec c
	jr nz, .loop

	ld a, d ; how many available monsters are there?
	cp 2    ; don't bother if only 1
	jp nc, SwitchEnemyMon
	and a
	ret

SwitchEnemyMon:

; prepare to withdraw the active monster: copy hp, number, and status to roster

	ld a, [wEnemyMonPartyPos]
	ld hl, wEnemyMon1HP
	ld bc, wEnemyMon2 - wEnemyMon1
	call AddNTimes
	ld d, h
	ld e, l
	ld hl, wEnemyMonHP
	ld bc, 4
	call CopyData

	ld hl, AIBattleWithdrawText
	call PrintText

	; This wFirstMonsNotOutYet variable is abused to prevent the player from
	; switching in a new mon in response to this switch.
	ld a, 1
	ld [wFirstMonsNotOutYet], a
	callfar EnemySendOut
	xor a
	ld [wFirstMonsNotOutYet], a

	ld a, [wLinkState]
	cp LINK_STATE_BATTLING
	ret z
	scf
	ret

AIBattleWithdrawText:
	text_far _AIBattleWithdrawText
	text_end

AIUseFullHeal:
	call AIPlayRestoringSFX
	call AICureStatus
	ld a, FULL_HEAL
	jp AIPrintItemUse

AICureStatus:
; cures the status of enemy's active pokemon
	ld a, [wEnemyMonPartyPos]
	ld hl, wEnemyMon1Status
	ld bc, wEnemyMon2 - wEnemyMon1
	call AddNTimes
	xor a
	ld [hl], a ; clear status in enemy team roster
	ld [wEnemyMonStatus], a ; clear status of active enemy
	ld hl, wEnemyBattleStatus3
	res 0, [hl]
	ret

AIUseXAccuracy: ; unused
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set 0, [hl]
	ld a, X_ACCURACY
	jp AIPrintItemUse

AIUseGuardSpec:
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set 1, [hl]
	ld a, GUARD_SPEC
	jp AIPrintItemUse

AIUseDireHit: ; unused
	call AIPlayRestoringSFX
	ld hl, wEnemyBattleStatus2
	set 2, [hl]
	ld a, DIRE_HIT
	jp AIPrintItemUse

AICheckIfHPBelowFraction:
; return carry if enemy trainer's current HP is below 1 / a of the maximum
	ldh [hDivisor], a
	ld hl, wEnemyMonMaxHP
	ld a, [hli]
	ldh [hDividend], a
	ld a, [hl]
	ldh [hDividend + 1], a
	ld b, 2
	call Divide
	ldh a, [hQuotient + 3]
	ld c, a
	ldh a, [hQuotient + 2]
	ld b, a
	ld hl, wEnemyMonHP + 1
	ld a, [hld]
	ld e, a
	ld a, [hl]
	ld d, a
	ld a, d
	sub b
	ret nz
	ld a, e
	sub c
	ret

AIUseXAttack:
	ld b, $A
	ld a, X_ATTACK
	jr AIIncreaseStat

AIUseXDefend:
	ld b, $B
	ld a, X_DEFEND
	jr AIIncreaseStat

AIUseXSpeed:
	ld b, $C
	ld a, X_SPEED
	jr AIIncreaseStat

AIUseXSpecial:
	ld b, $D
	ld a, X_SPECIAL
	; fallthrough

AIIncreaseStat:
	ld [wAIItem], a
	push bc
	call AIPrintItemUse_
	pop bc
	ld hl, wEnemyMoveEffect
	ld a, [hld]
	push af
	ld a, [hl]
	push af
	push hl
	ld a, XSTATITEM_DUPLICATE_ANIM
	ld [hli], a
	ld [hl], b
	callfar StatModifierUpEffect
	pop hl
	pop af
	ld [hli], a
	pop af
	ld [hl], a
	jp DecrementAICount

AIPrintItemUse:
	ld [wAIItem], a
	call AIPrintItemUse_
	jp DecrementAICount

AIPrintItemUse_:
; print "x used [wAIItem] on z!"
	ld a, [wAIItem]
	ld [wd11e], a
	call GetItemName
	ld hl, AIBattleUseItemText
	jp PrintText

AIBattleUseItemText:
	text_far _AIBattleUseItemText
	text_end
