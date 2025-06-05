;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2017 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------
;#####################################################################
;### MODULE: SetVideoMode                                          ###
;#####################################################################
;### Routines to establish and control video modes                 ###
;#####################################################################
;
.module cpct_video
 .include "../../CPCteleraHW.src"   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: cpct_setCRTCReg
;;
;;   Sets a new value for a given CRTC register
;;
;; C Definition:
;;    void <cpct_setCRTCReg> (<u8> *regnum*, <u8> *newval*) __z88dk_callee
;;
;; Input Parameters (2 Bytes):
;;    (1B B) newval - New value to be set for the register
;;    (1B C) regnum - Number of the register to be set 
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_setCRTCReg_asm
;;
;; Parameter Restrictions:
;;    - *regnum* has to be a regiter number from 0 to 31
;;    - *newval* can be any 8-bits value. Its valid range depends on the selected 
;;             register. Each register has a different set of valid values.
;;
;; Known issues:
;;   * Using values out of range have unpredicted behaviour and can even 
;; potentially cause damage to real Amstrad CPC monitors. Please, use with care.
;;
;; Details:
;;    This function sets a new value for a given CRTC register. To do so, two 
;; commands have to be sent to two different ports of the CRTC: 
;;    - Select Register (Port 0xBC) 
;;    - Write Register (Port 0xBD)
;;
;;    So, this function just gets the two parameters given by the user and sends
;; them to these two ports in sequence, in order to set a new value for the 
;; given register.
;;
;;    It is important to note that the function does not perform any kind of check.
;; You must be careful not to select inappropriate registers or write out-of-range
;; values to any register. In fact, as CRTC registers control the way the image
;; is produced by the monitor, there is always a risk of damaging a real monitor
;; due to inappropriate values. Use this feature with care.
;;
;; Destroyed Register values:
;;    AF, BC
;;
;; Required memory:
;;     C-bindings - 14 bytes
;;   ASM-bindings - 11 bytes
;;
;; Time Measures:
;; (start code)
;;    Case     | microSecs (us) | CPU Cycles
;; ------------------------------------------
;;     Any     |      27        |    108
;; ------------------------------------------
;;  ASM-Saving |     -10        |    -40
;; ------------------------------------------
;; (end code)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    .if HARDWARE_CPC
   ;; Select CRTC the register to be modified
   ld     a, b                ;; [1] A = Value to be set (Save for later use)
   ld     b, #CRTC_SELECTREG  ;; [2] B = 0xBC CRTC Select Register, C = register number to be selected
   out  (c), c                ;; [4] Select register
   ;; Set the new value for the CRTC Register
   ld     c, a                ;; [1] C = Value to be set (which was previously saved into A)
   ld     b, #CRTC_SETVAL     ;; [2] B = 0xBD CRTC Set Register Value
   out  (c), c                ;; [4] Set the value

   ret                        ;; [3] Return to caller
    .else
        ld      e,c
        ld      d,#0x00
        ld      hl,#crtregs
        add     hl,de
        ld      a,(hl)
        ld      (regsel+1),a
regsel: jr      #0x00
crtreg1:
        call    pagein
        ld      a,b
        ld      (#0xc006),a     ;screen x
        srl     a
        ld      b,a
        ld      a,#0x1f
        sub     b
        ld      c,a             ;left margin
        add     a,b
        add     a,b
        ld      h,a             ;right margin
        ld      a,(#0xc006)     ;screen y
        ld      b,a
        ld      a,h
        call    set_margins
        ld      a,(pageout+1)
        push    af
        ld      de,(#0xc004)
        jp      setaddr

crtreg6:
        call    pagein
        ld      a,b
        cp      #0x1a
        jr      c,height_ok
        ld      a,#0x19
height_ok:
        add     a,a
        add     a,a
        ld      (#0xc007),a     ;screen y
        add     a,a
        ld      b,a
        ld      a,#0xc8
        sub     b
        push    af
        ld      hl,(#0xc002)    ;rght,left margin
        ld      c,l
        ld      a,h
        call    set_margins
        ld      c,a
        pop     af
        jr      z,pageout
        ld      b,a
        ld      a,c
        ld      c,#0x3f
        call    set_margins
pageout:
        ld      a,#0x00
        ei
        out     (#0xb3),a
crtcret:
        ret


pagein: in      a,(#0xb3)
        ld      (pageout+1),a
        ld      a,#0xff
        di
        out     (#0xb3),a
        ret

crtregc:
        ld      l,b
        jp      _cpct_setVideoMemoryPage
crtregd:
        ld      l,b
        jp      _cpct_setVideoMemoryOffset

set_margins:
        ld      hl,#0xc002      ;left margin
        ld      de,#0x000f
setmarg:
        ld      (hl),c
        inc     l
        ld      (hl),a
        add     hl,de
        ld      (hl),c
        inc     l
        ld      (hl),a
        add     hl,de
        djnz    setmarg
        ret

        .include "video/cpct_setVideoMemoryPage.s"
        .include "video/cpct_setVideoMemoryOffset.s"

crtregs:
        .db     crtcret-crtreg1,crtreg1-crtreg1,crtcret-crtreg1,crtcret-crtreg1,crtcret-crtreg1,crtcret-crtreg1,crtreg6-crtreg1,crtcret-crtreg1
        .db     crtcret-crtreg1,crtcret-crtreg1,crtcret-crtreg1,crtcret-crtreg1,crtregc-crtreg1,crtregd-crtreg1,crtcret-crtreg1,crtcret-crtreg1
   .endif