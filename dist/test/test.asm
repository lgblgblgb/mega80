; vi: ft=ca65

.WORD	$2001
.ORG	$2001
.SETCPU	"4510"
.SCOPE
	.WORD lastline, $FFFF
	; TODO: for me, BASIC 10 "BANK" keyword is quite confusing. According to the available documentation,
	; It's set the BANK number, with the extension that +128 means the "BASIC configuration" (I/O, etc)
	; However according to my tests, it's not true. Using BANK 128 here, still does not work. What I can
	; found only for a sane C65 loader is using BANK 0 before SYS, and doing all the memory MAP, etc then
	; in machine code for the desired mode. I will do that, in routine init_system, see later.
	.WORD $02FE					; "BANK" basic 10 token (double byte token, btw)
	.BYTE " 0 : "
	.BYTE $9E					; "SYS" basic token
	.BYTE " "
	.BYTE $30+.LOBYTE((stub_main .MOD 10000)/ 1000)
	.BYTE $30+.LOBYTE((stub_main .MOD  1000)/  100)
	.BYTE $30+.LOBYTE((stub_main .MOD   100)/   10)
	.BYTE $30+.LOBYTE( stub_main .MOD    10)
	.BYTE 0
lastline:
	.WORD 0
.ENDSCOPE


; Must be moved into BSS segment later
sd_cmd_tmp:		.BYTE	0	; workspace for sd_op_lba
drive_sd_img_base_b0:	.BYTE 0,0
drive_sd_img_base_b1:	.BYTE 0,0
drive_sd_img_base_b2:	.BYTE 0,0
drive_sd_img_base_b3:	.BYTE 0,0
current_drive:		.BYTE 0
diskbuffer:		.RES	1024
irq_counter:		.RES	1

.MACRO  WRISTR  str
	JSR	write_inline_string
	.BYTE	str
	.BYTE	0
.ENDMACRO

CHROUT = $FFD2
write_char = CHROUT
string_p = $2


.PROC	write_inline_string
        PLA
        STA     string_p
        PLA
        STA     string_p+1
        PHZ
:       INW     string_p
	LDZ	#0
        LDA     (string_p),Z
        BEQ     :+
        JSR     write_char
        BRA     :-
:       INW     string_p
        PLZ
        JMP     (string_p)
.ENDPROC



.PROC	sd_wait
	LDA	irq_counter	; check the IRQ incremented counter
	BMI	timeout		; if counter hits 128 or more (to avoid "catching the moment" situation for some odd reason)
	LDA	$D680
	AND	#3
	BNE	sd_wait
	CLC
	RTS
timeout:
	SEC
	RTS
.ENDPROC


; Sector is relative to the mounting registers!
; Sector is always 512 bytes long (1600 of them on a D81)
; A=SD-card controller command to send
; X=D81 512 byte sector LBA, low byte
; Z= --""--, hi byte
; Y=current drive [MAKE SURE the drive is valid!!]
; SD buffer must be filled before (write-op), or read after (read-op)
.PROC	sd_op_lba
	; Save the SD-card command
	STA	sd_cmd_tmp
	; Check if we're in the range (0..1599, ie 0-$63F)
	TZA
	CMP	#6
	BCC	doit
	BNE	error
	TXA
	CMP	#$40
	BCC	doit
timeout:
error:	SEC
	RTS
	; IMG_BASE + Z/X -> SD-ctrl SD-sector registers
doit:	TXA
	CLC
	ADC	drive_sd_img_base_b0,Y
	STA	$D681
	TZA
	ADC	drive_sd_img_base_b1,Y
	STA	$D682
	LDA	#0
	ADC	drive_sd_img_base_b2,Y
	STA	$D683
	LDA	#0
	ADC	drive_sd_img_base_b3,Y
	STA	$D684
	; Use the IRQ incremented variable to have some time-out
	LDA	#128 - 60	; give approx 1 sec of time for the operation to work out (see sd_wait)
	STA	irq_counter
	; Just to be on the safe side: wait for SD-controller to be ready
	JSR	sd_wait
	BCS	timeout
	; Issue the command
	LDA	sd_cmd_tmp
	STA	$D680
	; Again, wait for SD-controller to be ready, this time: to wait for the command finished we've issued above
	JSR	sd_wait
	BCS	timeout
	; check error status
	; TODO: maybe we need reset-retry on error?
	LDA	$D680
	AND	#$40+$20
	BNE	error
	; OK :-)
	CLC
	RTS
.ENDPROC

.PROC	sd_rd_lba
	LDA	#2	; SD-read command
	JMP	sd_op_lba
.ENDPROC



; Uses 128 byte sector notion.
; One track is always 4 sectors
cpmimg_read_sector:


