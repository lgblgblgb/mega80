; ----------------------------------------------------------------------------
;
; Software emulator of the 8080 CPU for the MEGA65, intended for CP/M or such.
; Please read comments throughout this source for more information.
;
; Copyright (C)2017,2024 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
;
; ----------------------------------------------------------------------------
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Please note: this is *NOT* a Z80 emulator, but a 8080. Still, I
; prefer the Z80 style assembly syntax over 8080, so don't be
; surpised.
;
; ----------------------------------------------------------------------------


.INCLUDE "mega65.inc"
.INCLUDE "cpu.inc"

TEXT_COLOUR	= 13
BG_COLOUR	= 0
BORDER_COLOUR	= 11
CURSOR_COLOUR	= 2

.ZEROPAGE

key_queued:		.RES 1
key_timing:		.RES 1
string_p:		.RES 2
cursor_x:		.RES 1
cursor_y:		.RES 1
cursor_blink_counter:	.RES 1
ring_the_bell:		.RES 1
irq_counter:		.RES 1


.CODE

; Note about screen routines: these are highly unoptimazed, the main focus is on CPU emulator
; Surely at many places (scroll, fill) DMA can be more useful. I wait for that to create
; a "library" with possible detecting/using new and old DMA revisions as well. Honestly, I just
; coded it what ideas I have without too much thinking, to allow to focus on the more important
; and speed sensitive part (i8080 emulation). So there is huge amount room here for more sane
; and optimized solution!


; Purpose: reset console state, for future escape sequences and like that
.EXPORT	console_state_reset
.PROC	console_state_reset
	RTS
.ENDPROC


; Currently we don't handle colours etc anything, but full colour RAM anyway with a consistent colour
.EXPORT	clear_screen
.PROC	clear_screen
	LDA	#0
	STA	cursor_x
	STA	cursor_y
;	STA	$D702		; DMA list bank addr
	LDA	#15
	STA	4088		; cursor shape
