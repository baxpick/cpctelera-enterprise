;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2009 Targhan / Arkos
;;  Copyright (C) 2015 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WArraNTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------
.module cpct_audio
        .include "../../CPCteleraHW.src"
        .include "arkostrackerLW_var.src"

;       Arkos Tracker 2 Lightweight player (format V1 (used by AT2 since alpha4)).

;       ** This player has been superseded by the AKM format, more compact but also more powerful. Please use it instead. **

;       This compiles with RASM. Check the compatibility page on the Arkos Tracker 2 website, it contains a source converter to any Z80 assembler!

;   	This is a generic player, but much simpler and using only the most used features, so that the music and players are both
;   	lightweight. The player supports sound effects.

;       Though the player is optimized in speed, it is much slower than the generic one or the AKY player.
;       With effects used at the same time, it may reach 35 scanlines on a CPC, plus some few more if you are using sound effects.

;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.

;       Target harware:
;       ---------------
;       This code can target Amstrad CPC, MSX, Spectrum and Pentagon. By default, it targets Amstrad CPC.
;       Simply use one of the follow line (BEFORE this player):
;       PLY_LW_HARDWARE_CPC = 1
;       PLY_LW_HARDWARE_MSX = 1
;       PLY_LW_HARDWARE_SPECTRUM = 1
;       PLY_LW_HARDWARE_PENTAGON = 1
;       PLY_LW_HARDWARE_ENTERPRISE = 1
;       Note that the PRESENCE of this variable is tested, NOT its value.
;
;       Some severe optimizations of CPU/memory can be performed:
;       ---------------------------------------------------------
;       - Use the Player Configuration of Arkos Tracker 2 to generate a configuration file to be included at the beginning of this player.
;         It will disable useless features according to your songs! Check the manual for more details, or more simply the testers.
;
;       Sound effects:
;       --------------
;       Sound effects are disabled by default. Declare PLY_LW_MANAGE_SOUND_EFFECTS to enable it:
;       PLY_LW_MANAGE_SOUND_EFFECTS = 1
;       Check the sound effect tester to see how it enables it.
;       Note that the PRESENCE of this variable is tested, NOT its value.
;
;       ROM
;       ----------------------
;       No ROM player is available for this player. I suggest you try the AKM player, which is more powerful and more compact (albeit a bit slower).
;
;       -------------------------------------------------------

PLY_LW_Start:

.equ PLY_LW_HardwareCounter      , PLY_LW_HARDWARE_CPC + PLY_LW_HARDWARE_MSX + PLY_LW_HARDWARE_SPECTRUM + PLY_LW_HARDWARE_PENTAGON + PLY_LW_HARDWARE_ENTERPRISE
        .ifeq PLY_LW_HardwareCounter
.equ PLY_LW_HARDWARE_ENTERPRISE  , 1
       .endif
       .ifgt PLY_LW_HardwareCounter-1
                FAIL 'Only one hardware must be selected!'
       .endif

        ;Agglomerates some flags, because they are treated the same way by this player.
        ;--------------------------------------------------
        ;Creates a flag for pitch in instrument, and also pitch in hardware.
       .if PLY_CFG_SoftOnly_SoftwarePitch + PLY_CFG_SoftToHard_SoftwarePitch + PLY_CFG_SoftAndHard_SoftwarePitch
.equ PLY_LW_PitchInInstrument , 1
       .else
.equ PLY_LW_PitchInInstrument , 0
       .endif
       .if PLY_CFG_SoftToHard_SoftwarePitch + PLY_CFG_SoftAndHard_SoftwarePitch
.equ PLY_LW_PitchInHardwareInstrument , 1
       .else
.equ PLY_LW_PitchInHardwareInstrument , 0
       .endif
        ;A flag for Arpeggios in Instrument, both in software and hardware.
       .if PLY_CFG_SoftOnly_SoftwareArpeggio + PLY_CFG_SoftToHard_SoftwareArpeggio + PLY_CFG_SoftAndHard_SoftwareArpeggio
.equ PLY_LW_ArpeggioInSoftwareOrHardwareInstrument , 1
       .else
.equ PLY_LW_ArpeggioInSoftwareOrHardwareInstrument , 0
       .endif

       .if PLY_CFG_SoftToHard_SoftwareArpeggio + PLY_CFG_SoftAndHard_SoftwareArpeggio
.equ PLY_LW_ArpeggioInHardwareInstrument , 1
       .else
.equ PLY_LW_ArpeggioInHardwareInstrument , 0
       .endif

        ;A flag if noise is used (noise in hardware not tested, not present in this format).
       .if PLY_CFG_NoSoftNoHard_Noise + PLY_CFG_SoftOnly_Noise
.equ PLY_LW_USE_Noise , 1
        ;The noise is managed? Then the noise register access must be compiled.
.equ PLY_LW_USE_NoiseRegister , 1
       .else
.equ PLY_LW_USE_Noise , 0
.equ PLY_LW_USE_NoiseRegister , 0
       .endif
        
        ;Mixing Pitch up/down effects.
       .if PLY_CFG_UseEffect_PitchUp + PLY_CFG_UseEffect_PitchDown + PLY_CFG_UseEffect_SetVolume
.equ PLY_LW_USE_EffectPitchUpDown , 1
       .else
.equ PLY_LW_USE_EffectPitchUpDown , 0
       .endif

        ;Volume and Pitch up/down dual effects (if one exists, the other one too).
       .if PLY_CFG_UseEffect_SetVolume + PLY_LW_USE_EffectPitchUpDown
.equ PLY_LW_USE_Volume_And_PitchUpDown_Effects , 1
       .else
.equ PLY_LW_USE_Volume_And_PitchUpDown_Effects , 0
       .endif

      .ifeq PLY_CFG_UseEffect_SetVolume
       .if PLY_LW_USE_EffectPitchUpDown
                FAIL " plase set: PLY_CFG_UseEffect_SetVolume = 1"
       .endif
      .endif
        ;Volume and Arpeggio Table dual effect (if one exists, the other one too).
       .if PLY_CFG_UseEffect_SetVolume + PLY_CFG_UseEffect_ArpeggioTable
.equ PLY_LW_USE_Volume_And_ArpeggioTable_Effects , 1
           .ifeq PLY_CFG_UseEffect_ArpeggioTable
                FAIL " plase set: PLY_CFG_UseEffect_ArpeggioTable = 1"
           .endif
           .ifeq PLY_CFG_UseEffect_SetVolume
                FAIL " please set: PLY_CFG_UseEffect_SetVolume = 1"
           .endif
       .else
.equ PLY_LW_USE_Volume_And_ArpeggioTable_Effects , 0
       .endif

        ;Reset and Arpeggio Table dual effect (if one exists, the other one too).
       .if PLY_CFG_UseEffect_Reset + PLY_CFG_UseEffect_ArpeggioTable
.equ PLY_LW_USE_Reset_And_ArpeggioTable_Effects , 1
           .ifeq PLY_CFG_UseEffect_ArpeggioTable
                FAIL " plase set: PLY_CFG_UseEffect_ArpeggioTable = 1"
           .endif
           .ifeq PLY_CFG_UseEffect_Reset
                FAIL " plase set: PLY_CFG_UseEffect_Reset = 1"
           .endif
       .else
.equ PLY_LW_USE_Reset_And_ArpeggioTable_Effects , 0
       .endif
        
        ;Hooks for external calls. Can be removed if not needed.
       .if PLY_LW_USE_HOOKS
;		assert PLY_LW_Start == $		;Makes sure no extra byte were inserted before the hooks.
                jp PLY_LW_Init          ;Player + 0.
                jp PLY_LW_Play          ;Player + 3.
               .if PLY_LW_STOP_SOUNDS
                jp PLY_LW_Stop          ;Player + 6.
               .endif
       .endif
        
        ;Includes the sound effects player, if wanted. Important to do it as soon as possible, so that
        ;its code can react to the Player Configuration and possibly alter it.
       .if PLY_LW_MANAGE_SOUND_EFFECTS
		.include "arkostrackerLW_SoundEffects.src"
       .endif
        ;[[INSERT_SOUND_EFFECT_SOURCE]]                 ;A tag for test units. Don't touch or you're dead.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpLW_musicInit
;;
;;    Sets up a music into Arkos Tracker Player to be played later on with
;; <cpct_akpLW_musicPlay>.
;;
;; C Definition:
;;    void <cpct_akpLW_musicInit> (void* *songdata*, song number)
;;
;; Input Parameters (2 bytes):
;;    (2B HL) songdata - Pointer to the start of the array containing song's data in AKS binary format
;;    (1B A) song number
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpLW_musicInit_asm
;;
;; Parameter Restrictions:
;;    * *songdata* must be an array containing dong's data in AKS binary format.
;; Take into account that AKS binary format enforces a concrete start location in
;; memory. Therefore, song must have been created in Arkos Tracker and exported 
;; to the same memory location that *songdata* points to. If you fail to 
;; locate the song at the same memory location it was exported for in Arkos 
;; Tracker, unexpected results will happen (Typically, noise will be played but,
;; occasionally your program may hang or crash).
;;
;; Known limitations:
;;    * *songdata* must be the same memory address that the one given to Arkos
;; Tracker when exporting song's binary. Arkos Tracker songs are created to
;; be at a concrete memory location, due to optimization constraints. Therefore,
;; this must be taken into account. If you wanted to change the memory location
;; of the song, you should first open the song into Arkos Tracker and export
;; it again with the new desired memory location.
;;    * This function *will not work from ROM*, as it uses self-modifying code.
;;
;; Details:
;;    This function should be called fist to initialize the song that is to be 
;; played. The function reads the song header and sets up the player to start 
;; playing it. Once this process is done, <cpct_akp_musicPlay> should be called
;; at the required frequency to continuously play the song.
;;
;; Destroyed Register values: 
;;    AF, AF', BC, DE, HL, IX, IY
;;
;; Required memory:
;;    ? bytes 
;;
;;    However, take into account that all of Arkos Tracker Player's
;; functions are linked and included, because they depend on each other. Total
;; memory requirement is around xxxx bytes.
;;
;; Time Measures:
;; (start code)
;;    To be done
;; (end code)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_cpct_akpLW_musicInit::
   ld   hl, #2    ;; [10] Retrieve parameters from stack
   add  hl, sp    ;; [11]
   ld    e, (hl)  ;; [ 7] DE = Pointer to the start of music
   inc  hl        ;; [ 6]
   ld    d, (hl)  ;; [ 7]
   inc  hl
   ld    c, (hl)
   ex   de,hl
