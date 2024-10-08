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
.INCLUDE "emu.inc"
.INCLUDE "console.inc"

.ZEROPAGE

.EXPORTZP	cpm_dma
.EXPORTZP	disk_sector
.EXPORTZP	disk_track

cpm_dma:	.RES 4		; 4 bytes, as we may use it with 32 bit addressing
disk_sector:	.RES 2
disk_track:	.RES 2

.CODE


; --------------------------------------------------------
; BIOS_READ: Read sector from disk
;            Input:  -
;            Output: A = opresult: 0=OK, 1=(unrecoverable)ERROR, $FF = media changed
; --------------------------------------------------------

.EXPORT	disk_read
.PROC	disk_read
DEBUG_READ = 0
.IF	DEBUG_READ = 1
	WRISTR  {"[READ "}
	LDA	disk_track+1
	JSR	write_hex_byte
	LDA	disk_track
	JSR	write_hex_byte
	LDA	#'/'
	JSR	write_char
	LDA	disk_sector+1
	JSR	write_hex_byte
	LDA	disk_sector
	JSR	write_hex_byte
	WRISTR	{"->"}
.ENDIF
	; TODO: now a fake stuff: just fill the DMA area with constant value and report OK
	LDA	cpm_dma+1
	STA	caddr+1
.IF	DEBUG_READ = 1
	JSR	write_hex_byte
.ENDIF
	LDA	cpm_dma
	STA	caddr
.IF	DEBUG_READ = 1
	JSR	write_hex_byte
.ENDIF
	; Conv
	JSR	geo2byteoffset
	BCS	error
	STY	aaddr+2
	STX	aaddr+1
	STA	aaddr
.IF	DEBUG_READ = 1
	WRISTR	{"<-"}
	LDA	aaddr+2
	JSR	write_hex_byte
	LDA	aaddr+1
	JSR	write_hex_byte
	LDA	aaddr
	JSR	write_hex_byte
	LDA	#']'
	JSR	write_char
.ENDIF
	; DMA time!
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,$80,$80,0				; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	128					; DMA length: 128 for the CP/M sector size
aaddr:	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
caddr:	.WORD	0					; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	LDA	#0		; no error (FIXME: this is bad, we must check track/sector)
	RTS
error:
	LDA	#1
	RTS
.ENDPROC

; --------------------------------------------------------
; BIOS_WRITE: Write sector to disk
;             Input:  C = deblocking info
;                         0 = normal sector write [write can be deferred]
;                         1 = write to directory sector [write must be immediate]
;                         2 = write to the first sector of a new data block [write can be deferred, no pre-read is needed]
;             Output: A = opresult: 0=OK, 1=(unrecoverable)ERROR, 2=R/O-DISK, $FF = media changed
; --------------------------------------------------------

.EXPORT	disk_write
.PROC	disk_write
.IF	0
	; No write is supported:
	LDA	#2		; error answer: "disk is R/O"
	RTS
.ELSE
	; TODO: now a fake stuff: just fill the DMA area with constant value and report OK
	LDA	cpm_dma+1
	STA	caddr+1
	LDA	cpm_dma
	STA	caddr
	; Conv
	JSR	geo2byteoffset
	BCS	error
	STY	aaddr+2
	STX	aaddr+1
	STA	aaddr
	; DMA time!
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,$81,$80,0				; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	128					; DMA length: 128 for the CP/M sector size
caddr:	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	I8080_BANK					; source bank + other info
aaddr:	.WORD	0					; target addr
	.BYTE	0					; target bank + other info
	.WORD	0					; modulo: not used
	LDA	#0		; no error (FIXME: this is bad, we must check track/sector)
	RTS
error:
	LDA	#1
	RTS
.ENDIF
.ENDPROC


TOTAL_TRACKS = 17


; Calculates the byte offset from CP/M track and sector info
; Output: Y = bits 16..23
;         X = bits  8..15
;         A = bits  0.. 7
;         CARRY: set -> error [bad sec/trk], clear -> conversion OK
.PROC	geo2byteoffset
	LDA	disk_sector+1
	ORA	disk_track+1
	BNE	error			; track and sector numbers should be below 256
	LDA	disk_track
	CMP	#TOTAL_TRACKS
	BCS	error
	LSR	A
	TAY
	LDA	disk_sector
	ROR	A
	TAX
	LDA	#0
	ROR	A		; bit7 will be "imported", other bits remain zero, carry set to zero (old bit 0)
	RTS			; because of ROR on zero, carry will be cleared on RST, so we're good
error:
.IF	1
	PHA
	PHX
	PHY
	WRISTR	{"*** Invalid track/sector: "}
	LDA	disk_track+1
	JSR	write_hex_byte
	LDA	disk_track
	JSR	write_hex_byte
	LDA	#'/'
	JSR	write_char
	LDA	disk_sector+1
	JSR	write_hex_byte
	LDA	disk_sector
	JSR	write_hex_byte
	JSR	write_crlf
	PLY
	PLX
	PLA
.ENDIF
	SEC			; carry set -> error!
	RTS
.ENDPROC
