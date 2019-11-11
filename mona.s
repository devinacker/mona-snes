; "Mona" SNES procgfx source code
; by Revenant / Resistance

; Based on an original Atari XL demo by Ilmenit.

; A basic rundown of the algorithm can be found here:
; https://codegolf.stackexchange.com/questions/126738/lets-draw-mona-lisa

; This version is larger than the original due to some necessary hardware init,
; but I still tried to make it as small as possible using a few tricks like:
; - using mode 7 + high scaling factor + mosaic to create an easy 128x128
;   render surface with packed pixels
; - using direct color mode instead of CGRAM for easy/small palette setup
; - abusing open-bus behavior to be able to init some hardware without having
;   to load an immediate value into A or X first

.p816

INIDISP = $2100
BGMODE  = $2105
BG1HOFS = $210D
BG1VOFS = $210E
VMAIN   = $2115
VMADDL  = $2116
VMADDH  = $2117
VMDATAL = $2118
VMDATAH = $2119
M7SEL   = $211A
M7A     = $211B
M7B     = $211C
M7C     = $211D
M7D     = $211E
M7X     = $211F
M7Y     = $2120
TM      = $212C
TMW     = $212E
CGWSEL  = $2130
SETINI  = $2133
HVBJOY  = $4212

; -----------------------------------------------------------------------------
stackbase  = $37
seedLo     = $38
length     = $3a
part       = $3b
seedHi     = $3c
direction  = $3e
cursor     = $40

; -----------------------------------------------------------------------------
.code
code_start:

; This data file was taken directly from the original demo's source.
; It contains the 16-bit LFSR seeds plus an initial 32-bit seed, but we're
; skipping the 32-bit part since we just directly initialize it in code later
word_seeds:
.incbin "DATA.BIN", 4

; 4-color direct (BGR233) palette, based roughly on the colors used by the
; original demo. The background uses $01 instead of $00 since the latter
; would actually be transparent and we avoid properly initializing the actual
; screen backdrop to save space, but a dark non-black color also works okay.
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
	dec z:<INIDISP

	; $2133: disable hires, interlace, etc
	stz z:<SETINI

	; init mode 7 screen buffer here before re-enabling screen
	; what we want to do is create 4 tiles each with a different color
	; as the upper left pixel, then actually use the tile map as a canvas
	lda #$81
	sta z:<VMAIN
	; palette setup
	stz z:<VMADDL
	stz z:<VMADDH
	ldx #$03
:	lda colors,x
	sta z:<VMDATAH
	stz z:<VMDATAH
	dex
	bpl :-
	; restore normal VRAM increment settings
	stz z:<VMAIN

	; at this point X = FF
	; $210d: set mode 7 bg position
	stz z:<BG1HOFS
	stz z:<BG1HOFS
	stx z:<BG1VOFS
	stx z:<BG1VOFS

	; $211f-20: center mode 7 bg at (0,0)
	stz z:<M7X
	stz z:<M7X
	stz z:<M7Y
	stz z:<M7Y

	; $211a - normal screen rotation
	stz z:<M7SEL
	; 211b-1e mode 7 matrix
	; along with the mosaic setting in $2106, this transform will let
	; each tile in the tilemap appear as a single double-size pixel on screen
	; to turn the tilemap itself into our 128x128 four-color drawing surface
	lda #$04
	stz z:<M7A
	sta z:<M7A
	stz z:<M7B
	stz z:<M7B
	stz z:<M7C
	stz z:<M7C
	stz z:<M7D
	sta z:<M7D

	; $212c: enable bg 1
	inc z:<TM

	; start using 16-bit writes from A now
	rep #$20
	.a16

	; $2130-31: disable color math but enable direct color
	inc z:<CGWSEL

	; $2105: enable mode 7
	; $2106: 2x2 mosaic
	lda #$1107
	sta z:<BGMODE

	; $212e-2f: disable window clipping
	stz z:<TMW

	; clear tilemap
	tya ; we never use Y so it's always zero from power on
	; - assume it's not nonzero when booting from a flash cart either
:	sta z:<VMADDL
	sty Z:<VMDATAL
	inc
	bpl :-

	ldx #$3f
	; $2100: enable screen
	; (same value is used to init {part} below as well as stack pointer)
	stx z:<INIDISP

	pld

	; set stack pointer to $003f
	txs

	; initialize the direction by pushing $00
	phd
	; initialize the high byte of the seed
	pea $7ec8

next_part:
	; part number is also the number of 32-pixel increments to draw
	; with the current color

	; push the part number
	phx
	txa
	; update the lower 16 bits of the LFSR seed for this part
	asl
	tay
	lda word_seeds,y
	; also move the cursor/plot position to the same value (LSB = X, MSB = Y)
	sta cursor

next_length:
	; push the length
	phx
	; push the lower 16 bits of the seed
	pha

	; wait for the start of vblank so we can get (seemingly)
	; exactly the same image as the original
:	ldy HVBJOY
	bmi :-
:	ldy HVBJOY
	bpl :-

	; drawing in 32-pixel increments
	ldy #31
next_pixel:
	; update LFSR
	asl seedLo
	rol seedHi
	bcc :+
	; pull the lower 16 bits of the seed
	pla
	eor #$1db7
	; and update
	pha
	; use the updated lower 8 bits of the seed to determine current direction
	sta direction
	lda seedHi
	eor #$04c1
	sta seedHi

:	sep #$20
	.a8
	; update direction
	; bit 1 clear: change Y direction (x = 1)
	; bit 1 set:   change X direction (x = 0)
	; bit 7 clear: increase position (a = 1)
	; bit 7 set:   decrease position (a = -1)

	; initialize X with stack pointer value, with one byte long opcode
	tsx
	lda direction
	asl
	and #$04
	bne :+
	inx

	; subtract by one so the same result can be obtained
	; without clearing the carry flag even when set
:	lda #$ff - 1
	bcs :+
	lda #$01
	; here subtract the current stack pointer value
	; to access the proper address
:	adc cursor - stackbase,x
	and #$7f
	sta cursor - stackbase,x

	; this waiting method can save 5 bytes instead, however,
	; we seem unlucky enough to get several pixels unupdated due to the bad timing
;:	bit HVBJOY
;	bpl :-

	; plot pixel
	; some slight translation is needed here in order to turn our 8-bit X/Y
	; coordinates into a VRAM address - with our current setup, the address
	; has the lowest 7 bits for X and the next 7 bits for Y, so we basically
	; just need to compact 16 bits into 14
	lda cursor+1
	lsr
	sta VMADDH
	lda cursor
	bcc :+
	ora #$80
:	sta VMADDL
	; write a tile number (= color number) into VRAM now
	; based on the lowest 2 bits of the current part/seed number
	lda part
	and #$03
	sta VMDATAL

	rep #$20
	.a16
	; Y = pixel count
	dey
	bpl next_pixel

	; pull the lower 16 bits of the seed
	pla
	; pull the length
	plx
	dex
	bpl next_length

	; pull the part number
	plx
	dex
	bpl next_part

	; the end
	; don't use STP since that makes snes9x freak out,
	; but there are no interrupts anyway
	wai

.out .sprintf("code size: %u bytes (including reset vector)", *-code_start+2)

; -----------------------------------------------------------------------------
.segment "RESET"
.word .loword(Main)
