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
