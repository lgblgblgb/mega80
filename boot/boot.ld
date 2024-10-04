FEATURES {
	STARTADDRESS:	default = $400;
}
MEMORY {
	ZP:		file = "", define = yes, start = $0002, size = $00F0;
#        RAM:		file = %O, start = %S, size = $C000 - %S, define = yes;
	BOOTSECTOR:	file = %O, start = $400, size = $200, define = yes, fill = yes;
	CPMSYS:		file = %O, start = $2001 - 2, size = $C000 - $2001 - 2;
}
SEGMENTS {
	ZEROPAGE:	load = ZP, type = zp;
	CODE:		load = BOOTSECTOR;
	PAYLOAD:	load = CPMSYS, define = yes;
	BSS:		load = CPMSYS, type = BSS;
}
