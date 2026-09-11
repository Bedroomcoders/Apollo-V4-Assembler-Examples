**
**	$VER: RGB565.s v1.1 release (September 2026)
**	Platform: Apollo V4 (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot RGB565.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code build on previous examples and shows how to fill screen fast with any color as input.
**			In addition it shows how to convert one single RGB (24 bit) color to 16 bit RGB565.
**			Please mind that for superfast convertion of 2x2 32bit RGBA to RGB565 we would use the AMMX instruction PACK3216
**			That would be more suitable for converting a 24 bit image to 16 bits. 
**			but this code give better understanding of how it`s done.


			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:RGB565					; Final code is saved to RAM-Disk

POTGOR		equ	$dff016
DMACON		equ	$dff096
DMACONR		equ	$dff002
GFXMODE		equ	$dff1f4
GFXMODER	equ	$dfe1f4
BPLHMOD		equ	$dff1e6
BPLHMODR	equ	$dfe1e6
BPLHPTH		equ	$dff1ec
BPLHPTHR	equ	$dfe1ec
SPRHSTRT	equ	$dff1d0

SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	720
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)



			section mycode,code

			
_Init			move.w	POTGOR,d0
			andi.w	#$fe,d0						; 0 = Paula, 1=Arne (Full SAGA Chipset)
			beq.s	.quit						; If no Vampire v4/SAGA Chipset is detected, quit and don`t tell anyone :-)

			ori.w	#$0800,sr					; Set AMMX Bit - Enable use of e-registers

			movea.l	4.w,a6						; a6 = ExecBase
			move.l	#(SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)+64,d0
			move.l	#MEMF_CLEAR!MEMF_PUBLIC,d1			; Cleared memory, SAGA Graphics don`t need chipram - NO LIMITS !!!
			jsr	_LVOAllocVec(a6)				; Allocate memory for screen buffer + 64 bytes for alignment
			move.l	d0,_MemoryBuffer
			beq	.quit

			add.l	#63,d0
			and.l	#-64,d0
			move.l	d0,_ScreenPointer				; This trick aligns the Screenpointer to 64 bytes in memory = Quicker access to the data

			jsr	_LVODisable(a6)

			move.w	DMACONR,store_dmacon
			move.w	GFXMODER,store_gfxmode
			move.w	BPLHMODR,store_bplhmod
			move.l	BPLHPTHR,store_bplhpth

			move.l	#-16,SPRHSTRT					; Move mousepoint out of screen
			move.w	#$7fff,DMACON
			move.w	#$0a02,GFXMODE					; 0a = 1280x720, 02 = 16 bit chunky 
			clr.w	BPLHMOD

			move.l  _ScreenPointer,BPLHPTH				; Writes our aligned screenpointer to BPLHPTH and the hardware displays the data on screen

			move.l	#$44ff88,d0					; Red = $44, Green = $ff, Blue = $88
			bsr	_ConvertRGB565
			bsr	_ClearScreen					; d0 is returned from _ConvertRGB565

			
.lmbLoop		btst	#6,$bfe001					; Wait for left mousebutton
			bne.s	.lmbLoop

			or.w    #$8000,store_dmacon				; Set the highest bit to enable write access
			move.w	store_dmacon,DMACON
			move.w	store_gfxmode,GFXMODE
			move.w	store_bplhmod,BPLHMOD
			move.l	store_bplhpth,BPLHPTH

			movea.l	4.w,a6
			jsr	_LVOEnable(a6)

			movea.l	_MemoryBuffer,a1
			jsr	_LVOFreeVec(a6)

.quit			moveq	#0,d0
			rts



			; _ConvertRGB565
			;--------------------------------------------------------------
			; Input:
			;	d0.w = RGB888 - 24 bits color to convert
			; Result
			;	d0.w = RGB565 - 16 bits color

_ConvertRGB565		moveq	#0,d1
										; Red
			move.l	d0,d2						; d2 = 00RRGGBB (Red, Green, Blue)
			lsr.l	#8,d2						; d2 = RRGGBB00
			and.w	#%1111100000000000,d2				; d2 = 5 bits of R, rest is 0
			or.w	d2,d1
										; Green
			move.l	d0,d2						; d2 = 00RRGGBB
			lsr.l	#5,d2						; Shift Green to bits 5-10 (6 bits in total)
			and.w	#%0000011111100000,d2				; Mask out other colors
			or.w	d2,d1
										; Blue
			move.l	d0,d2						; d2 = 00RRGGBB
			lsr.w	#3,d2						; Shift Blue to bits 0-4 (5 bits)
			and.w	#%0000000000011111,d2				; Mask out other bits
			or.w	d2,d1						; d1 = combined result = RGB565

			move.l	d1,d0						; Return in d0
			rts
			


			; _ClearScreen
			;--------------------------------------------------------------
			; Input:
			;	d0.w = RGB565 color to clear screen with
						
_ClearScreen		movea.l	_ScreenPointer,a0

			move.w	d0,d1
			swap	d1
			move.w	d0,d1							; d1 = color repeated twice (32 bit)

			load	d1,e0
			lslq	#32,e0,e1						; shift low 32 bits of e0 to high 32 bits of e1
			por	e0,e1,e0						; combine e0 and e1. e0 = color repeated four times (64 bit)
			

			move.l	#((SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_BPP)/8)-1,d0	; Divide by 8 since we write 8 bytes for every iteration of the loop
.loop			store	e0,(a0)+						; Store command write 8 bytes (4 pixels) in one go
			dbf.l	d0,.loop						; dbf is running in second pipe and does not consume extra CPU time
			rts


			
			; Declaring data in BSS section gives automatic allocation of cleared memory

			Section myBSS,bss

			cnop	0,4						; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1
store_gfxmode		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1
