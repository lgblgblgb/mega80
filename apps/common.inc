; vi: ft=z8a
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
; ----------------------------------------------------------------------------

	ORG	0x100

	LD	HL, (6)
	DEC	H		; leave 1K for the transfer buffer
	DEC	H
	DEC	H
	DEC	H
	LD	SP, HL
	LD	(trans), HL

	; MEGA-GW func #0: activation
	LD	BC, "Me"
	LD	DE, "Ga"
	XOR	A		; for test: if it's MEGA/80, the OUT op will modify 'A'
	OUT	(0), A
	OR	A
	JP	Z, no_mega80_error

	; Jump to the application
	JP	main

trans:
	DW	0

no_mega80_error:
	LD	C, 9
	LD	DE, .text
	CALL	5
	JP	0
.text:	DB	"This app needs MEGA/80$"



GW_SHUTDOWN		=  1
GW_GET_INFO_STR		=  2
GW_PRINT_ASCIIZ		=  3
GW_PRINT_CHAR		=  4
GW_PRINT_CRLF		=  5
GW_PRINT_HEX_DIGIT	=  6
GW_PRINT_HEX_BYTE	=  7
GW_PRINT_HEX_WORD	=  8
GW_GET_KEY		=  9
GW_PRINT_ASCIIZ_INLINE	= 10
GW_INIT_DIR		= 11
GW_READ_DIR		= 12
GW_CHROOT		= 13
GW_CHDIR		= 14
GW_ATTACH		= 15