;	LDA	#.HIBYTE(dma_list)
;	STA	$D701
;	LDA	#.LOBYTE(dma_list)
;	STA	$D705		; starts the DMA! [enhanced mode DMA, because it's $D705 and not $D700]
;	RTS
;dma_list:
	STA	$D707	; trigger in-line DMA session
	; First DMA entry, clear the screen
	.BYTE	$A, 0	; enhanced mode opts, rev-A list
	.BYTE	4|3	; DMA command, and other info (chained, op is 3, which is fill)
	.WORD	80*25	; DMA operation length
	.WORD	32	; source addr, NOTE: in case of FILL op (now!) this is not an address, but low byte is the fill value!! (space character now)
	.BYTE	0	; source bank + other info
	.WORD	$800	; target addr
	.BYTE	0	; target bank + other info
	.WORD	0	; modulo ... no idea, just skip it
	; Second DMA entry, init the colour RAM: we access colour RAM by DMA at the C65 position, we don't need to enable full 2K colour RAM in the I/O area
	.BYTE	0	; no enhanced mode opts in this
	.BYTE	3
	.WORD	80*25
	.WORD	TEXT_COLOUR
	.BYTE	0
	.WORD	$F800	; C65 colour RAM addr
	.BYTE	1	; C65 colour RAM bank
	.WORD	0
	RTS
.ENDPROC


.EXPORT	write_inline_string
write_inline_string:
	PLA
	STA	string_p
	PLA
	STA	string_p+1
	PHZ
	LDZ	#0
@loop:
	INW	string_p
	LDA	(string_p),Z
	BEQ	@eos
	JSR	write_char
	JMP	@loop
@eos:
	INW	string_p
	PLZ
	JMP	(string_p)


write_string:
	PHZ
	LDZ	#0
@loop:
	LDA	(string_p),Z
	BEQ	@eos
	JSR	write_char
	INZ
	BNE	@loop
@eos:
	PLZ
	RTS


.EXPORT	write_hex_word_at_zp
.PROC write_hex_word_at_zp
	PHX
	TAX
	LDA	z:1,X
	JSR	write_hex_byte
that:
	LDA	z:0,X
	JSR	write_hex_byte
	PLX
	RTS
.ENDPROC

.EXPORT	write_hex_byte_at_zp
.EXPORT	write_hex_byte
.EXPORT	write_hex_nib
.EXPORT	write_char
.EXPORT	write_crlf

write_crlf:
	LDA	#13
	JSR	write_char
	LDA	#10
	JMP	write_char

write_hex_byte_at_zp:
	PHX
	TAX
	BSR	write_hex_word_at_zp::that

write_hex_byte:
	PHA
	LSR	A
	LSR	A
	LSR	A
	LSR	A
	JSR	write_hex_nib
	PLA
write_hex_nib:
	AND	#$F
	ORA	#'0'
	CMP	#'9'+1
	BCC	write_char
	ADC	#6
.PROC write_char
	PHX
	; cursor begin: purpose, show "solid" cursor during output
	LDX	#8
	STX	cursor_blink_counter
	LDX	#1
	STX	$D015
	; cursor end
	CMP	#32
	BCS	normal_char
	CMP	#13
	BEQ	cr_char
	CMP	#10
	BEQ	lf_char
	CMP	#8
	BEQ	bs_char
	TAX
	LDA	#'^'
	JSR	write_char
	TXA
	JSR	write_hex_byte
	PLX
	RTS
bs_char:
	LDA	cursor_x
	BEQ	:+
	DEA
	STA	cursor_x
:	PLX
	RTS
cr_char:
	LDA	#0
	STA	cursor_x
	PLX
	RTS
normal_char:
	PHA
	; load address
	LDX	cursor_y
	LDA	screen_line_tab_lo,X
	STA	self_addr
	LDA	screen_line_tab_hi,X
	STA	self_addr+1
	LDX	cursor_x
	PLA
	AND	#$7F
	;TAX
	;LDA	ascii_to_screencodes-$20,X
	self_addr = * + 1
	STA	$8000,X
	CPX	#79
	BEQ	eol
	INX
	STX	cursor_x
	PLX
	RTS
eol:
	LDA	#0
	STA	cursor_x
lf_char:
	LDA	cursor_y
	CMP	#24
	BEQ	scroll
	INA
	STA	cursor_y
	PLX
	RTS
	; Start of scrolling of screen
scroll:
;	LDA	#0
;	STA	$D702
;	LDA	#.HIBYTE(scroll_dma_list)
;	STA	$D701
;	LDA	#.LOBYTE(scroll_dma_list)
;	STA	$D705	; this actually starts the DMA operation
;	; end of scrolling of screen
;	PLX
;	RTS
	STA	$D707	; trigger in-line DMA
;scroll_dma_list:	; DMA list for scolling
	; First DMA entry (chained) to copy screen content [this is "old DMA behaviour"!]
	.BYTE	$A,0	; enhanced mode opt
	.BYTE	4	; DMA command, and other info (bit2=chained, bit0/1=command: copy=0)
	.WORD	24*80	; DMA operation length
	.WORD	$850	; source addr
	.BYTE	0	; source bank + other info
	.WORD	$800	; target addr
	.BYTE	0	; target bank + other info
	.WORD	0	; modulo ... no idea, just skip it
	; Second DMA entry (last) to erase bottom line
	.BYTE	0	; enhanced mode opt
	.BYTE	3	; DMA command, and other info (not chained so last, op is 3, which is fill)
	.WORD	80	; DMA operation length
	.WORD	32	; source addr, NOTE: in case of FILL op (now!) this is not an address, but low byte is the fill value!! (space character now)
	.BYTE	0	; source bank + other info
	.WORD	$F80	; target addr
	.BYTE	0	; target bank + other info
	.WORD	0	; modulo ... no idea, just skip it
	PLX
	RTS

screen_line_tab_lo:
	.BYTE	$0,$50,$a0,$f0,$40,$90,$e0,$30,$80,$d0,$20,$70,$c0,$10,$60,$b0,$0,$50,$a0,$f0,$40,$90,$e0,$30,$80
screen_line_tab_hi:
	.BYTE	$8,$8,$8,$8,$9,$9,$9,$a,$a,$a,$b,$b,$b,$c,$c,$c,$d,$d,$d,$d,$e,$e,$e,$f,$f
.ENDPROC



.MACRO	WRISTR	str
	JSR	write_inline_string
	.BYTE	str
	.BYTE	0
.ENDMACRO


.EXPORT	init_console
.PROC init_console
	; Turn hot-register off
	LDA	#$80
	TRB	$D05D
	; Setup our own character set included in MEGA/80
	.IMPORT	font_data
	LDA	#.LOBYTE(font_data)
	STA	$D068
	LDA	#.HIBYTE(font_data)
	STA	$D069
	LDA	#0
	STA	$D06A
	; Set interrupt handler
	LDA	#<irq_handler
	STA	$FFFE
	LDA	#>irq_handler
	STA	$FFFF
	; Set NMI handler
	LDA	#<nmi_handler
	STA	$FFFA
	LDA	#>nmi_handler
	STA	$FFFB
	; Enable raster interrupt
	LDA	#1
	STA	$D01A
	; Sprite
	LDX	#0
sprite_shaper1:
	LDA	#$F0
	STA	$3C0,X
	INX
	LDA	#0
	STA	$3C0,X
	INX
	STA	$3C0,X
	INX
	CPX	#24
	BNE	sprite_shaper1
sprite_shaper2:
	STA	$3C0,X
	INX
	CPX	#63
	BNE	sprite_shaper2

	LDA	#1
	STA	$D015		; sprite enable
	LDA	#100
	STA	$D001		; Y-coord
	STA	$D000		; X-coord
	LDA	#CURSOR_COLOUR
	STA	$D027		; sprite colour
	;
	LDA	#BORDER_COLOUR
	STA	$D020
	LDA	#BG_COLOUR
	STA	$D021

.IF 0
	LDA	#$80
	STA	$D400		; freq low byte
	STA	$D401		; freq hi byte
;	LDA	#16+1		; triangle wf (bit 0 is gate!)
;	STA	$D404		; ctrl reg
;$d405 (54277) 	attack duration 	decay duration voice 1
;$d406 (54278) 	sustain level 	release duration
	LDA	#$FF
	STA	$D405
	STA	$D406
	LDA	#15
	STA	$D418		; volume
	LDA	#16
	STA	ring_the_bell
.ENDIF


	JMP	empty_kbd
.ENDPROC


.PROC	empty_kbd
:	LDA	$D610
	STA	$D610
	BNE	:-
	LDA	#0
	STA	key_queued
	RTS
.ENDPROC


; TODO: also dump the word on the top of the stack!
.EXPORT	reg_dump
.PROC	reg_dump
	WRISTR	"OP="
	LDA	cpu_op
	JSR	write_hex_byte
	WRISTR	" PC="
	LDA	#cpu_pc
	JSR	write_hex_word_at_zp
	WRISTR	" SP="
	LDA	#cpu_sp
	JSR	write_hex_word_at_zp
	WRISTR	" AF="
	LDA	#cpu_af
	JSR	write_hex_word_at_zp
	WRISTR	" BC="
	LDA	#cpu_bc
	JSR	write_hex_word_at_zp
	WRISTR	" DE="
	LDA	#cpu_de
	JSR	write_hex_word_at_zp
	WRISTR	" HL="
	LDA	#cpu_hl
	JSR	write_hex_word_at_zp
	JMP	write_crlf
.ENDPROC








.PROC	irq_handler
	PHA
	PHX
	PHY
	PHZ

;	; Test for BRK
;	TSX
;	LDA	$105,X
;	AND	#$10
;	BEQ	notbrk
;
;
;	INC	$D020
;
;	;JMP	eoi
;
;notbrk:
	; --- KEYBOARD scanning with $D610 ---
	LDA	key_queued
	BNE	@already_has		; avoid scanning, if there is already a character extracted to kbd_queued
	LDA	$D610
	BEQ	@end_scan		; no new character in the HW queue
;			PHA
;			JSR	write_hex_byte
;			PLA
	BMI	@invalid		; char codes >= 128 are considered invalid for now, remove it from the queue
	CMP	#32
	BCS	@accept_key		; 32 ... 127 is OK
	CMP	#20			; DEL?
	BEQ	@backspace_trans
	LDX	#@list_of_valid_keys_last
:	CMP	@list_of_valid_keys,X
	BEQ	@accept_key
	DEX
	BPL	:-
	BRA	@invalid
@list_of_valid_keys:	; List of valid keys in the 0-31 ASCII range
	.BYTE	$03	; STOP (or CTRL-C)
	.BYTE	$09	; TAB
	.BYTE	$0D	; return
	.BYTE	$10	; CTRL-P
	.BYTE	$12	; CTRL-R
	.BYTE	$13	; CTRL-S
	.BYTE	$15	; CTRL-U
	.BYTE	$18	; CTRL-X
	.BYTE	$1A	; CTRL-Z (used as EOF marker in CP/M)
@list_of_valid_keys_last = * - @list_of_valid_keys - 1
@already_has:
	INC	key_timing
	BNE	@end_scan
	JSR	empty_kbd
	BRA	@end_scan
@backspace_trans:
	LDA	#8
@accept_key:
	STA	key_queued
	LDA	#255 - 50		; leaving about one sec - do not left extracted key too long in the buffer: maybe it's a useless stuff?
	STA	key_timing
@invalid:
	STA	$D610			; remove key from HW queue
@end_scan:
	; --- END of KEYBOARD scanning ---


	; TODO: simple audio events like "bell" (ascii code 7)?
			BRA		@no_bell
	LDA	ring_the_bell
	BEQ	@no_bell
	DEA
	STA	ring_the_bell
	LSR	A
	LSR	A
	LSR	A
	ORA	#16
	STA	$D404
@no_bell:



	; Cursor blink stuff
	LDA	cursor_blink_counter
	INA
	STA	cursor_blink_counter
	LSR	A
	LSR	A
	LSR	A
	AND	#1
	STA	$D015	; enable
	; Update cursor position (we use a sprite as a cursor, updated in IRQ handler always)
	LDA	cursor_x
	LDY	#0
	ASL	A
	ASL	A
	BCC	:+
	CLC
	INY
:	ADC	#24
	STA	$D000	; sprite-0 X coordinate

	TYA
	ADC	#0

	STA	$D010	; 8th bit stuff
	LDA	cursor_y
	ASL	A
	ASL	A
	ASL	A
	CLC
	ADC	#50
	STA	$D001	; cursor Y coordinate!

	;INC	$84E	; "heartbeat"

.IF 0
	LDA	cpu_pch
	LSR	A
	LSR	A
	LSR	A
	LSR	A
	AND	#15
	TAX
	LDA	hextab,X
	STA	$84C
	LDA	cpu_pch
	AND	#15
	TAX
	LDA	hextab,X
	STA	$84D
	LDA	cpu_pcl
	LSR	A
	LSR	A
	LSR	A
	LSR	A
	AND	#15
	TAX
	LDA	hextab,X
	STA	$84E
	LDA	cpu_pcl
	AND	#15
	TAX
	LDA	hextab,X
	STA	$84F
.ENDIF


	INC	irq_counter

	ASL	$D019	; acknowledge VIC interrupt (note: it wouldn't work on a real C65 as RMW opcodes are different but it does work on M65 as on C64 too!)

eoi:
	PLZ
	PLY
	PLX
	PLA
	RTI

.IF 0
hextab:
	.BYTE	"0123456789ABCDEF"
.ENDIF
.ENDPROC


.PROC	nmi_handler
;	INC	$D020
	RTI
.ENDPROC


.EXPORT	conin_check_status
.PROC	conin_check_status
	LDA	key_queued
	BEQ	:+
	LDA	#$FF
:	RTS
.ENDPROC


.EXPORT	conin_get_with_wait
.PROC	conin_get_with_wait
:	LDA	key_queued
	BEQ	:-
	PHA
	LDA	#0
	STA	key_queued
	PLA
	RTS
.ENDPROC
