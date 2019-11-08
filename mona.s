; "Mona" SNES procgfx source code
; by Revenant / Resistance

; Based on an original Atari XL demo by Ilmenit.

.p816

; -----------------------------------------------------------------------------
.zeropage
part:      .res 2
direction: .res 2
length:    .res 2
seed:      .res 4
cursor:    .res 2
pixel:     .res 2

; -----------------------------------------------------------------------------
.code
code_start:

word_seeds: 
.incbin "DATA.BIN", 4

colors:
.byte $bf, $67, $15, $01

Main:
	clc
	xce

	; use DP as a pointer to B bus
	phd
	pea $2100
	pld

	; $2100: disable the display so we can start setting up VRAM
	dec z:$00
	
	; $2133: disable hires, interlace, etc
	stz z:$33

	; init mode 7 screen buffer here before re-enabling screen
	lda #$81
	sta z:$15
	; palette setup
	stz z:$16
	stz z:$17
	ldx #$03
:	lda colors,x
	sta z:$19
	stz z:$19
	dex
	bpl :-
	; restore normal VRAM increment settings
	stz z:$15

	; at this point X = FF
	; $210d: set mode 7 bg position
	stz z:$0d
	stz z:$0d
	stx z:$0e
	stx z:$0e
	
	; $211f-20: center mode 7 bg at (0,0)
	stz z:$1f
	stz z:$1f
	stz z:$20
	stz z:$20

	; $211a - normal screen rotation
	stz z:$1a
	; 211b-1e mode 7 matrix
	lda #$04
	stz z:$1b
	sta z:$1b
	stz z:$1c
	stz z:$1c
	stz z:$1d
	stz z:$1d
	stz z:$1e
	sta z:$1e
	
	; $212c: enable bg 1
	inc z:$2c

	; start using 16-bit writes from A now
	rep #$20
	.a16
	
	; $2130-31: disable color math but enable direct color
	inc z:$30
	
	; $2105: enable mode 7
	; $2106: 2x2 mosaic
	lda #$1107
	sta z:$05
	
	; $212e-2f: disable window clipping
	stz z:$2e
	
	; clear tilemap
	tya ; we never use Y so it's always zero from power on 
	; - assume it's not nonzero when booting from a flash cart either
:	sta z:$16
	sty $18
	inc
	bpl :-

	lda #$003f
	; $2100: enable screen
	; (same value is used to init {part} below)
	sta z:$00

	pld
	; init variables
	sta part
	lda #$7ec8
	sta seed+2
	stz direction

next_part:
	lda part
	sta length
	
	asl
	tax
	lda word_seeds,x
	sta seed
	sta cursor

next_length:
	lda #31
	sta pixel
next_pixel:
	; update LFSR
	asl seed
	rol seed+2
	bcc :+
	lda seed
	eor #$1db7
	sta seed
	sta direction
	lda seed+2
	eor #$04c1
	sta seed+2

:	sep #$20
	.a8
	; update direction
	tyx
	lda direction
	asl
	and #$04
	bne :+
	inx

:	lda #$ff
	bcs :+
	lda #$01
:	clc
	adc cursor,x
	and #$7f
	sta cursor,x

	; wait for vblank
:	bit $4212
	bpl :-
	
	; plot pixel
	; need to translate 8.8 coords into 7.7 here, which sucks, but oh well
	lda cursor+1
	lsr
	sta $2117
	lda cursor
	bcc :+
	ora #$80
:	sta $2116
	lda part
	and #$03
	sta $2118

	rep #$20
	.a16
	dec pixel
	bpl next_pixel
	dec length
	bpl next_length
	dec part
	bpl next_part

	; the end
	; don't use STP since that makes snes9x freak out, 
	; but there are no interrupts anyway
	wai
	
.out .sprintf("code size: %u bytes (including reset vector)", *-code_start+2)
	
; -----------------------------------------------------------------------------
.segment "RESET"
.word .loword(Main)
