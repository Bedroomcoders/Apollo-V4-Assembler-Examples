**
**	$VER: VerticalScroller.s v1.1 release (September 2026)
**	Platform: Apollo V4 (SAGA Graphics)
**	Assemble command:
**				Programs:Developer/VASM/vasmm68k_mot VerticalScroller.s -Fhunkexe
**	
**	Author: Tomas Jacobsen - Bedroomcoders.com
**	Description: 
**
**			This code build on previous examples and copy a large image from our data section to the allocated screen.
**			Further it shows a classic hardware trick that is available on many computer platform, Vertical scroll without moving any data.
**			The Screens buffer containing the image is larger than the screen resolution, and only a portion of it is displayed.
**			By manipulating the screenpointer (where we tell the hardware to show data on screen), we can create the effect of
**			scrolling up and down in the image.


			machine 68080						; NOTE - Tells the assembler to treat this source as 68080 code.

			incdir	"include:"
			include	"lvo/exec_lib.i"
			include	"exec/exec.i"

			output	RAM:VerticalScroller				; Final code is saved to RAM-Disk

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
INTREQ		equ	$dff09c
INTREQR		equ	$dff01e

			
SCREEN_WIDTH	equ	1280
SCREEN_HEIGHT	equ	3200
SCREEN_BPP	equ	2							; Bytes per pixel = 2 (16 bits screen or 1 word per pixel)
IMAGE_HEIGHT	equ	3200
IMAGE_WIDTH	equ	1280
VIEW_HEIGHT	equ	720


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


			bsr	_CopyImageToScreen

			move.l	#0,_ViewOffset
			move.l	#1,_YDirection


.waitLoop		btst	#5,INTREQR+1					; Test low byte bit 5 to wait for Vertical Blank
			beq.s	.waitLoop
			move.w	#$0020,INTREQ					; Clear VBL

			bsr	_AnimateViewPort
			
			btst	#6,$bfe001					; Check for left mousebutton
			bne.s	.waitLoop


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



			; _CopyImageToScreen
			;--------------------------------------------------------------
						
_CopyImageToScreen	lea	_Image,a0
			movea.l	_ScreenPointer,a1
			move.l	#((IMAGE_WIDTH/8)*IMAGE_HEIGHT)-1,d0
.copy			move16	(a0)+,(a1)+
			dbf.l	d0,.copy			
			rts



			; _AnimateViewPort
			;--------------------------------------------------------------
						
_AnimateViewPort	movea.l	_ScreenPointer,a0
			move.l	_ViewOffset,d0
			mulu.l	#SCREEN_WIDTH*2,d0
			
			add.l	d0,a0
			move.l	a0,BPLHPTH
			
			move.l	_ViewOffset,d0
			move.l	_YDirection,d1
			add.l	d1,d0
			cmp.l	#SCREEN_HEIGHT-VIEW_HEIGHT,d0
			bge.s	.flipY
			cmp.l	#0,d0
			ble.s	.flipY

.done			move.l	d0,_ViewOffset
			rts

.flipY			neg.l	_YDirection
			bra.s	.done



			Section myBSS,bss

			cnop	0,4						; Align data to avoid problems
			
_MemoryBuffer		ds.l	1
_ScreenPointer		ds.l	1						; Aligned and populated at runtime
store_dmacon		ds.w	1
store_gfxmode		ds.w	1
store_bplhmod		ds.w	1
store_bplhpth		ds.l	1
_ViewOffset		ds.l	1
_YDirection		ds.l	1


			section	mydata,data
_Image			incbin	"Workers-1280x3200.raw"