cpct_akpLW_musicInit_asm::   ;; Entry point for assembly calls using registers for parameter passing
   ;; First, set song loop times to 0 when we start
   xor   a                          ;; A = 0
   ld (_cpct_akpLW_songLoopTimes), a  ;; _cpct_akpLW_songLoopTimes = 0
   ld    a,c

;Initializes the song. MUST be called before actually playing the song.
;IN:    HL = Address of the song.
;       A = Index of the subsong to play (>=0).
PLY_LW_InitDisarkGenerateExternalLabel:
PLY_LW_Init:
        ;Reads the Song data.
        ;Skips the tag and format number.
;dknr3:  
        ld de,#0x05
        add hl,de

        ;Reads the pointers to the various index tables.
        ld de,#PLY_LW_PtInstruments + 1
        ldi
        ldi
                       .if PLY_CFG_UseEffects                           ;CONFIG SPECIFIC
                               .if PLY_CFG_UseEffect_ArpeggioTable      ;CONFIG SPECIFIC
        ld de,#PLY_LW_PtArpeggios + 1
        ldi
        ldi
                               .else
                                inc hl
                                inc hl
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                               .if PLY_CFG_UseEffect_PitchTable         ;CONFIG SPECIFIC
        ld de,#PLY_LW_PtPitches + 1
        ldi
        ldi
                               .else
                                inc hl
                                inc hl
                               .endif ;PLY_CFG_UseEffect_PitchTable
                       .else
;dknr3:  
        ld de,#0x0004
        add hl,de
                       .endif ;PLY_CFG_UseEffects

        ;Finds the address of the Subsong.
        ;HL points on the table, adds A * 2.
        ;Possible optimization: possible to set the Subsong directly.
        ld e,a
        ld d,#0x00
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        
        ;Reads the header of the Subsong.
        ld a,(de)       ;Gets the speed.
        inc de
        ld (PLY_LW_Linker + 1),de
        ld (PLY_LW_Speed + 1),a
        ;Forces a new line.
        dec a
        ld (PLY_LW_TickCounter + 1),a

        ;Can be removed if there is no need to reset the song.
        xor a
        ld (PLY_LW_PatternRemainingHeight + 1),a

        ;A big LDIR to erase all the data blocks. Optimization: can be removed if there is no need to reset the song.
        ld hl,#PLY_LW_Track1_Data
        ld de,#PLY_LW_Track1_Data + 1
;dknr3:  
        ld bc,#PLY_LW_Track3_Data_End - PLY_LW_Track3_Data - 1
        ld (hl),#0x00
        ldir

        ;Reads the first instrument, the empty one, and set-ups the pointers to the instrument to read.
        ;Optimization: needed if the song doesn't start with an instrument on all the channels. Else, it can be removed.
        ld hl,(PLY_LW_PtInstruments + 1)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc de          ;Skips the header.
        ld (PLY_LW_Track1_PtInstrument),de
        ld (PLY_LW_Track2_PtInstrument),de
        ld (PLY_LW_Track3_PtInstrument),de
   .if HARDWARE_ENTERPRISE
        jp     ayReset
   .else
        ret
   .endif


;Cuts the channels, stopping all sounds.
       .if PLY_LW_STOP_SOUNDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpLW_stop
;;
;;    Stops playing musing and sound effects on all 3 channels.
;;
;; C Definition:
;;    void <cpct_akpLW_stop> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpLW_stop_asm
;;
;; Known limitations:
;;  * This function *will not work from ROM*, as it uses self-modifying code.
;;
;; Details:
;;    This function stops the music and sound effects playing in the 3 channels. 
;; It can be later continued again calling <cpct_akp_musicPlay>. Please, take
;; into account that sound effects cannot be played while music is stopped, as
;; code for sound effects and music play is integrated.
;;
;; Destroyed Register values: 
;;    AF, AF', BC, DE, HL, IX, IY
;;
;; Required memory:
;;    xx bytes 
;;
;;    However, take into account that all of Arkos Tracker Player's
;; functions are linked and included, because they depend on each other. Total
;; memory requirement is around xxxx bytes.
;;
;; Time Measures:
;; (start code)
;;    To be done
;; (end code)
;;
;; Credits:
;;    This is a modification of the original <Arkos Tracker Player at
;; http://www.grimware.org/doku.php/documentations/software/arkos.tracker/start> 
;; code from Targhan / Arkos. Madram / Overlander and Grim / Arkos have also 
;; contributed to this source.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Stop the music, cut the channels.
_cpct_akpLW_stop::
cpct_akpLW_stop_asm::  ;; Entry point for assembly calls 

PLY_LW_StopDisarkGenerateExternalLabel:
PLY_LW_Stop:
       .ifeq PLY_LW_HARDWARE_ENTERPRISE
        ld (PLY_LW_SaveSP + 1),sp
       .endif

        xor a
        ld (PLY_LW_Track1_Volume),a
        ld (PLY_LW_Track2_Volume),a
        ld (PLY_LW_Track3_Volume),a
       .if PLY_LW_HARDWARE_MSX
                ld a,#0b10111111          ;Bit 7/6 must be 10 on MSX!
       .else
                ld a,#0b00111111          ;On CPC, bit 6 must be 0! Other platforms don't care.
       .endif
        ld (PLY_LW_MixerRegister),a
        jp PLY_LW_SendPsg
       .endif ;PLY_LW_STOP_SOUNDS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpLW_musicPlay
;;
;;    Plays next music cycle of the present song with Arkos Tracker Player. Song 
;; has had to be previously established with <cpct_akp_musicInit>.
;;
;; C Definition:
;;    void <cpct_akpLW_musicPlay> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpLW_musicPlay_asm
;;
;; Known limitations:
;;  * This function *will not work from ROM*, as it uses self-modifying code.
;;
;; Details:
;;    This function is to be called to start and continue playing the presently 
;; selected song with Arkos Tracker Player. Depending on the frequency at which 
;; the song were created, this function should be called 12, 25, 50, 100, 200 
;; or 300 times per second. 
;;
;;    Each time you call the function, it plays 1/frequency seconds. This means
;; that you have to manually synchronize your calls to this function to have
;; a stable music playing. If you call too fast or too slow you will either 
;; interrupt sound or have sound valleys. Therefore, you are responsible for
;; calling this function with the most accurate timing possible, to get best 
;; sound results.
;;
;; Destroyed Register values: 
;;    AF, AF', BC, DE, HL, IX, IY
;;
;; Required memory:
;;    xxxx bytes 
;;
;;    However, take into account that all of Arkos Tracker Player's
;; functions are linked and included, because they depend on each other. Total
;; memory requirement is around xxx bytes.
;;
;; Time Measures:
;; (start code)
;;    To be done
;; (end code)
;;
;; Credits:
;;    This is a modification of the original <Arkos Tracker Player at
;; http://www.grimware.org/doku.php/documentations/software/arkos.tracker/start> 
;; code from Targhan / Arkos. Madram / Overlander and Grim / Arkos have also 
;; contributed to this source.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_cpct_akpLW_musicPlay::
cpct_akpLW_musicPlay_asm::   ;; Entry point for assembly calls 

;Plays one frame of the song. It MUST have been initialized before.
;The stack is saved and restored, but is diverted, so watch out for the interruptions.
PLY_LW_PlayDisarkGenerateExternalLabel:
PLY_LW_Play:
       .ifeq PLY_LW_HARDWARE_ENTERPRISE
        ld (PLY_LW_SaveSP + 1),sp
       .endif

        ;Reads a new line?
PLY_LW_TickCounter: ld a,#0x00
        inc a
PLY_LW_Speed: cp #0x01                       ;Speed (>0).
        jp nz,PLY_LW_TickCounterManaged

        ;A new line must be read. But have we reached the end of the Pattern?
PLY_LW_PatternRemainingHeight: ld a,#0x00              ;Height. If 0, end of the pattern.
        sub #0x01
        jr c,PLY_LW_Linker
        ;Pattern not ended. No need to read the Linker.
        ld (PLY_LW_PatternRemainingHeight + 1),a
        jr PLY_LW_ReadLine

        ;New pattern. Reads the Linker.
