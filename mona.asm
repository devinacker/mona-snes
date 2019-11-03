//; "Mona" SNES procgfx source code
//; by Revenant / Resistance

arch snes.cpu
lorom

org $808000

define part      $0000 // 2 bytes
define direction $0002 // 2 bytes
define length    $0004 // 2 bytes
define crc_seed  $0006 // 4 bytes
define cursor    $000a // 2 bytes
define pixel     $000c // 2 bytes

word_seeds: 
incbin "DATA.BIN"

colors:
db $bf, $67, $15, $00

Reset:
	clc
	xce
	rep   #$10

	//; use DP as a pointer to B bus
	phd
	pea   $2100
	pld

	//; $2100: disable the display so we can start setting up VRAM
	//; (C will already be set from previous XCE, so we can do it in 2 bytes like this)
	ror   $00
	
	//; $2133: disable hires, interlace, etc
	stz   $33
	
	//; $210d: set mode 7 bg position
	stz   $0d
	stz   $0d
	stz   $0e
	stz   $0e
	
	//; $211f-20: center mode 7 bg at (0,0)
	stz   $1f
	stz   $1f
	stz   $20
	stz   $20

	//; init mode 7 screen buffer here before re-enabling screen
	lda   #$81
	sta   $15
	//; test palette setup
	stz   $16
	stz   $17
	ldx   #$0003
-
	lda   colors,x
	sta   $19
	stz   $19
	dex
	bpl   -
	
	//; clear tilemap
	stz   $15
-
	stx   $16
	stz   $18
	dex
	bmi   -

	//; enable screen
	lda   #$0f
	sta   $00

	//; $2105: enable mode 7
	//; $2106: 2x2 mosaic
	ldx.w #$1107
	stx   $05

	//; $211a - normal screen rotation
	stz   $1a
	//; 211b-1e mode 7 matrix
	lda   #$04
	stz   $1b
	sta   $1b
	stz   $1c
	stz   $1c
	stz   $1d
	stz   $1d
//	asl
	stz   $1e
	sta   $1e
	
	//; $212c: enable bg 1
	inc   $2c

	//; $212e: disable window clipping of main screen
	stz   $2e
	//; $2130: disable color math but enable direct color
	inc   $30
	stz   $31

	pld
	rep   #$20
	//; init variables
	lda.w #$003f
	sta.b {part}
	lda.w #$7ec8
	sta.b {crc_seed}+2
	stz.b {direction}

next_part:
	lda.b {part}
	sta.b {length}
	
	asl
	tax
	lda.w word_seeds,x
	sta.b {crc_seed}
	sta.b {cursor}

next_length:
	lda.w #31
	sta.b {pixel}
next_pixel:
	//; update LFSR
	asl.b {crc_seed}
	rol.b {crc_seed}+2
	bcc   +
	lda.b {crc_seed}
	eor.w #$1db7
	sta.b {crc_seed}
	sta.b {direction}
	lda.b {crc_seed}+2
	eor.w #$04c1
	sta.b {crc_seed}+2
+
	lda.w #$0000
	tax
	sep   #$20
	//; update direction
	lda.b {direction}
	php
	and.b #$02
	bne   +
	inx
+
	lda.b #$ff
	plp
	bmi   +
	lda.b #$01
+
	clc
	adc.b {cursor},x
	and.b #$7f
	sta.b {cursor},x

	//; wait for vblank
-
	bit   $4212
	bpl   -
	
	//; plot pixel	
	ldx.b {cursor}
	stx   $2116
	lda.b {part}
	and.b #$03
	sta   $2118

	rep   #$20
	dec.b {pixel}
	bpl   next_pixel
	dec.b {length}
	bpl   next_length
	dec.b {part}
	bpl   next_part

	//; the end
	//; don't use STP since that makes snes9x freak out, 
	//; but there are no interrupts anyway
	wai

//; The reset vector. Try not to trash this
warnpc $80fffd
org $fffc
dw Reset
dw 0
