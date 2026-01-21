;-------------------------------------------------------------------------------
include '../include/library.inc'
;-------------------------------------------------------------------------------

library HDLIB, 42

;-------------------------------------------------------------------------------
; Dependencies
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; v1 functions
;-------------------------------------------------------------------------------
	export hdl_ScaleHalfResSpriteFullscreen_NoClip
	export hdl_ScaleHalfResTransparentSpriteFullscreen_NoClip

;-------------------------------------------------------------------------------
LcdSize            := ti.lcdWidth*ti.lcdHeight
; minimum stack size to provide for interrupts if moving the stack
InterruptStackSize := 4000
CurrentBuffer      := ti.mpLcdLpbase
TRASPARENT_COLOR   := 2
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
macro mIsHLLessThanDE?
	or	a, a
	sbc	hl, de
	add	hl, hl
	jp	po, $+5
	ccf
end macro
macro mIsHLLessThanBC?
	or	a, a
	sbc	hl, bc
	add	hl, hl
	jp	po, $+5
	ccf
end macro
macro s8 op, imm
	local i
	i = imm
	assert i >= -128 & i < 128
	op, i
end macro

;-------------------------------------------------------------------------------
wait_quick.usages_counter = 0

macro wait_quick?
	call	_WaitQuick
	wait_quick.usages_counter = wait_quick.usages_counter + 1
end macro

postpone
	wait_quick.usages := wait_quick.usages_counter
end postpone

;-------------------------------------------------------------------------------

macro smcByte name*, addr: $-1
	local link
	link := addr
	name equ link
end macro

;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
hdl_ScaleHalfResSpriteFullscreen_NoClip:
; Draws a 160x120 sprite scaled 2x to 320x240 at (0,0)
; Optimized for speed.

    push ix                 ; Preserve IX
    ld   iy, 0
    add  iy, sp
    
    ; --- Setup Source and Destination ---
    ld   hl, (iy + 6)       ; Get sprite pointer (Arg0)
    inc  hl                 ; Skip width byte
    inc  hl                 ; Skip height byte
    
    ld   de, (CurrentBuffer) ; DE = Top-left of screen (X=0, Y=0)
    
    ; We use IXL as our row counter (120 rows)
    ld   a, 120
    ld   ixl, a

NcSprRowLoop:
    ; --- Horizontal Scale (160 -> 320 pixels) ---
    ; We process 160 pixels. Unrolled 4x to reduce branch overhead.
    ld   b, 40              ; 40 * 4 = 160 pixels
NcSprPixelLoop:
    repeat 4
        ld   a, (hl)        ; Load 1 pixel
        inc  hl             ; Next source pixel
        ld   (de), a        ; Write pixel once
        inc  de
        ld   (de), a        ; Write pixel twice
        inc  de
    end repeat
    djnz NcSprPixelLoop

    ; --- Vertical Scale (Line Copy) ---
    ; At this point, HL is at the start of the NEXT sprite row.
    ; DE is at the start of the NEXT screen row.
    ; We need to copy the 320 bytes we just wrote to the current screen row.
    
    push hl                 ; Save sprite pointer
    
    ; Source for copy = Current DE - 320 bytes
    push de
    pop  hl                 
    ld   bc, 320
    or   a
    sbc  hl, bc             ; HL = Start of the line we just finished
    
    ; Destination = DE (Start of the next line)
    ; Count = 320
    ldir                    ; High-speed copy of the entire line
    
    ; After LDIR, DE is now at the start of the 3rd row (ready for next loop)
    pop  hl                 ; Restore sprite pointer
    
    dec  ixl
    jr   nz, NcSprRowLoop

    pop  ix                 ; Restore IX
    ret
	
	
;-------------------------------------------------------------------------------
hdl_ScaleHalfResTransparentSpriteFullscreen_NoClip:
; Draws a 160x120 sprite scaled 2x with transparency
; Hardcoded: X=0, Y=0, Scale=2x
; Optimized: Dual-row writing, no EXX, safe for stack.

    push ix
    push iy                 ; Preserve pointers
    
    ; --- Setup Source and Destination ---
    ; Arg0 (Sprite Pointer) is at SP + 9 (3 for IX, 3 for IY, 3 for Ret)
    ld   hl, 9
    add  hl, sp
    ld   hl, (hl)           ; HL = Sprite structure
    inc  hl                 ; Skip width byte
    inc  hl                 ; Skip height byte
    
    ld   de, (CurrentBuffer) ; DE = Start of Row 1
    ld   bc, 320
    push de
    pop  iy
    add  iy, bc             ; IY = Start of Row 2
    
    ; We use IXL as our outer row counter (120 input rows)
    ld   a, 120
    ld   ixl, a

NcTransRowLoop:
    ld   b, 160             ; Inner loop: 160 input pixels
NcTransPixelLoop:
    ld   a, (hl)            ; 1. Load pixel
    inc  hl
    
    cp   a, TRASPARENT_COLOR; 2. Check transparency
    jr   z, NcTransSkip     ; If transparent, just move pointers
    
    ; 3. Not Transparent: Write 2x2 block
    ; Write Row 1
    ld   (de), a
    inc  de
    ld   (de), a
    inc  de
    
    ; Write Row 2
    ld   (iy + 0), a
    inc  iy
    ld   (iy + 0), a
    inc  iy
    
    djnz NcTransPixelLoop
    jr   NcTransRowAdvance

NcTransSkip:
    ; 4. Transparent: Skip 2 pixels on both rows
    inc  de
    inc  de
    inc  iy
    inc  iy
    djnz NcTransPixelLoop

