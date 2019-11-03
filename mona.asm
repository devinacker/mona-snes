//; "Mona" SNES procgfx source code
//; by Revenant / Resistance

arch snes.cpu
lorom

org $00fe00

define part      $0000 // 2 bytes
define direction $0002 // 2 bytes
define length    $0004 // 2 bytes
define crc_seed  $0006 // 4 bytes
define cursor    $000a // 2 bytes
define pixel     $000c // 2 bytes

word_seeds: 
incbin "DATA.BIN"

colors:
db $bf, $67, $15, $01

Reset:
	clc
	xce

	//; use DP as a pointer to B bus
	phd
	pea   $2100
	pld

	//; $2100: disable the display so we can start setting up VRAM
	dec   $00
	
	//; $2133: disable hires, interlace, etc
	stz   $33

	//; init mode 7 screen buffer here before re-enabling screen
	
	lda   #$81
	sta   $15
	//; test palette setup
	stz   $16
	stz   $17
	ldx   #$03
-
	lda.w colors,x
	sta   $19
	stz   $19
	dex
	bpl   -
	//; restore normal VRAM increment settings
	stz   $15

	//; at this point X = FF
	//; $210d: set mode 7 bg position
	stz   $0d
	stz   $0d
	stx   $0e
	stx   $0e
	
	//; $211f-20: center mode 7 bg at (0,0)
	stz   $1f
	stz   $1f
	stz   $20
	stz   $20

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
	stz   $1e
	sta   $1e
	
	//; $212c: enable bg 1
	inc   $2c

	//; start using 16-bit writes from A now
	rep   #$20
	
	//; $2130-31: disable color math but enable direct color
	inc   $30
	
	//; $2105: enable mode 7
	//; $2106: 2x2 mosaic
	lda.w #$1107
	sta   $05
	
	//; $212e-2f: disable window clipping
	stz   $2e
	
	//; clear tilemap
	tya //; we never use Y so it's always zero from power on 
	//; - assume it's not nonzero when booting from a flash cart either
-
	sta   $16
	sty   $18
	inc
	bpl   -

	lda.w #$003f
	//; $2100: enable screen
	//; (same value is used to init {part} below)
	sta   $00

	pld
	//; init variables
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
	sep   #$20
	//; update direction
	tyx
	lda.b {direction}
	asl
	and.b #$04
	bne   +
	inx
+
	lda.b #$ff
	bcs   +
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
	//; need to translate 8.8 coords into 7.7 here, which sucks, but oh well
	lda.b {cursor}+1
	lsr
	sta   $2117
	lda.b {cursor}
	bcc   +
	ora   #$80
+
	sta   $2116
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
