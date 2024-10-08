.CODE


.EXPORT build_info_str
build_info_str:
; The included file will be created by the Makefile
.INCLUDE "buildinfo_inc.asm"
.BYTE 0	; ASCII string terminator