NcTransRowAdvance:
    ; After 160 pixels (320 output pixels), pointers are:
    ; DE = Start of Row 2, IY = Start of Row 3.
    ; We need to move them to start Row 3 and Row 4.
    
    push iy
    pop  de                 ; DE = Start of Row 3
    ld   bc, 320
    add  iy, bc             ; IY = Start of Row 4
    
    dec  ixl
    jr   nz, NcTransRowLoop

    pop  iy
    pop  ix
    ret
	
;-------------------------------------------------------------------------------
hdl_ColumnMajor_ScaleHalfResTransparentSpriteFullscreen_NoClip:

gfx_ScaledTransSprite_ColMajor:
; Draws a 160x120 sprite scaled 2x
; Input: Sprite Data is ROW-MAJOR (Standard)
; Output: Draws Vertically (Column-Major)
; Optimization: Uses IX for Sprite Stride, HL for Screen Stride.

    push ix
    push iy
    
    ; --- Setup ---
    ld   hl, 9
    add  hl, sp
    ld   hl, (hl)           ; HL = Sprite Data Start
    inc  hl
    inc  hl                 ; Skip width/height
    push hl
    pop  ix                 ; IX = Sprite Pointer (Source)
    
    ld   hl, (CurrentBuffer) ; HL = Screen Pointer (Dest)
    
    ; Define Constants for Stride
    ; BC = Sprite Stride (160 bytes to get to next Y pixel)
    ; DE = Screen Stride (640 bytes to get to next Y block)
    ld   bc, 160
    ld   de, 640
    
    ; Outer Loop: 160 Columns
    ld   a, 160
    ld   iyh, a             ; IYH = Column Counter

.ColLoop:
    push ix                 ; Save Top of Sprite Column
    push hl                 ; Save Top of Screen Column
    
    ; Inner Loop: 120 Rows
    ld   a, 120
    ld   iyl, a             ; IYL = Row Counter

.RowLoop:
    ld   a, (ix+0)          ; Load Pixel from Sprite
    
    ; Advance Sprite Pointer Vertically (Row +1)
    ; We do this now because IX is not needed for the rest of this iter
    add  ix, bc             ; IX += 160
    
    cp   a, 3               ; Transparent?
    jr   z, .Skip
    
    ; --- Draw 2x2 Block ---
    ; 1. Draw Top Pair
    ld   (hl), a            ; Write X
    inc  hl
    ld   (hl), a            ; Write X+1
    
    ; Move HL to Next Line (Down 1 line, Back 1 pixel)
    ; Offset: +320 - 1 = +319
    push bc                 ; Save Sprite Stride (160)
    ld   bc, 319
    add  hl, bc
    
    ; 2. Draw Bottom Pair
    ld   (hl), a            ; Write X
    inc  hl
    ld   (hl), a            ; Write X+1
    
    ; Align HL for next loop (Down 1 line, Back 1 pixel)
    ; Offset: +319
    add  hl, bc
    pop  bc                 ; Restore Sprite Stride (160)
    
    dec  iyl
    jr   nz, .RowLoop
    jr   .NextCol

.Skip:
    ; Transparent: Jump Screen Pointer down 2 lines (640 bytes)
    add  hl, de             ; HL += 640
    
    dec  iyl
    jr   nz, .RowLoop

.NextCol:
    pop  hl                 ; Restore Screen Top
    inc  hl
    inc  hl                 ; Move Screen Right 2 Pixels
    
    pop  ix                 ; Restore Sprite Top
    inc  ix                 ; Move Sprite Right 1 Pixel
    
    dec  iyh
    jr   nz, .ColLoop

    pop  iy
    pop  ix
    ret
	
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; Inner library routines
;-------------------------------------------------------------------------------


_gfx_Wait:
; Waits for the screen buffer to finish being displayed after gfx_SwapDraw
; Arguments:
;  None
; Returns:
;  None
	ret				; will be SMC'd into push hl
	push	af
	ld	a, (ti.mpLcdRis)
	bit	ti.bLcdIntVcomp, a
	jr	nz, .WaitDone
	push	de
.WaitLoop:
.ReadLcdCurr:
	ld	a, (ti.mpLcdCurr + 2)	; a = *mpLcdCurr>>16
	ld	hl, (ti.mpLcdCurr + 1)	; hl = *mpLcdCurr>>8
	sub	a, h
	jr	nz, .ReadLcdCurr	; nz ==> lcdCurr may have updated
					;        mid-read; retry read
	ld	de, (CurrentBuffer + 1)
	sbc	hl, de
	ld	de, -LcdSize shr 8
	add	hl, de
	jr	nc, .WaitLoop
	pop	de
.WaitDone:
	ld	a, $C9			; ret
	ld	(_gfx_Wait), a		; disable wait logic
	pop	af
	ld	hl, $0218		; jr $+4
_WriteWaitQuickSMC:
repeat wait_quick.usages
; Each call _WaitQuick will replace the next unmodified 4-byte entry with
; ld (_WaitQuick_callee_x), hl.
	pop	hl
	ret
	nop
	nop
end repeat
	pop	hl
	ret
;-------------------------------------------------------------------------------


_Shift:
	ex	(sp), ix	; shift copy amount
	push	hl
	pop	iy	; shift line offset
	sub	a, ti.lcdHeight
smcByte _YSpan
	ld	d, ti.lcdWidth / 2
	mlt	de
	ld	hl, (CurrentBuffer)
	add	hl, de
	add	hl, de
	add	hl, bc
	call	_gfx_Wait
ShiftCopyAmount :=$+1
.loop:
	lea	bc, ix	; shift copy amount
	ex	de, hl
ShiftAmountOffset :=$+1
	ld	hl, 0
	add	hl, de
ShiftCopyDirection :=$+1
	ldir
	lea	hl, iy	; shift line offset
	add	hl, de
	inc	a
	jr	nz, .loop
	pop	ix
	ret

;-------------------------------------------------------------------------------