;dknr3:
PLY_LW_Linker: ld hl,#0x0000
PLY_LW_LinkerPostPt:
        ;Resets the possible empty cell counter of each Track.
        xor a
        ld (PLY_LW_Track1_WaitEmptyCell),a
        ld (PLY_LW_Track2_WaitEmptyCell),a
        ld (PLY_LW_Track3_WaitEmptyCell),a

        ;Reads the state byte of the pattern.
        ld a,(hl)
        inc hl
        rra
        jr c,PLY_LW_LinkerNotEndOfSongOk
   ;; Increment song loop times
   ld    a, (_cpct_akpLW_songLoopTimes)
   inc   a
   ld (_cpct_akpLW_songLoopTimes), a

        ;End of song.
        ld a,(hl)               ;Reads where to loop in the Linker.
        inc hl
        ld h,(hl)
        ld l,a
        jr PLY_LW_LinkerPostPt

;; Loop times
;;    Read here to know the number of times a song has looped
_cpct_akpLW_songLoopTimes:: .db 0

PLY_LW_LinkerNotEndOfSongOk:
        rra
        ld b,a
                       .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC        
        ;New speed?
        jr nc,PLY_LW_LinkerAfterSpeed
        ld a,(hl)
        inc hl
        ld (PLY_LW_Speed + 1),a
PLY_LW_LinkerAfterSpeed:
                       .endif ;PLY_CFG_UseSpeedTracks

        ;New height?
        rr b
        jr nc,PLY_LW_LinkerUsePreviousHeight
        ld a,(hl)
        inc hl
        ld (PLY_LW_LinkerPreviousRemainingHeight + 1),a
        jr PLY_LW_LinkerSetRemainingHeight
        ;The same height is used. It was stored before.
PLY_LW_LinkerUsePreviousHeight:
PLY_LW_LinkerPreviousRemainingHeight: ld a,#0x00
PLY_LW_LinkerSetRemainingHeight:
        ld (PLY_LW_PatternRemainingHeight + 1),a

        ;New transpositions?
        rr b
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        jr nc,PLY_LW_LinkerAfterNewTranspositions
        ;New transpositions.
        ld de,#PLY_LW_Track1_Transposition
        ldi
        ld de,#PLY_LW_Track2_Transposition
        ldi
        ld de,#PLY_LW_Track3_Transposition
        ldi
PLY_LW_LinkerAfterNewTranspositions:
                       .endif ;PLY_CFG_UseTranspositions

        ;Reads the 3 track pointers.
        ld de,#PLY_LW_Track1_PtTrack
        ldi
        ldi
        ld de,#PLY_LW_Track2_PtTrack
        ldi
        ldi
        ld de,#PLY_LW_Track3_PtTrack
        ldi
        ldi
        ld (PLY_LW_Linker + 1),hl

;Reads the Tracks.
;---------------------------------
PLY_LW_ReadLine:
;dknr3:
PLY_LW_PtInstruments:   ld de,#0x0000
        exx
        ld ix,#PLY_LW_Track1_Data
        call PLY_LW_ReadTrack
        ld ix,#PLY_LW_Track2_Data
        call PLY_LW_ReadTrack
        ld ix,#PLY_LW_Track3_Data
        call PLY_LW_ReadTrack

        xor a
PLY_LW_TickCounterManaged:
        ld (PLY_LW_TickCounter + 1),a



;Plays the sound stream.
;---------------------------------
                ld de,#PLY_LW_PeriodTable
        exx

        ld c,#0b11100000          ;Register 7, shifted of 2 to the left. Bits 2 and 5 will be possibly changed by each iteration.

        ld ix,#PLY_LW_Track1_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_LW_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_LW_Track1_Registers
        call PLY_LW_PlaySoundStream

        srl c                   ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!
                                ;Also, on MSX? bit 6 must be 0.
        ld ix,#PLY_LW_Track2_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_LW_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_LW_Track2_Registers
        call PLY_LW_PlaySoundStream

       .if PLY_LW_HARDWARE_MSX
                scf             ;On MSX, bit 7 must be 1.
                rr c
       .else
                rr c            ;On other platforms, we don't care about b7.
       .endif
        ld ix,#PLY_LW_Track3_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_LW_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_LW_Track3_Registers
        call PLY_LW_PlaySoundStream

        ld a,c

;Plays the sound effects, if desired.
;-------------------------------------------
       .if PLY_LW_MANAGE_SOUND_EFFECTS
                        call PLY_LW_PlaySoundEffectsStream
       .else
                        ld (PLY_LW_MixerRegister),a
       .endif ;PLY_LW_MANAGE_SOUND_EFFECTS



;Sends the values to the PSG.
;---------------------------------
PLY_LW_SendPsg:
      .IF PLY_LW_HARDWARE_ENTERPRISE

        ld      de,#PLY_LW_Registers_RetTable
        call    ayRegisterWriteDE_  ;reg 8
        call    ayRegisterWriteDE_  ;reg 0
        call    ayRegisterWriteDE_  ;reg 1
        call    ayRegisterWriteDE_  ;reg 9
        call    ayRegisterWriteDE_  ;reg 2
        call    ayRegisterWriteDE_  ;reg 3
        call    ayRegisterWriteDE_  ;reg 10
        call    ayRegisterWriteDE_  ;reg 4
        call    ayRegisterWriteDE_  ;reg 5
       .if PLY_LW_USE_NoiseRegister + PLY_LW_USE_NoiseRegisterS         ;CONFIG SPECIFIC
        call    ayRegisterWriteDE_  ;reg 6
       .endif
       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        call    ayRegisterWriteDE_  ;reg 7
        call    ayRegisterWriteDE_  ;reg 11
        call    ayRegisterWriteDE_  ;reg 12
PLY_LW_SendPsgRegisterR13:
PLY_LW_SetReg13: 
        ld      a,#0x00
PLY_LW_SetReg13Old: 
        cp      #0x00
        ret     z
        ;Different. R13 must be played. Updates the old R13 value.
        ld      (PLY_LW_SetReg13Old + 1),a
        ld      c,#0x0d
        jp      ayRegisterWrite     ;reg 13
       .else
;        jp      ayRegisterWriteDE_  ;reg 7
       .endif
ayRegisterWriteDE_:
        ld      a,(de)
        ld      c,a
        inc     de
        ld      a,(de)
        inc     de
        inc     de
        inc     de
        jp      ayRegisterWrite
    .include "AYemul_EP.src"

PLY_LW_SendPsgRegister:
PLY_LW_SendPsgRegisterAfterPop:
PLY_LW_SendPsgRegisterEnd:
      .else

        ld sp,#PLY_LW_Registers_RetTable

       .if PLY_LW_HARDWARE_CPC
;dknr3:  
        ld bc,#0xf680
        ld a,#0xc0
;dknr3:  
        ld de,#0xf4f6
        out (c),a	;#f6c0          ;Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
       .endif

       .if PLY_LW_HARDWARE_SPECTRUM
;dknr3:  
        ld de,#0xbfff
;dknr3:  
        ld bc,#0xfffd
       .endif

       .if PLY_LW_HARDWARE_PENTAGON
;dknr3:  
        ld de,#0xbfff
;dknr3:  
        ld bc,#0xfffd
       .endif

PLY_LW_SendPsgRegister:
        pop hl          ;H = value, L = register.