; Input: Y=current drive
.PROC	check_mega80_disk_format
	; Read disk, we need the first three "CBM sector" (256 bytes each) which needs two 512-bytes sectors to cover
	LDX	#.LOBYTE(800)	; "LBA" 512-byte sector number low byte
	LDZ	#.HIBYTE(800)	; --""-- high byte
	JSR	sd_rd_lba
	BCS	error
	; copy to buffer
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,$80,$80,0				; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	512					; DMA length
	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
	.WORD	diskbuffer				; target addr
	.BYTE	0					; target bank + other info
	.WORD	0					; modulo: not used
	JSR	sd_op_lba
	LDX	#.LOBYTE(801)
	LDZ	#.HIBYTE(801)
	JSR	sd_rd_lba
	BCS	error
	; copy to buffer
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,$80,$80,0				; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	512					; DMA length
	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
	.WORD	diskbuffer+512				; target addr
	.BYTE	0					; target bank + other info
	.WORD	0					; modulo: not used
	; Check the format ID
	LDX	#5
:	LDA	diskid,X
	CMP	diskbuffer+$AD
	BNE	nope
	DEX
	BPL	:-
	; Check the copy of the slice entires (bit negated)
	LDX	#$3F
:	LDA	$0C0,X
	EOR	#$FF
	CMP	$3C0,X
	BNE	nope
	DEX
	BPL	:-
	; Check the slice names
	LDX	#14
:	LDA	nameid,X
	CMP	diskbuffer+$3C5,X
	BNE	nope
	CMP	diskbuffer+$3E5,X
	BNE	nope
	DEX
	BPL	:-
	LDA	diskbuffer+$3D4		; last char of slice0 filename
	INA
	CMP	diskbuffer+$3F4		; last char of slice1 filename
	BNE	nope
	CMP	#'1'
	BNE	nope
	; Check slice types
	LDA	#$85+$40
	CMP	diskbuffer+$3C2
	BNE	nope
	CMP	diskbuffer+$3E2
	BNE	nope
	; At this point, probably we're OK to trust that the disk is correct ...
	LDX	current_drive
	;TODO: we want to read parameters from disk and apply to the system

	CLC
	RTS

error:
nope:	; *** Not a MEGA/80 CP/M format disk ***
	SEC
	RTS
diskid: .BYTE "MEGA80"			;  6 bytes
nameid:	.BYTE "CP/M DISK POOL "		; 15 bytes
.ENDPROC


HDOS_BUFFER = $400

; HDOS_SETNAME
; Input:  A = ASCIIZ name ptr low byte
;         Y = ASCIIZ name ptr high byte
; Output: Carry SET   = OK [WARNING! Opposite as usual!]
;         Carry clear = ERROR
; Hyppo/HDOS needs (256 byte) page aligned data for SETNAME!
; Thus we must copy the input parameter first
.PROC	hdos_setname
	STA	string_p
	STY	string_p+1
	LDY	#0
:	LDA	(string_p),Y
	STA	HDOS_BUFFER, Y
	BEQ	:+
	INY
	BPL	:-
	CLC	; too long - longer than 128 bytes?!
	RTS
:	LDA	#$2E	; HDOS: "setname" function
	LDY	#.HIBYTE(HDOS_BUFFER)
	STA	$D640
	CLV
	RTS
toolong:
	CLC
	RTS
.ENDPROC




d81name: .BYTE "DIR.D81",0


stub_main:
	LDA	#.LOBYTE(d81name)
	LDY	#.HIBYTE(d81name)
	JSR	hdos_setname

	; Do the actual "mounting"
	LDA	#$40	; HDOS: d81attach0
	STA	$D640	; the trap!
	CLV

	LDA	$D68C
	STA	drive_sd_img_base_b0
	LDA	$D68D
	STA	drive_sd_img_base_b1
	LDA	$D68E
	STA	drive_sd_img_base_b2
	LDA	$D68F
	STA	drive_sd_img_base_b3

	JSR	check_mega80_disk_format

;	LDA	#'!'
;	JSR	CHROUT
;	WRISTR	"EZ KOMOLY"

	LDA	#$12	; HDOS: opendir
	STA	$D640
	CLV
	TAX		; returned file descriptor by "opendir" moved to X

@readdir:
	LDA	#$14	; HDOS: readdir, needs fd in X
	LDY	#.HIBYTE(HDOS_BUFFER)
	STA	$D640
	CLV
	BCC	@error_or_eod

	LDY	#' '
	LDA	HDOS_BUFFER+$56
	AND	#16
	BEQ	:+
	LDY	#'>'
:	TYA
	JSR	CHROUT
	LDY	#0
:	LDA	HDOS_BUFFER+65,Y
	JSR	CHROUT
	INY
	CPY	#8
	BNE	:-
	LDA	#' '
	JSR	CHROUT
	LDA	HDOS_BUFFER+65+8
	JSR	CHROUT
	LDA	HDOS_BUFFER+65+9
	JSR	CHROUT
	LDA	HDOS_BUFFER+65+10
	JSR	CHROUT
	LDA	#' '
	JSR	CHROUT
	LDA	#'|'
	JSR	CHROUT
	LDA	#' '
	JSR	CHROUT
	BRA	@readdir

@error_or_eod:
	LDA	#$16	; HDOS: closedir, needs fd in X
	STA	$D640
	CLV


	RTS


