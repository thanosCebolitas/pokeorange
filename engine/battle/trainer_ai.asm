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
	ld a, [wEnemyMoveEffect]
	cp ATTACK_UP1_EFFECT
	jr z, .nextMove
	cp BIDE_EFFECT
	jr z, .preferMove
	cp ATTACK_UP2_EFFECT
	jr z, .nextMove
	cp POISON_EFFECT
	jr z, .preferMove
	cp PARALYZE_EFFECT
	jr z, .preferMove2
	cp SLEEP_EFFECT
	jr z, .preferMove2
; Confusion is last since it needs somewhat special handling
	cp CONFUSION_EFFECT
	jr nz, .nextMove
	ld a, [wPlayerBattleStatus1]
	bit 7, a
	jr z, .preferMove2
	inc [hl] ; slightly discourage this move
	jr .nextMove
.preferMove
	dec [hl] ; slightly encourage this move
	jr .nextMove
.preferMove2
	dec [hl] ; encourage this move
	dec [hl] ; encourage this move
	jr .nextMove

; encourages moves that are effective against the player's mon (even if non-damaging).
; discourage damaging moves that are ineffective or not very effective against the player's mon,
; unless there's no damaging move that deals at least neutral damage
AIMoveChoiceModification3:
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
	push hl
	push bc
	push de
	callfar AIGetTypeEffectiveness
	pop de
	pop bc
	pop hl
; Discourage healing moves if at full HP	
	ld a, [wEnemyMoveEffect]
	cp HEAL_EFFECT
	jr nz, .notHealing
	push bc
	push de
; Division by 3
	xor a
	ldh [hDividend], a
	ldh [hDividend + 1], a
	ld a, [wEnemyMonMaxHP]
	ldh [hDividend + 2], a
	ld a, [wEnemyMonMaxHP + 1]
	ldh [hDividend + 3], a
	ld a, 3
	ldh [hDivisor], a
	ld b, 4
	call Divide
; Compare results
	ld a, [wEnemyMonHP]
	ld d, a
	ld a, [wEnemyMonHP + 1]
	ld e, a
	ldh a, [hQuotient + 2]
	cp d
	jr c, .discourageMove			; current HP is more than 1/3 of total
	jr nz, .encourageMove			; current HP is less than 1/3 of total
	ldh a, [hQuotient + 3]
	cp e
	jr c, .discourageMove			; current HP is more than 1/3 of total
.encourageMove
	pop de
	pop bc
	dec [hl] 						; encourage this move
	dec [hl] 						; encourage this move
	dec [hl] 						; encourage this move
	dec [hl] 						; encourage this move
	jr .nextMove
.discourageMove
	pop de
	pop bc
	ld a, [hl]
	add $4 ; heavily discourage move
	ld [hl], a
	jr .notEffectiveMove
.notHealing
	ld a, [wTypeEffectiveness]
	cp 10
	jr z, .nextMove
	jr c, .notEffectiveMove
	dec [hl] ; slightly encourage this move
	cp 20
	jr nz, .nextMove
;	dec [hl] ; encourage more if super effective
	jr .nextMove
.notEffectiveMove
	inc [hl] ; slightly discourage this move
	jp .nextMove

AIMoveChoiceModification4:
;-------------------------------------------------------------------------------
; Note: Assumes we can freely use all registers
;
; wBuffer usage:
; bytes [ 0: 3] 	final move score (lower is better)
; byte       4  	opponent best move max dmg
; byte       5   	opponent best move category
; bytes [ 6:13]  	our move avg dmg
; bytes [14:21]  	opponent best move dmg as modified by our moveset
; bytes [22:25]     remaining moves
; bytes [26:29]     opponent remaining moves
;
; Function summary:
; - Loop 1:
; 	- Compute & store opponent best move max dmg & category
; - Loop 2:
; 	- Compute & store our moves avg dmg
; - Loop 3:
; 	- Compute opponent modified best move dmg (ie apply volatile statuses)
; 	- Update our moves avg dmg to account for volatile statuses
; - Loop 4:
; 	- Compute remaining moves
; 	- Compute opponent remaining moves
; - Loop 5:
; 	- Update remaining moves to account for healing, paralyze, sleep & confusion
; 	- Update opponent remaining moves to account for confusion
; - Loop 6:
; 	- Compute final score as (opponent remaining moves) - (remaining moves)
;-------------------------------------------------------------------------------
	ld de, wEnemyMonMoves ; enemy moves
	ld c, -1
	ld b, 0
