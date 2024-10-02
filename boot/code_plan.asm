KERNAL_SETNAM	= $FFBD
KERNAL_SETLFS	= $FFBA
KERNAL_OPEN	= $FFC0
KERNAL_CHKIN	= $FFC6
KERNAL_CHRIN	= $FFCF
KERNAL_CLOSE	= $FFC3
KERNAL_CLRCHN	= $FFCC





	; open the channel file

	LDA	#cname_end-cname
	LDX	#<cname
	LDY	#>cname
	JSR	KERNAL_SETNAM

	LDA	#2		; file no 2
	LDX	$BA		; last used device
	BNE	:+
	LDX	#$08		; device 8 if $BA was zero
:	LDY	#$02		; secondary address 2
	JSR	KERNAL_SETLFS

	JSR	KERNAL_OPEN
	BCS	.error		; carry set -> file open error

	; open the command channel

	LDA #uname_end-uname
	LDX #<uname
	LDY #>uname
	JSR KERNAL_SETNAM     ; call SETNAM
	LDA #$0F      ; file number 15
	LDX $BA       ; last used device number
	LDY #$0F      ; secondary address 15
	JSR KERNAL_SETLFS     ; call SETLFS

	JSR KERNAL_OPEN     ; call OPEN (open command channel and send U1 command)
	BCS .error    ; if carry set, the file could not be opened

	; check drive error channel here to test for
	; FILE NOT FOUND error etc.

	LDX #$02      ; filenumber 2
	JSR KERNAL_CHKIN     ; call CHKIN (file 2 now used as input)

	LDA #<sector_address
	STA $AE
	LDA #>sector_address
	STA $AF

	LDY #$00
.loop   JSR KERNAL_CHRIN     ; call CHRIN (get a byte from file)
	STA ($AE),Y   ; write byte to memory
	INY
	BNE .loop     ; next byte, end when 256 bytes are read
.close
	LDA #$0F      ; filenumber 15
	JSR KERNAL_CLOSE     ; call CLOSE

	LDA #$02      ; filenumber 2
	JSR KERNAL_CLOSE     ; call CLOSE

	JSR KERNAL_CLRCHN     ; call CLRCHN
	RTS
.error
	; Akkumulator contains BASIC error code

	; most likely errors:
	; A = $05 (DEVICE NOT PRESENT)

	... error handling for open errors ...
	JMP .close    ; even if OPEN failed, the file has to be closed

cname:  .TEXT "#"
cname_end:

uname:  .TEXT "U1 2 0 18 0"
uname_end:

; New version
dos_command:
	.BYTE	"U1 2 0 "	; Command Channel Drive
trc_cmd = $
	.BYTE	"1 "		; track number
sec_cmd_h = $
sec_cmd_l = $ + 1
	.BYTE	"02"		; sector number, start with "2", with 256 bytes long sector this is the next after our 512 byte "boot sector"
dos_command_length = $ - dos_command


; Increment sector number
.PROC	rewrite_dos_cmd
	LDA	sec_cmd_l
	CMP	#'9'
	BEQ	ovrflow
	INC	sec_cmd_l
	RTS
ovrflow:
	LDA	#'0'
	STA	sec_cmd_l
	LDA	sec_cmd_h
	CMP	#'3'
	BEQ	ovrflow2
	INC	sec_cmd_h
	RTS
ovrflow2:
	LDA	#'0'
	STA	sec_cmd_h
	INC	trc_cmd
	RTS
.ENDPROC

