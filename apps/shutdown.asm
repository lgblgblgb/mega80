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
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB "Press Y to confirm MEGA/80 CP/M shutdown (RAMDRIVE changes will be lost) ",0

	OUT	(GW_GET_KEY), A

	; Check confirmation for shutdown
	CP	A, 'y'
	JP	Z, shutdown
	CP	A, 'Y'
	JP	Z, shutdown

	; Not confirmed, return to CP/M via WBOOT
	JP	0

shutdown:
	OUT	(GW_SHUTDOWN), A
