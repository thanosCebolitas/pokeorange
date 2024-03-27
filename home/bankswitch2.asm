BankswitchCommon::
	ldh [hLoadedROMBank], a
	ld [MBC1RomBank], a
	ret

Bankswitch::
; self-contained bankswitch, use this when not in the home bank
; switches to the bank in b
	ldh a, [hLoadedROMBank]
	push af
	ld a, b
	ldh [hLoadedROMBank], a
	ld [MBC1RomBank], a
	call JumpToAddress
	pop bc
	ld a, b
	ldh [hLoadedROMBank], a
	ld [MBC1RomBank], a
	ret
JumpToAddress::
	jp hl

Bankswitch2::
; self-contained bankswitch, use this when not in the home bank
; switches to the bank in b
	ldh a, [hLoadedROMBank]
	push af
	ld a, b
	ldh [hLoadedROMBank], a
	ld [MBC1RomBank], a
	call JumpToAddress2
	; store bc to sp + 2
	ld hl, sp + 4
	ld [hl], c
	inc hl
	ld [hl], b
	pop bc
	ld a, b
	ldh [hLoadedROMBank], a
	ld [MBC1RomBank], a
	ret
JumpToAddress2::
	push hl
	; read from sp + 2 to bc
	ld hl, sp + 8
	ld c, [hl]
	inc hl
	ld b, [hl]
	pop hl
	jp hl

SwitchSRAMBankAndLatchClockData::
	push af
	ld a, $1
	ld [MBC1SRamBankingMode], a
	ld a, SRAM_ENABLE
	ld [MBC1SRamEnable], a
	pop af
	ld [MBC1SRamBank], a
	ret

PrepareRTCDataAndDisableSRAM::
	push af
	ld a, $0
	ld [MBC1SRamBankingMode], a
	ld [MBC1SRamEnable], a
	pop af
	ret
