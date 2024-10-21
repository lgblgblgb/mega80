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

	INCLUDE	"common.inc"

main:
	LD	HL, (trans)
	OUT	(GW_GET_INFO_STR), A
	OUT	(GW_PRINT_ASCIIZ), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13,10,"BDOS at ",0

	LD	HL, (6)
	OUT	(GW_PRINT_HEX_WORD), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", BIOS at ",0

	LD	HL, (1)
	OUT	(GW_PRINT_HEX_WORD), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M system is ",0

	LD	C, 12			; BDOS function: get version number
	CALL	5

	LD	A, H
	OUT	(GW_PRINT_HEX_BYTE), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M version is ",0

	LD	A, L
	OUT	(GW_PRINT_HEX_BYTE), A

	JP	0			; Return to CP/M via WBOOT