.nextMove
	inc c
	ld a, c
	cp NUM_MOVES
	ret z ; processed all 4 moves
	ld a, [de]
	and a
	ret z ; no more moves in move set
	call ReadMove
	inc de
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

	call CalculateDamageAI
	call CalculateRemainingRoundsAI

; Store Score
	ld [hl], a
;--------------------------------------------------
; End Calculate Score
;--------------------------------------------------
	jp .nextMove


;--------------------------------------------------
; Calculate Damage for AI purposes
; Inputs: 
;	d, the move id
; Outputs: 
;	wDamage
;--------------------------------------------------
CalculateDamageAI:
;-----------------------------
; Push registers to stack
	push bc
	push de
	push hl
;-----------------------------
; Store hWhoseTurn on stack and set to AI
	ldh a, [hWhoseTurn]
	push af
	ld a, 1
	ldh [hWhoseTurn], a
;-----------------------------
; Base dmg calculation
	ld a, b
	ld [wEnemySelectedMove], a
; Base dmg - no crit
	ld a, 0
	ld [wCriticalHitOrOHKO], a
	callfar GetDamageVarsForEnemyAttack
	callfar CalculateDamage
	callfar AdjustDamageForMoveType
	; CAREFULL WITH THAT AXE EUGENE
	ld hl, SP +2 ; pushed de on stack ie. enemy move id
	push hl
	call WDamageWeightFactor
; Reset registers; might not be needed
	pop af
	pop hl
	pop de
	pop bc
	push bc
	push de
	push hl
	push af
; Store dmg on stack temporarily
	ld a, [wDamage]
	ld b, a
	ld a, [wDamage + 1]
	ld c, a
	push bc
; Compute critical hit dmg as well
	ld a, 1
	ld [wCriticalHitOrOHKO], a
	callfar GetDamageVarsForEnemyAttack
	callfar CalculateDamage
	callfar AdjustDamageForMoveType
; Update dmg accounting for crit rate
; CAREFULL WITH THAT AXE EUGENE
	ld hl, SP +4 ; pushed de on stack ie. enemy move id
	push hl
	call WDamageWeightFactor
; Compute weighted sum
; - weighted base dmg is on stack
; - weighted crit dmg is on wDamage
	ld a, [wDamage]
	ld d, a
	ld a, [wDamage + 1]
	ld e, a
	pop hl 		; hl: weighted base dmg
	add hl, de
; Store back to wDamage
	ld a, h
	ld [wDamage], a
	ld a, l
	ld [wDamage + 1], a
;-----------------------------
; Restore hWhoseTurn
	pop af
	ldh [hWhoseTurn], a
;-----------------------------
; Correct for minimum damage
; AI doesn't like taking risks : )
; multiply by 217
	xor a
	ldh [hMultiplicand], a
	ld a, [wDamage]
	ldh [hMultiplicand + 1], a
	ld a, [wDamage + 1]
	ldh [hMultiplicand + 2], a
	ld a, 217
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
; divide by 100
	ld a, 100
	ldh [hDivisor], a
	ld b, 4
	call Divide
;-----------------------------
; Pop and push
	pop hl
	pop de
	pop bc
	push bc
	push de
	push hl
;-----------------------------
; Store to wBuffer + 2 * bc, wBuffer + 2 * bc + 1
	ld hl, wBuffer
	sla c
	add hl, bc
	ldh a, [hQuotient + 2]
	ld [hli], a
	ldh a, [hQuotient + 3]
	ld [hl], a
;-----------------------------
; Pop and ret
	pop hl
	pop de
	pop bc
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
	jr nz, .notCrit
	ld a, [wMonHBaseSpeed]
	srl a 					; speed / 2
	jr .goOn
.notCrit
	cpl 					; 255 - a
.goOn
	ldh [hMultiplier], a
	call Multiply
; divide by 512 (or by 64 if it's a high crit move)
; CAREFULL WITH THAT AXE EUGENE
	pop hl
	ld a, l
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
;-----------------------------
; Pop and push
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
