CinnabarLabMetronomeRoom_Script:
	jp EnableAutoTextBoxDrawing

CinnabarLabMetronomeRoom_TextPointers:
	def_text_pointers
	dw_const CinnabarLabMetronomeRoomScientist1Text, TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1
	dw_const CinnabarLabMetronomeRoomScientist2Text, TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST2
	dw_const CinnabarLabMetronomeRoomPCText,         TEXT_CINNABARLABMETRONOMEROOM_PC_KEYBOARD
	dw_const CinnabarLabMetronomeRoomPCText,         TEXT_CINNABARLABMETRONOMEROOM_PC_MONITOR
	dw_const CinnabarLabMetronomeRoomAmberPipeText,  TEXT_CINNABARLABMETRONOMEROOM_AMBER_PIPE

CinnabarLabMetronomeRoomScientist1Text:
	text_asm
	CheckEvent EVENT_GOT_TM35
	jr nz, .got_item
	ld hl, .Text
	call PrintText
	lb bc, TM_METRONOME, 1
	call GiveItem
	jr nc, .bag_full
	ld hl, .ReceivedTM35Text
	call PrintText
	SetEvent EVENT_GOT_TM35
	jr .done
.bag_full
	ld hl, .TM35NoRoomText
	call PrintText
	jr .done
.got_item
	ld hl, .TM35ExplanationText
	call PrintText
.done
	jp TextScriptEnd

.Text:
	text_far _CinnabarLabMetronomeRoomScientist1Text
	text_end

.ReceivedTM35Text:
	text_far _CinnabarLabMetronomeRoomScientist1ReceivedTM35Text
	sound_get_item_1
	text_end

.TM35ExplanationText:
	text_far _CinnabarLabMetronomeRoomScientist1TM35ExplanationText
	text_end

.TM35NoRoomText:
	text_far _CinnabarLabMetronomeRoomScientist1TM35NoRoomText
	text_end

CinnabarLabMetronomeRoomScientist2Text:
	text_asm
	call SaveScreenTilesToBuffer2
	ld hl, .Text
	call PrintText
	call YesNoChoice
	ld a, [wCurrentMenuItem]
	and a
	jp nz, .nothingToDo
;
; Check if player has enough money
;
	xor a
	ldh [hMoney + 1], a
	ldh [hMoney + 2], a
	ld a, $30
	ldh [hMoney], a
	call HasEnoughMoney
	jr nc, .enoughMoney
	ld hl, .TextNotEnoughMoney
	call PrintText
	jp .done
;
; Open party menu
;
.enoughMoney
	xor a
	ld [wPartyMenuTypeOrMessageID], a
	ld [wUpdateSpritesEnabled], a
	ld [wMenuItemToSwap], a
	call DisplayPartyMenu
; Restore screen
	push af
	call GBPalWhiteOutWithDelay3
	call RestoreScreenTilesAndReloadTilePatterns
	call LoadGBPal
	pop af
;
; Check selection and apply changes
;
	jr c, .nothingToDo
	ld hl, .TextTreatment
	call PrintText
	ld hl, wPartyMon1DVs
	ld bc, wPartyMon2 - wPartyMon1
	ld a, [wWhichPokemon]
	call AddNTimes
; Check if perfect already
	push hl
	push bc
	ld a, $ff
	cp [hl]
	jr nz, .continue
	inc hl
	cp [hl]
.continue
	pop bc
	pop hl
	jr z, .perfectPokemon
; Set DVs to max
    ldi [hl], a
    ld [hl], a
; Recalculate stats
	xor a
	ld [wMonDataLocation], a
	call LoadMonData
	farcall CalcLevelFromExperience
	ld a, d
	ld [wCurEnemyLVL], a
	ld hl, wPartyMon1MaxHP
	ld bc, wPartyMon2 - wPartyMon1
	ld a, [wWhichPokemon]
	call AddNTimes
	ld d, h
	ld e, l
	ld hl, wPartyMon1HPExp - 1
	ld a, [wWhichPokemon]
	call AddNTimes
	ld b, $1
	call CalcStats
; Remove money
	call SubtractAmountPaidFromMoney
	ld hl, .TextCompleted
	call PrintText
	jr .done
.perfectPokemon
	ld hl, .TextPerfect
	call PrintText
	jr .done
.nothingToDo
	ld hl, .TextNotCompleted
	call PrintText
.done
	jp TextScriptEnd
.Text
	text_far _CinnabarLabMetronomeRoomScientist2Text
	text_end
.TextTreatment
	text_far _CinnabarLabMetronomeRoomScientist2TextTreatment
	text_end
.TextCompleted
	text_far _CinnabarLabMetronomeRoomScientist2EnhancedText
	text_end
.TextNotEnoughMoney
	text_far _CinnabarLabMetronomeRoomScientist2NotEnoughMoneyText
	text_end
.TextNotCompleted
	text_far _CinnabarLabMetronomeRoomScientist2NotEnhancedText
	text_end
.TextPerfect
	text_far _CinnabarLabMetronomeRoomScientist2PerfectText
	text_end

CinnabarLabMetronomeRoomPCText:
	text_far _CinnabarLabMetronomeRoomPCText
	text_end

CinnabarLabMetronomeRoomAmberPipeText:
	text_far _CinnabarLabMetronomeRoomAmberPipeText
	text_end