PLY_LW_SendPsgRegisterAfterPop:

       .if PLY_LW_HARDWARE_CPC
        ld b,d
        out (c),l       ;#f400 + register.
        ld b,e
    .db #0xed,#0x71     ;out (c),#0x00   ;#f600
        ld b,d
        out (c),h       ;#f400 + value.
        ld b,e
        out (c),c       ;#f680
        out (c),a       ;#f6c0
       .endif

       .if PLY_LW_HARDWARE_SPECTRUM + PLY_LW_HARDWARE_PENTAGON
        out (c),l       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
       .endif

       .if PLY_LW_HARDWARE_MSX
        ld a,l          ;Register.
        out (#0xa0),a
        ld a,h          ;Value.
        out (#0xa1),a
       .endif

        ret

                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
PLY_LW_SendPsgRegisterR13:

        ;Should the R13 be played? Yes only if different. No "force retrig" is managed by this player.
PLY_LW_SetReg13: ld a,#0x00
PLY_LW_SetReg13Old: cp #0x00
        jr z,PLY_LW_SendPsgRegisterEnd
        ;Different. R13 must be played. Updates the old R13 value.
        ld (PLY_LW_SetReg13Old + 1),a

        ld h,a
        ld l,#0x0d
       .if PLY_LW_HARDWARE_CPC
                ld a,#0xc0
       .endif
        ret                     ;Sends the 13th registers.
                       .endif ;PLY_CFG_UseHardwareSounds

PLY_LW_SendPsgRegisterEnd:

;dknr3:
PLY_LW_SaveSP: ld sp,#0x0000
        ret
       .endif









;Reads a Track.
;IN:    IX = Data block of the Track.
;       DE'= Instrument table. Do not modify!
PLY_LW_ReadTrack:
        ;Are there any empty lines to wait?
        ld a, PLY_LW_Data_OffsetWaitEmptyCell (ix)
        sub #0x01
        jr c,PLY_LW_RT_NoEmptyCell
        ;Wait!
        ld PLY_LW_Data_OffsetWaitEmptyCell (ix) ,a
        ret

PLY_LW_RT_NoEmptyCell:
        ;Reads the Track pointer.
        ld l, PLY_LW_Data_OffsetPtTrack + 0 (ix)
        ld h, PLY_LW_Data_OffsetPtTrack + 1 (ix)
        ld a,(hl)
        inc hl
        ld b,a
        and #0b111111     ;Keeps only the note.
        sub #0x3c
        jr c,PLY_LW_RT_NoteMaybeEffect
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        jr z,PLY_LW_RT_ReadEffect       ;No note, but effect.
                       .endif ;PLY_CFG_UseEffects
        dec a
        jr z,PLY_LW_RT_WaitLong
        dec a
        jr z,PLY_LW_RT_WaitShort
        ;63: Escape code for a note, because octave <2 or >5.
        ;Reads the note.
        ld a,(hl)
        inc hl
        ;The rest is exactly as the "note maybe effect", as B contains the flag to know about the possible
        ;New Instrument and/or Effect?.
        jr PLY_LW_RT_NMB_AfterOctaveCompensation

PLY_LW_RT_NoteMaybeEffect:
        ;A is the note from octave 2, and 60 to compensate the sub above.
        ;Then adds the transposition.
        add a,#0x0c * #0x02 + #0x3c
PLY_LW_RT_NMB_AfterOctaveCompensation:
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        add a,PLY_LW_Data_OffsetTransposition (ix)
                       .endif ;PLY_CFG_UseTranspositions
        ld PLY_LW_Data_OffsetBaseNote (ix),a

        ;New Instrument?
        rl b
        jr c,PLY_LW_RT_NME_NewInstrument
        ;Same Instrument. Retrieves the address previously stored.
        ld a,PLY_LW_Data_OffsetPtBaseInstrument + 0 (ix)
        ld PLY_LW_Data_OffsetPtInstrument + 0 (ix),a
        ld a,PLY_LW_Data_OffsetPtBaseInstrument + 1 (ix)
        ld PLY_LW_Data_OffsetPtInstrument + 1 (ix),a
        jr PLY_LW_RT_NME_AfterInstrument

PLY_LW_RT_NME_NewInstrument:
        ;New Instrument, reads it.
        ld a,(hl)
        inc hl
        exx
                ;Gets the address of the Instrument.
                ld l,a  ;No need to *2, it is already encoded like that.
                ld h,#0x00
                add hl,de       ;Adds to the Instrument Table.
                ld c,(hl)
                inc hl
                ld b,(hl)
                ;Reads the header of the Instrument.
                ld a,(bc)       ;Speed.
                ld PLY_LW_Data_OffsetInstrumentSpeed (ix),a
                inc bc
                ;Stores the pointer on the data of the Instrument.
                ld PLY_LW_Data_OffsetPtInstrument + 0 (ix),c
                ld PLY_LW_Data_OffsetPtInstrument + 1 (ix),b
                ld PLY_LW_Data_OffsetPtBaseInstrument + 0 (ix),c              ;Useful to store the base Instrument address to retrieve it when
                ld PLY_LW_Data_OffsetPtBaseInstrument + 1 (ix),b              ;there is a new instrument, without providing its number (optimization).
        exx
PLY_LW_RT_NME_AfterInstrument:
        ;Resets the step on the Instrument.
        ld PLY_LW_Data_OffsetInstrumentCurrentStep (ix),#0x00

        ;Resets the Track pitch.
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        xor a
                                       .if PLY_LW_USE_EffectPitchUpDown              ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetIsPitchUpDownUsed (ix),a
        ld PLY_LW_Data_OffsetTrackPitchInteger + 0 (ix),a
        ld PLY_LW_Data_OffsetTrackPitchInteger + 1 (ix),a
                                       .endif ;PLY_LW_USE_EffectPitchUpDown
        ;ld PLY_LW_Data_OffsetTrackPitchDecimal (ix),a                ;Shouldn't be needed, the difference shouldn't be noticeable.
        ;Resets the offset on Arpeggio and Pitch tables.
                                       .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetPtArpeggioOffset (ix),a
                                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetPtPitchOffset (ix),a
                                       .endif ;PLY_CFG_UseEffect_PitchTable

                       .endif ;PLY_CFG_UseEffects

        ;Any effect? If no, stop.
        rl b
        jr nc,PLY_LW_RT_CellRead
        ;Effect present.
        ;jr PLY_LW_RT_ReadEffect

                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
PLY_LW_RT_ReadEffect:
        ;Reads effect number and possible data.
        ld a,(hl)
        inc hl
        ld b,a
        exx
                rra
                rra
                rra
                rra
                and #0b1110
                ld iy,#PLY_LW_EffectTable
                ld c,a
                ld b,#0x00
                add iy,bc
        exx
        jp (iy)
                       .endif ;PLY_CFG_UseEffects

PLY_LW_RT_WaitLong:
        ;A 8-bit byte is encoded just after.
        ld a,(hl)
        inc hl
        ld PLY_LW_Data_OffsetWaitEmptyCell (ix),a
        jr PLY_LW_RT_CellRead
PLY_LW_RT_WaitShort:
        ;Only a 2-bit value is encoded.
        ld a,b
        rla                     ;Transfers the bit 7/6 to 1/0.
        rla
        rla
        and #0b11
        ;inc a
        ld PLY_LW_Data_OffsetWaitEmptyCell (ix),a
        ;jr PLY_LW_RT_CellRead
;Jumped to after the Cell has been read.
;IN:    HL = new value of the Track pointer. Must point after the read Cell.
PLY_LW_RT_CellRead:
        ld PLY_LW_Data_OffsetPtTrack + 0 (ix),l
        ld PLY_LW_Data_OffsetPtTrack + 1 (ix),h
        ret


;Manages the effects, if any. For the activated effects, modifies the internal data for the Track which data block is given.
;IN:    IX = data block of the Track.
;OUT:   IX, IY = unmodified.
;       C must NOT be modified!
;       DE' must NOT be modified!
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
PLY_LW_ManageEffects:
                       .if PLY_LW_USE_EffectPitchUpDown      ;CONFIG SPECIFIC
        ;Pitch up/down used?
        ld a,PLY_LW_Data_OffsetIsPitchUpDownUsed (ix)
        or a
        jr z,PLY_LW_ME_PitchUpDownFinished

        ;Adds the LSB of integer part and decimal part, using one 16 bits operation.
        ld l,PLY_LW_Data_OffsetTrackPitchDecimal (ix)
        ld h,PLY_LW_Data_OffsetTrackPitchInteger + 0 (ix)

        ld e,PLY_LW_Data_OffsetTrackPitchSpeed + 0 (ix)
        ld d,PLY_LW_Data_OffsetTrackPitchSpeed + 1 (ix)

        ld a,PLY_LW_Data_OffsetTrackPitchInteger + 1 (ix)

        ;Negative pitch?
        bit 7,d
        jr nz,PLY_LW_ME_PitchUpDown_NegativeSpeed

PLY_LW_ME_PitchUpDown_PositiveSpeed:
        ;Positive speed. Adds it to the LSB of the integer part, and decimal part.
        add hl,de

        ;Carry? Transmits it to the MSB of the integer part.
        adc #0x00
        jr PLY_LW_ME_PitchUpDown_Save
PLY_LW_ME_PitchUpDown_NegativeSpeed:
        ;Negative speed. Resets the sign bit. The encoded pitch IS positive.
        ;Subtracts it to the LSB of the integer part, and decimal part.
        res 7,d

        or a
        sbc hl,de

        ;Carry? Transmits it to the MSB of the integer part.
        sbc #0x00

PLY_LW_ME_PitchUpDown_Save:
        ld PLY_LW_Data_OffsetTrackPitchInteger + 1 (ix),a

        ld PLY_LW_Data_OffsetTrackPitchDecimal (ix),l
        ld PLY_LW_Data_OffsetTrackPitchInteger + 0 (ix),h

PLY_LW_ME_PitchUpDownFinished:
                       .endif   ;PLY_LW_USE_EffectPitchUpDown


        ;Manages the Arpeggio Table effect, if any.
                       .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
        ld a,PLY_LW_Data_OffsetIsArpeggioTableUsed (ix)
        or a
        jr z,PLY_LW_ME_ArpeggioTableFinished
        ;Reads the Arpeggio Table. Adds the Arpeggio base address to an offset.
        ld e,PLY_LW_Data_OffsetPtArpeggioTable + 0 (ix)
        ld d,PLY_LW_Data_OffsetPtArpeggioTable + 1 (ix)
        ld l,PLY_LW_Data_OffsetPtArpeggioOffset (ix)
PLY_LW_ME_ArpeggioTableReadAgain: ld h,#0x00
        add hl,de
        ld a,(hl)
        ;End of the Arpeggio?
        sra a
        jr nc,PLY_LW_ME_ArpeggioTableEndNotReached
        ;End of the Arpeggio. The loop offset is now in A.
        ld l,a  ;And read the next value!
        ld PLY_LW_Data_OffsetPtArpeggioOffset (ix),a
        jr PLY_LW_ME_ArpeggioTableReadAgain

PLY_LW_ME_ArpeggioTableEndNotReached:
        ;Not the end. A = arpeggio note.
        ld PLY_LW_Data_OffsetCurrentArpeggioValue (ix),a
        ;Increases the offset for next time.
        inc PLY_LW_Data_OffsetPtArpeggioOffset (ix)
PLY_LW_ME_ArpeggioTableFinished:
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable


        ;Manages the Pitch Table effect, if any.
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld a,PLY_LW_Data_OffsetIsPitchTableUsed (ix)
        or a
        ret z
        ;Reads the Pitch Table. Adds the Pitch base address to an offset.
        ld e,PLY_LW_Data_OffsetPtPitchTable + 0 (ix)
        ld d,PLY_LW_Data_OffsetPtPitchTable + 1 (ix)
        ld l,PLY_LW_Data_OffsetPtPitchOffset (ix)
PLY_LW_ME_PitchTableReadAgain: ld h,#0x00
        add hl,de
        ld a,(hl)
        ;End of the Pitch?
        sra a
        jr nc,PLY_LW_ME_PitchTableEndNotReached
        ;End of the Pitch. The loop offset is now in A.
        ld l,a  ;And read the next value!
        ld PLY_LW_Data_OffsetPtPitchOffset (ix),a
        jr PLY_LW_ME_PitchTableReadAgain

PLY_LW_ME_PitchTableEndNotReached:
        ;Not the end. A = pitch note. It is converted to 16 bits.
        ld h,#0x00
        or a
        jp p,PLY_LW_ME_PitchTableEndNotReached_Positive
        dec h
PLY_LW_ME_PitchTableEndNotReached_Positive:
        ld PLY_LW_Data_OffsetCurrentPitchTableValue + 0 (ix),a
        ld PLY_LW_Data_OffsetCurrentPitchTableValue + 1 (ix),h
        ;Increases the offset for next time.
        inc PLY_LW_Data_OffsetPtPitchOffset (ix)
                       .endif ;PLY_CFG_UseEffect_PitchTable
        ret

                       .endif ;PLY_CFG_UseEffects







;---------------------------------------------------------------------
;Sound stream.
;---------------------------------------------------------------------

;Plays the sound stream, filling the PSG registers table (but not playing it).
;The Instrument pointer must be updated as it evolves inside the Instrument.
;IN:    IX = Data block of the Track.
;       IY = Points at the beginning of the register structure related to the channel.
;       C = R7. Only bit 2 (sound) must be *set* to cut the sound if needed, and bit 5 (noise) must be *reset* if there is noise.
;       DE' = Period table. Must not be modified.
PLY_LW_PlaySoundStream:
        ;Gets the pointer on the Instrument, from its base address and the offset.
        ld l,PLY_LW_Data_OffsetPtInstrument + 0 (ix)
        ld h,PLY_LW_Data_OffsetPtInstrument + 1 (ix)

        ;Reads the first byte of the cell of the Instrument. What type?
PLY_LW_PSS_ReadFirstByte:
        ld a,(hl)
        ld b,a
        inc hl
        rra
        jr c,PLY_LW_PSS_SoftOrSoftAndHard

        ;NoSoftNoHard or SoftwareToHardware
        rra
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        jr c,PLY_LW_PSS_SoftwareToHardware
                       .endif ;PLY_CFG_UseHardwareSounds

        ;No software no hardware, or end of sound (loop)!
        ;End of sound?
        rra
        jr nc,PLY_LW_PSS_NSNH_NotEndOfSound
        ;The sound loops/ends. Where?
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ;As a sound always has at least one cell, we should safely be able to read its bytes without storing the instrument pointer.
        ;However, we do it anyway to remove the overhead of the Speed management: if looping, the same last line will be read,
        ;if several channels do so, it will be costly. So...
        ld PLY_LW_Data_OffsetPtInstrument + 0 (ix),l
        ld PLY_LW_Data_OffsetPtInstrument + 1 (ix),h
        jr PLY_LW_PSS_ReadFirstByte

PLY_LW_PSS_NSNH_NotEndOfSound:
        ;No software, no hardware.
        ;-------------------------
        ;Stops the sound.
        set 2,c

        ;Volume. A now contains the volume on b0-3.
        call PLY_LW_PSS_Shared_AdjustVolume
        ld PLY_LW_Registers_OffsetVolume (iy),a

        ;Read noise?
        rl b
                       .if PLY_CFG_NoSoftNoHard_Noise        ;CONFIG SPECIFIC
        call c,PLY_LW_PSS_ReadNoise
                       .endif ;PLY_CFG_NoSoftNoHard_Noise
        jr PLY_LW_PSS_Shared_StoreInstrumentPointer

        ;Software sound, or Software and Hardware?
PLY_LW_PSS_SoftOrSoftAndHard:
        rra
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        jr c,PLY_LW_PSS_SoftAndHard
                       .endif ;PLY_CFG_UseHardwareSounds

        ;Software sound.
        ;-----------------
        ;A is the volume. Already shifted twice, so it can be used directly.
        call PLY_LW_PSS_Shared_AdjustVolume
        ld PLY_LW_Registers_OffsetVolume (iy),a

        ;Arp and/or noise?
        ld d,#0x00          ;Default arpeggio.
        rl b
        jr nc,PLY_LW_PSS_S_AfterArpAndOrNoise
        ld a,(hl)
        inc hl
        ;Noise?
        sra a
        ;A is now the signed Arpeggio. It must be kept.
        ld d,a
        ;Now takes care of the noise, if there is a Carry.
                       .if PLY_LW_USE_Noise          ;CONFIG SPECIFIC
        call c,PLY_LW_PSS_ReadNoise
                       .endif ;PLY_LW_USE_Noise
PLY_LW_PSS_S_AfterArpAndOrNoise:

        ld a,d          ;Gets the instrument arpeggio, if any.
        call PLY_LW_CalculatePeriodForBaseNote

        ;Read pitch?
        rl b
                       .if PLY_CFG_SoftOnly_SoftwarePitch    ;CONFIG SPECIFIC
        call c,PLY_LW_ReadPitchAndAddToPeriod
                       .endif ;PLY_CFG_SoftOnly_SoftwarePitch

        ;Stores the new period of this channel.
        exx
                ld PLY_LW_Registers_OffsetSoftwarePeriodLSB (iy),l
                ld PLY_LW_Registers_OffsetSoftwarePeriodMSB (iy),h
        exx

        ;The code below is mutualized!
        ;Stores the new instrument pointer, if Speed allows it.
        ;--------------------------------------------------
PLY_LW_PSS_Shared_StoreInstrumentPointer:
        ;Checks the Instrument speed, and only stores the Instrument new pointer if the speed is reached.
        ld a,PLY_LW_Data_OffsetInstrumentCurrentStep (ix)
        cp PLY_LW_Data_OffsetInstrumentSpeed (ix)
        jr z,PLY_LW_PSS_S_SpeedReached
        ;Increases the current step.
        inc PLY_LW_Data_OffsetInstrumentCurrentStep (ix)
        ret
PLY_LW_PSS_S_SpeedReached:
        ;Stores the Instrument new pointer, resets the speed counter.
        ld PLY_LW_Data_OffsetPtInstrument + 0 (ix),l
        ld PLY_LW_Data_OffsetPtInstrument + 1 (ix),h
        ld PLY_LW_Data_OffsetInstrumentCurrentStep (ix),#0x00
        ret


                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC

        ;Software and Hardware.
        ;----------------------------
PLY_LW_PSS_SoftAndHard:
        ;Reads the envelope bit, the possible pitch, and sets the software period accordingly.
        call PLY_LW_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv
        ;Reads the hardware period.
        ld a,(hl)
        ld (PLY_LW_Reg11),a
        inc hl
        ld a,(hl)
        ld (PLY_LW_Reg12),a
        inc hl

        jr PLY_LW_PSS_Shared_StoreInstrumentPointer


        ;Software to Hardware.
        ;-------------------------
PLY_LW_PSS_SoftwareToHardware:
        call PLY_LW_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv

        ;Now we can calculate the hardware period thanks to the ratio.
        ld a,b
        rra
        rra
        and #0b11100
        ld (PLY_LW_PSS_STH_Jump + 1),a
        exx
PLY_LW_PSS_STH_Jump: 
                jr . + 2           ;Automodified by the line above to jump to the right place.
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                jr nc,PLY_LW_PSS_STH_RatioEnd
                inc hl
PLY_LW_PSS_STH_RatioEnd:
                ld a,l
                ld (PLY_LW_Reg11),a
                ld a,h
                ld (PLY_LW_Reg12),a
        exx

        jr PLY_LW_PSS_Shared_StoreInstrumentPointer

;A shared code for hardware sound.
;Reads the envelope bit in bit 1, arpeggio in bit 7 pitch in bit 2 from A. If pitch present, adds it to BC'.
;Converts the note to period, adds the instrument pitch, sets the software period of the channel.
;Also sets the hardware volume, and sets the hardware curve.
PLY_LW_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv:
        ;Envelope bit? R13 = 8 + 2 * (envelope bit?). Allows to have hardware envelope to 8 or 0xa.
        ;Shifted by 2 to the right, bit 1 is now envelope bit, which is perfect for us.
        and #0b10
        add a,#0x08
        ld (PLY_LW_SetReg13 + 1),a

        ;Volume to 16 to trigger the hardware envelope.
        ld PLY_LW_Registers_OffsetVolume (iy),#0x10

        ;Arpeggio?
        xor a                   ;Default arpeggio.
                       .if PLY_LW_ArpeggioInHardwareInstrument  ;CONFIG SPECIFIC
        bit 7,b                 ;Not shifted yet.
        jr z,PLY_LW_PSS_Shared_REnvBAP_AfterArpeggio
        ;Reads the Arpeggio.
        ld a,(hl)
        inc hl
PLY_LW_PSS_Shared_REnvBAP_AfterArpeggio:
                       .endif ;PLY_LW_ArpeggioInHardwareInstrument
        ;Calculates the software period.
        call PLY_LW_CalculatePeriodForBaseNote

        ;Pitch?
                       .if PLY_LW_PitchInHardwareInstrument  ;CONFIG SPECIFIC
        bit 2,b         ;Not shifted yet.
        call nz,PLY_LW_ReadPitchAndAddToPeriod
                       .endif ;PLY_LW_PitchInHardwareInstrument

        ;Stores the new period of this channel.
        exx
                ld PLY_LW_Registers_OffsetSoftwarePeriodLSB (iy),l
                ld PLY_LW_Registers_OffsetSoftwarePeriodMSB (iy),h
        exx
        ret

                       .endif ;PLY_CFG_UseHardwareSounds
                
;Decreases the given volume (encoded in possibly more then 4 bits). If <0, forced to 0.
;IN:    A = volume, not ANDed.
;OUT:   A = new volume.
PLY_LW_PSS_Shared_AdjustVolume:
        and #0b1111
        sub PLY_LW_Data_OffsetTrackInvertedVolume (ix)
        ret nc
        xor a
        ret

;Reads and stores the noise pointed by HL, opens the noise channel.
;IN:    HL = instrument data where the noise is.
;OUT:   HL = HL++.
;MOD:   A.
               .if PLY_LW_USE_Noise          ;CONFIG SPECIFIC
PLY_LW_PSS_ReadNoise:
        ld a,(hl)
        inc hl
        ld (PLY_LW_NoiseRegister),a
        res 5,c                 ;Opens the noise channel.
        ret
               .endif ;PLY_LW_USE_Noise

;Calculates the period according to the base note and put it in BC'. Used by both software and hardware codes.
;IN:    DE' = period table.
;       A = instrument arpeggio (0 if not used).
;OUT:   HL' = period.
;MOD:   A
PLY_LW_CalculatePeriodForBaseNote:
        ;Gets the period from the current note.
        exx
                ld h,#0x00
                add a,PLY_LW_Data_OffsetBaseNote (ix)                        ;Adds the instrument Arp to the base note (including the transposition).
                               .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
                add PLY_LW_Data_OffsetCurrentArpeggioValue (ix)               ;Adds the Arpeggio Table effect.
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                ld l,a
                sla l                   ;Note encoded on 7 bits, so should be fine.
                add hl,de
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a                  ;HL' = period.

                ;Adds the Pitch Table value, if used.
                               .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
                ld a,PLY_LW_Data_OffsetIsPitchTableUsed (ix)
                or a
                jr z,PLY_LW_CalculatePeriodForBaseNote_NoPitchTable
                ld c,PLY_LW_Data_OffsetCurrentPitchTableValue + 0 (ix)
                ld b,PLY_LW_Data_OffsetCurrentPitchTableValue + 1 (ix)
                add hl,bc
PLY_LW_CalculatePeriodForBaseNote_NoPitchTable:
                               .endif ;PLY_CFG_UseEffect_PitchTable
                ;Adds the Track Pitch.
                               .if PLY_LW_USE_EffectPitchUpDown
                ld c,PLY_LW_Data_OffsetTrackPitchInteger + 0 (ix)
                ld b,PLY_LW_Data_OffsetTrackPitchInteger + 1 (ix)
                add hl,bc
                               .endif ;PLY_LW_USE_EffectPitchUpDown
        exx
        ret

                       .if PLY_LW_PitchInInstrument  ;CONFIG SPECIFIC
;Reads the pitch in the Instruments (16 bits) and adds it to HL', which should contain the software period.
;IN:    HL = points on the pitch value.
;OUT:   HL = points after the pitch.
;MOD:   A, BC', HL' updated.
PLY_LW_ReadPitchAndAddToPeriod:
        ;Reads 2 * 8 bits for the pitch. Slow...
        ld a,(hl)
        inc hl
        exx
                ld c,a                  ;Adds the read pitch to the note period.
        exx
        ld a,(hl)
        inc hl
        exx
                ld b,a
                add hl,bc
        exx
        ret
                       .endif ;PLY_LW_PitchInInstrument













;---------------------------------------------------------------------
;Effect management.
;---------------------------------------------------------------------

                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC

;IN:    HL = points after the first byte.
;               B = data of the first byte on bits 0-4 (will probably needed to be ANDed, as bits 5-7 are undetermined).
;               DE'= Instrument Table (not useful here). Do not modify!
;               IX = data block of the Track.
;OUT:   HL = points after the data of the effect (maybe nothing to do).
;               Each effect must jump to PLY_LW_RT_CellRead.

;Clears all the effects (volume, pitch table, arpeggio table).
                       .if PLY_CFG_UseEffect_Reset           ;CONFIG SPECIFIC.
PLY_LW_EffectReset:
        ;Inverted volume.
        call PLY_LW_ReadInvertedVolumeFromB

        xor a
        ;The inverted volume is managed above, so don't change it.
                               .if PLY_LW_USE_EffectPitchUpDown              ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetIsPitchUpDownUsed (ix),a
                               .endif ;PLY_LW_USE_EffectPitchUpDown
                               .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetIsArpeggioTableUsed (ix),a
        ld PLY_LW_Data_OffsetCurrentArpeggioValue (ix),a      ;Contrary to the Pitch, the value must be reset.
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld PLY_LW_Data_OffsetIsPitchTableUsed (ix),a
                               .endif ;PLY_CFG_UseEffect_PitchTable
        jp PLY_LW_RT_CellRead
                       .endif ;PLY_CFG_UseEffect_Reset

;Changes the volume. Possibly changes the Track pitch.
                       .if PLY_LW_USE_Volume_And_PitchUpDown_Effects           ;CONFIG SPECIFIC.
PLY_LW_EffectVolumeAndPitchUpDown:
        ;Stores the new inverted volume.
        call PLY_LW_ReadInvertedVolumeFromB

        ;Pitch? Warning, the code below is shared with the PitchUp/Down effect.
        bit 4,b
        jp z,PLY_LW_RT_CellRead
        ;Pitch present. Reads and stores its 16 bits value (integer/decimal).
PLY_LW_EffectPitchUpDown_Activated:
        ;Code shared with the effect above.
        ;Activates the effect.
        ld PLY_LW_Data_OffsetIsPitchUpDownUsed (ix),#0xff
        ld a,(hl)
        inc hl
        ld PLY_LW_Data_OffsetTrackPitchSpeed + 0 (ix),a
        ld a,(hl)
        inc hl
        ld PLY_LW_Data_OffsetTrackPitchSpeed + 1 (ix),a

        jp PLY_LW_RT_CellRead
                       .endif ;PLY_LW_USE_Volume_And_PitchUpDown_Effects


;Effect table. Each entry jumps to an effect management code.
;Put after the code above so that the JR are within bound.
PLY_LW_EffectTable:
                       .if PLY_CFG_UseEffects * PLY_CFG_UseEffect_Reset ;CONFIG SPECIFIC
        jr PLY_LW_EffectReset                                   ;000
                       .else
                        jr .
                       .endif
                        
                       .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
        jr PLY_LW_EffectArpeggioTable                           ;001
                       .else
                        jr .
                       .endif
                
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        jr PLY_LW_EffectPitchTable                              ;010
                       .else
                        jr .
                       .endif
                        
                       .if PLY_LW_USE_EffectPitchUpDown              ;CONFIG SPECIFIC
        jr PLY_LW_EffectPitchUpDown                             ;011
                       .else
                        jr .
                       .endif
                        
                       .if PLY_LW_USE_Volume_And_PitchUpDown_Effects         ;CONFIG SPECIFIC
        jr PLY_LW_EffectVolumeAndPitchUpDown                    ;100
                       .else
                        jr .
                       .endif
                        
                       .if PLY_LW_USE_Volume_And_ArpeggioTable_Effects       ;CONFIG SPECIFIC
        jr PLY_LW_EffectVolumeArpeggioTable                     ;101
                       .else
                        jr .
                       .endif
                        
                       .if PLY_LW_USE_Reset_And_ArpeggioTable_Effects        ;CONFIG SPECIFIC
        jr PLY_LW_EffectResetArpeggioTable                      ;110
                       .else
                        jr .
                       .endif
        
        ;111 Unused.



;Pitch up/down effect, activation or stop.
                       .if PLY_LW_USE_EffectPitchUpDown              ;CONFIG SPECIFIC
PLY_LW_EffectPitchUpDown:
        rr b    ;Pitch present or pitch stop?
        jr c,PLY_LW_EffectPitchUpDown_Activated
        ;Pitch stop.
        ld PLY_LW_Data_OffsetIsPitchUpDownUsed (ix),#0x00
        jp PLY_LW_RT_CellRead
                       .endif ;PLY_LW_USE_EffectPitchUpDown

;Arpeggio table effect, activation or stop.
                       .if PLY_CFG_UseEffect_ArpeggioTable           ;CONFIG SPECIFIC
PLY_LW_EffectArpeggioTable:
        ld a,b
        and #0b11111
PLY_LW_EffectArpeggioTable_AfterMask:
        ld PLY_LW_Data_OffsetIsArpeggioTableUsed (ix),a       ;Sets to 0 if the Arpeggio is stopped, or any other value if it starts.
        jr z,PLY_LW_EffectArpeggioTable_Stop

        ;Gets the Arpeggio address.
        add a,a
        exx
                ld l,a
                ld h,#0x00
;dknr3:
PLY_LW_PtArpeggios: ld bc,#0x0000
                add hl,bc
                ld a,(hl)
                inc hl
                ld PLY_LW_Data_OffsetPtArpeggioTable + 0 (ix),a
                ld a,(hl)
                ld PLY_LW_Data_OffsetPtArpeggioTable + 1 (ix),a
        exx

        ;Resets the offset of the Arpeggio, to force a restart.
        xor a
        ld PLY_LW_Data_OffsetPtArpeggioOffset (ix),a
        jp PLY_LW_RT_CellRead
PLY_LW_EffectArpeggioTable_Stop:
        ;Contrary to the Pitch, the Arpeggio must also be set to 0 when stopped.
        ld PLY_LW_Data_OffsetCurrentArpeggioValue (ix),a
        jp PLY_LW_RT_CellRead
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable

;Pitch table effect, activation or stop.
;This is exactly the same code as for the Arpeggio, but I can't find a way to share it...
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_LW_EffectPitchTable:
        ld a,b
        and #0b11111
PLY_LW_EffectPitchTable_AfterMask:
        ld PLY_LW_Data_OffsetIsPitchTableUsed (ix),a  ;Sets to 0 if the Pitch is stopped, or any other value if it starts.
        jp z,PLY_LW_RT_CellRead

        ;Gets the Pitch address.
        add a,a
        exx
                ld l,a
                ld h,#0x00
;dknr3:
PLY_LW_PtPitches: ld bc,#0x0000
                add hl,bc
                ld a,(hl)
                inc hl
                ld PLY_LW_Data_OffsetPtPitchTable + 0 (ix),a
                ld a,(hl)
                inc hl
                ld PLY_LW_Data_OffsetPtPitchTable + 1 (ix),a
        exx

        ;Resets the offset of the Pitch, to force a restart.
        xor a
        ld PLY_LW_Data_OffsetPtPitchOffset (ix),a

        jp PLY_LW_RT_CellRead
                       .endif ;PLY_CFG_UseEffect_PitchTable



;Volume, and Arpeggio Table, activation or stop.
                       .if PLY_LW_USE_Volume_And_ArpeggioTable_Effects       ;CONFIG SPECIFIC
PLY_LW_EffectVolumeArpeggioTable:
        ;Stores the new inverted volume.
        call PLY_LW_ReadInvertedVolumeFromB

        ;Manages the Arpeggio, encoded just after.
        ld a,(hl)
        inc hl
        or a            ;Required, else a volume of 0 will disturb the flag test after the jump!
        jr PLY_LW_EffectArpeggioTable_AfterMask
                       .endif ;PLY_LW_USE_Volume_And_ArpeggioTable_Effects

;Reset, and Arpeggio Table (activation only).
                       .if PLY_LW_USE_Reset_And_ArpeggioTable_Effects        ;CONFIG SPECIFIC
PLY_LW_EffectResetArpeggioTable:
        ;Resets effects and read volume.
        ;A bit of loss of CPU because we're going to set the Arpeggio just after, AND the effect pointer is stored!
        ;Oh well, less memory taken this way.
        call PLY_LW_EffectReset

        ;Reads the Arpeggio.
        ld a,(hl)
        inc hl
        or a            ;Required, else a volume of 0 will disturb the flag test after the jump!
        jp PLY_LW_EffectArpeggioTable_AfterMask         ;No need to use the mask, the value is clean.
                       .endif ;PLY_LW_USE_Reset_And_ArpeggioTable_Effects


;Reads the inverted volume from B, stored it after masking the bits in A.
PLY_LW_ReadInvertedVolumeFromB:
        ld a,b
        and #0b1111
        ld PLY_LW_Data_OffsetTrackInvertedVolume (ix),a
        ret

                       .endif ;PLY_CFG_UseEffects








;---------------------------------------------------------------------
;Data blocks for the three channels. Make sure NOTHING is added between, as the init clears everything!
;---------------------------------------------------------------------

;Data block for channel 1.
PLY_LW_Track1_Data:
;dkbs:
PLY_LW_Track1_WaitEmptyCell: .db #0x00                       ;How many empty cells have to be waited. 0 = none.
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
PLY_LW_Track1_Transposition: .db 0
                       .endif ;PLY_CFG_UseTranspositions
PLY_LW_Track1_BaseNote: .db #0x00                            ;Base note, such as the note played. The transposition IS included.
PLY_LW_Track1_InstrumentCurrentStep: .db #0x00               ;The current step on the Instrument (>=0, till it reaches the Speed).
PLY_LW_Track1_InstrumentSpeed: .db #0x00                     ;The Instrument speed (>=0).
PLY_LW_Track1_TrackInvertedVolume: .db 0
;dkbe:
;dkws:
PLY_LW_Track1_PtTrack: .dw #0x0000                             ;Points on the next Cell of the Track to read. Evolves.
PLY_LW_Track1_PtInstrument: .dw #0x0000                        ;Points on the Instrument, evolves.
PLY_LW_Track1_PtBaseInstrument: .dw #0x0000                    ;Points on the base of the Instrument, does not evolve.
;dkwe:
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
;dkbs:
PLY_LW_Track1_IsPitchUpDownUsed: .db #0x00                   ;>0 if a Pitch Up/Down is currently in use.
PLY_LW_Track1_TrackPitchDecimal: .db #0x00                   ;The decimal part of the Track pitch. Evolves as the pitch goes up/down.
dkbe:
dkws:
PLY_LW_Track1_TrackPitchSpeed: .dw #0x0000                     ;The integer and decimal part of the Track pitch speed. Is added to the Track Pitch every frame.
PLY_LW_Track1_TrackPitchInteger: .dw #0x0000                   ;The integer part of the Track pitch. Evolves as the pitch goes up/down.
dkwe:
;dkbs:
PLY_LW_Track1_IsArpeggioTableUsed: .db #0x00                 ;>0 if an Arpeggio Table is currently in use.
PLY_LW_Track1_PtArpeggioOffset: .db #0x00                    ;Increases over the Arpeggio.
PLY_LW_Track1_CurrentArpeggioValue: .db #0x00                ;Value from the Arpeggio to add to the base note. Read even if the Arpeggio effect is deactivated.
;dkbe:
;dkws:
PLY_LW_Track1_PtArpeggioTable: .dw #0x0000                     ;Point on the base of the Arpeggio table, does not evolve.
;dkwe:
;dkbs:
PLY_LW_Track1_IsPitchTableUsed: .db #0x00                    ;>0 if a Pitch Table is currently in use.
PLY_LW_Track1_PtPitchOffset: .db #0x00                       ;Increases over the Pitch.
;dkbe:
;dkws:
PLY_LW_Track1_CurrentPitchTableValue: .dw #0x0000              ;16 bit value from the Pitch to add to the base note. Not read if the Pitch effect is deactivated.
PLY_LW_Track1_PtPitchTable: .dw #0x0000                        ;Points on the base of the Pitch table, does not evolve.
;dkwe:
                       .endif ;PLY_CFG_UseEffects
PLY_LW_Track1_Data_End:

.equ PLY_LW_Track1_Data_Size  , PLY_LW_Track1_Data_End - PLY_LW_Track1_Data

.equ PLY_LW_Data_OffsetWaitEmptyCell                , PLY_LW_Track1_WaitEmptyCell - PLY_LW_Track1_Data
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
.equ PLY_LW_Data_OffsetTransposition                , PLY_LW_Track1_Transposition - PLY_LW_Track1_Data
                       .endif ;PLY_CFG_UseTranspositions

.equ PLY_LW_Data_OffsetPtTrack                      , PLY_LW_Track1_PtTrack - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetBaseNote                     , PLY_LW_Track1_BaseNote - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtInstrument                 , PLY_LW_Track1_PtInstrument - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtBaseInstrument             , PLY_LW_Track1_PtBaseInstrument - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetInstrumentCurrentStep        , PLY_LW_Track1_InstrumentCurrentStep - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetInstrumentSpeed              , PLY_LW_Track1_InstrumentSpeed - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetTrackInvertedVolume          , PLY_LW_Track1_TrackInvertedVolume - PLY_LW_Track1_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
                               .if PLY_LW_USE_EffectPitchUpDown      ;CONFIG SPECIFIC
.equ PLY_LW_Data_OffsetIsPitchUpDownUsed            , PLY_LW_Track1_IsPitchUpDownUsed - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetTrackPitchInteger            , PLY_LW_Track1_TrackPitchInteger - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetTrackPitchDecimal            , PLY_LW_Track1_TrackPitchDecimal - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetTrackPitchSpeed              , PLY_LW_Track1_TrackPitchSpeed - PLY_LW_Track1_Data
                               .endif ;PLY_LW_USE_EffectPitchUpDown
                               .if PLY_CFG_UseEffect_ArpeggioTable ;CONFIG SPECIFIC
.equ PLY_LW_Data_OffsetIsArpeggioTableUsed          , PLY_LW_Track1_IsArpeggioTableUsed - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtArpeggioTable              , PLY_LW_Track1_PtArpeggioTable - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtArpeggioOffset             , PLY_LW_Track1_PtArpeggioOffset - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetCurrentArpeggioValue         , PLY_LW_Track1_CurrentArpeggioValue - PLY_LW_Track1_Data
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                               .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
.equ PLY_LW_Data_OffsetIsPitchTableUsed             , PLY_LW_Track1_IsPitchTableUsed - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtPitchTable                 , PLY_LW_Track1_PtPitchTable - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetCurrentPitchTableValue       , PLY_LW_Track1_CurrentPitchTableValue - PLY_LW_Track1_Data
.equ PLY_LW_Data_OffsetPtPitchOffset                , PLY_LW_Track1_PtPitchOffset - PLY_LW_Track1_Data
                               .endif ;PLY_CFG_UseEffect_PitchTable
                       .endif ;PLY_CFG_UseEffects

;Data block for channel 2.
PLY_LW_Track2_Data:
;       .ds PLY_LW_Track1_Data_Size

        .db 0
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        .db 0
                       .endif ;PLY_CFG_UseTranspositions
        .db 0,0,0,0,0,0,0,0,0,0
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        .db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                       .endif ;PLY_CFG_UseEffects

PLY_LW_Track2_Data_End:
.equ PLY_LW_Track2_WaitEmptyCell  , PLY_LW_Track2_Data + PLY_LW_Data_OffsetWaitEmptyCell
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
.equ PLY_LW_Track2_Transposition  , PLY_LW_Track2_Data + PLY_LW_Data_OffsetTransposition
                       .endif ;PLY_CFG_UseTranspositions

.equ PLY_LW_Track2_PtTrack  , PLY_LW_Track2_Data + PLY_LW_Data_OffsetPtTrack
.equ PLY_LW_Track2_PtInstrument  , PLY_LW_Track2_Data + PLY_LW_Data_OffsetPtInstrument

;Data block for channel 3.
PLY_LW_Track3_Data:
;       .ds PLY_LW_Track1_Data_Size
        .db 0
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        .db 0
                       .endif ;PLY_CFG_UseTranspositions
        .db 0,0,0,0,0,0,0,0,0,0
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        .db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                       .endif ;PLY_CFG_UseEffects
PLY_LW_Track3_Data_End:
.equ PLY_LW_Track3_WaitEmptyCell  , PLY_LW_Track3_Data + PLY_LW_Data_OffsetWaitEmptyCell
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
.equ PLY_LW_Track3_Transposition  , PLY_LW_Track3_Data + PLY_LW_Data_OffsetTransposition
                       .endif ;PLY_CFG_UseTranspositions
.equ PLY_LW_Track3_PtTrack  , PLY_LW_Track3_Data + PLY_LW_Data_OffsetPtTrack
.equ PLY_LW_Track3_PtInstrument  , PLY_LW_Track3_Data + PLY_LW_Data_OffsetPtInstrument

;        ;Makes sure the structure all have the same size!
;        ASSERT (PLY_LW_Track1_Data_End - PLY_LW_Track1_Data) == (PLY_LW_Track2_Data_End - PLY_LW_Track2_Data)
;        ASSERT (PLY_LW_Track1_Data_End - PLY_LW_Track1_Data) == (PLY_LW_Track3_Data_End - PLY_LW_Track3_Data)
;        ;No holes between the blocks, the init makes a LDIR to clear everything!
;        ASSERT PLY_LW_Track1_Data_End == PLY_LW_Track2_Data
;        ASSERT PLY_LW_Track2_Data_End == PLY_LW_Track3_Data



;---------------------------------------------------------------------
;Register block for all the channels. They are "polluted" with pointers to code because all this
;is actually a RET table!
;---------------------------------------------------------------------
;DB register, DB value then.dw code to jump to once the value is read.
PLY_LW_Registers_RetTable:
PLY_LW_Track1_Registers:
       .db 8
PLY_LW_Track1_Volume: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 0
PLY_LW_Track1_SoftwarePeriodLSB: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 1
PLY_LW_Track1_SoftwarePeriodMSB: .db 0
       .dw PLY_LW_SendPsgRegister

PLY_LW_Track2_Registers:
       .db 9
PLY_LW_Track2_Volume: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 2
PLY_LW_Track2_SoftwarePeriodLSB: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 3
PLY_LW_Track2_SoftwarePeriodMSB: .db 0
       .dw PLY_LW_SendPsgRegister

PLY_LW_Track3_Registers:
       .db 10
PLY_LW_Track3_Volume: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 4
PLY_LW_Track3_SoftwarePeriodLSB: .db 0
       .dw PLY_LW_SendPsgRegister
       .db 5
PLY_LW_Track3_SoftwarePeriodMSB: .db 0
       .dw PLY_LW_SendPsgRegister

;Generic registers.
                       .if PLY_LW_USE_NoiseRegister + PLY_LW_USE_NoiseRegisterS         ;CONFIG SPECIFIC
       .db 6
PLY_LW_NoiseRegister: .db 0
       .dw PLY_LW_SendPsgRegister
                       .endif ;PLY_LW_USE_NoiseRegister

       .db 7
PLY_LW_MixerRegister: .db 0
    .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
       .dw PLY_LW_SendPsgRegister
       .db 11
PLY_LW_Reg11:  .db 0
       .dw PLY_LW_SendPsgRegister
       .db 12
PLY_LW_Reg12:  .db 0
       .dw PLY_LW_SendPsgRegisterR13
        ;This one is a trick to send the register after R13 is managed.
       .dw PLY_LW_SendPsgRegisterAfterPop

       .dw PLY_LW_SendPsgRegisterEnd
    .else
       .dw PLY_LW_SendPsgRegisterEnd
    .endif ;PLY_CFG_UseHardwareSounds



.equ PLY_LW_Registers_OffsetVolume             , PLY_LW_Track1_Volume - PLY_LW_Track1_Registers
.equ PLY_LW_Registers_OffsetSoftwarePeriodLSB  , PLY_LW_Track1_SoftwarePeriodLSB - PLY_LW_Track1_Registers
.equ PLY_LW_Registers_OffsetSoftwarePeriodMSB  , PLY_LW_Track1_SoftwarePeriodMSB - PLY_LW_Track1_Registers

;The period table for each note (from 0 to 127 included).
PLY_LW_PeriodTable:
;dkws
       .if PLY_LW_HARDWARE_CPC + PLY_LW_HARDWARE_ENTERPRISE
        ;PSG running to 1000000 Hz.
       .dw 3822,3608,3405,3214,3034,2863,2703,2551,2408,2273,2145,2025          ;0
       .dw 1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073,1012          ;12
       .dw 956,902,851,804,758,716,676,638,602,568,536,506                      ;24
       .dw 478,451,426,402,379,358,338,319,301,284,268,253                      ;36
       .dw 239,225,213,201,190,179,169,159,150,142,134,127                      ;48
       .dw 119,113,106,100,95,89,84,80,75,71,67,63                              ;60
       .dw 60,56,53,50,47,45,42,40,38,36,34,32                                  ;72
       .dw 30,28,27,25,24,22,21,20,19,18,17,16                                  ;84
       .dw 15,14,13,13,12,11,11,10,9,9,8,8                                      ;96
       .dw 7,7,7,6,6,6,5,5,5,4,4,4                                              ;108
       .dw 4,4,3,3,3,3,3,2 ;,2,2,2,2                                            ;120 -> 127
       .endif

       .if PLY_LW_HARDWARE_SPECTRUM + PLY_LW_HARDWARE_MSX
        ;PSG running to 1773400 Hz.
       .dw 6778, 6398, 6039, 5700, 5380, 5078, 4793, 4524, 4270, 4030, 3804, 3591	; Octave 0
       .dw 3389, 3199, 3019, 2850, 2690, 2539, 2397, 2262, 2135, 2015, 1902, 1795	; Octave 1
       .dw 1695, 1599, 1510, 1425, 1345, 1270, 1198, 1131, 1068, 1008, 951, 898	; Octave 2
       .dw 847, 800, 755, 712, 673, 635, 599, 566, 534, 504, 476, 449	; Octave 3
       .dw 424, 400, 377, 356, 336, 317, 300, 283, 267, 252, 238, 224	; Octave 4
       .dw 212, 200, 189, 178, 168, 159, 150, 141, 133, 126, 119, 112	; Octave 5
       .dw 106, 100, 94, 89, 84, 79, 75, 71, 67, 63, 59, 56	; Octave 6
       .dw 53, 50, 47, 45, 42, 40, 37, 35, 33, 31, 30, 28	; Octave 7
       .dw 26, 25, 24, 22, 21, 20, 19, 18, 17, 16, 15, 14	; Octave 8
       .dw 13, 12, 12, 11, 11, 10, 9, 9, 8, 8, 7, 7	; Octave 9
       .dw 7, 6, 6, 6, 5, 5, 5, 4	; Octave 10
       .endif

       .if PLY_LW_HARDWARE_PENTAGON
        ;PSG running to 1750000 Hz.
       .dw 6689, 6314, 5959, 5625, 5309, 5011, 4730, 4464, 4214, 3977, 3754, 3543	; Octave 0
       .dw 3344, 3157, 2980, 2812, 2655, 2506, 2365, 2232, 2107, 1989, 1877, 1772	; Octave 1
       .dw 1672, 1578, 1490, 1406, 1327, 1253, 1182, 1116, 1053, 994, 939, 886	; Octave 2
       .dw 836, 789, 745, 703, 664, 626, 591, 558, 527, 497, 469, 443	; Octave 3
       .dw 418, 395, 372, 352, 332, 313, 296, 279, 263, 249, 235, 221	; Octave 4
       .dw 209, 197, 186, 176, 166, 157, 148, 140, 132, 124, 117, 111	; Octave 5
       .dw 105, 99, 93, 88, 83, 78, 74, 70, 66, 62, 59, 55	; Octave 6
       .dw 52, 49, 47, 44, 41, 39, 37, 35, 33, 31, 29, 28	; Octave 7
       .dw 26, 25, 23, 22, 21, 20, 18, 17, 16, 16, 15, 14	; Octave 8
       .dw 13, 12, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7	; Octave 9
       .dw 7, 6, 6, 5, 5, 5, 5, 4	; Octave 10
       .endif
;dkwe
PLY_LW_End:


   ;PLY_UseEnterprise_End 

