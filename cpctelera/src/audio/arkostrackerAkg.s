;       Arkos Tracker 2 player "generic" player.
;       By Targhan/Arkos.
;       Psg optimization trick on CPC by Madram/Overlanders.
;
;       This compiles with RASM. Check the compatibility page on the Arkos Tracker 2 website, it contains a source converter to any Z80 assembler!
;
;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.
;
;       Target hardware:
;       ---------------
;       This code can target Amstrad CPC, MSX, Spectrum and Pentagon. By default, it targets Amstrad CPC.
;       Simply use one of the follow line (BEFORE this player):
;       PLY_AKG_HARDWARE_CPC = 1
;       PLY_AKG_HARDWARE_MSX = 1
;       PLY_AKG_HARDWARE_SPECTRUM = 1
;       PLY_AKG_HARDWARE_PENTAGON = 1
;       Note that the PRESENCE of this variable is tested, NOT its value.
;
;       ROM
;       ----------------------
;       To use a ROM player (no automodification, use of a small buffer to put in RAM):
;       PLY_AKG_ROM = 1
;       PLY_AKG_ROM_Buffer = #4000 (or wherever).
;       This makes the player a bit slower and slightly bigger.
;       The buffer is PLY_AKG_ROM_BufferSize long (=250 max). You can hardcode this value, because it is calculated, so it won't be accessible before this player is assembled.
;       This value decreases when you use player configuration, but increases if you use sound effects.
;
;       Optimizations:
;       --------------
;       - Use the Player Configuration of Arkos Tracker 2 to generate a configuration file to be included at the beginning of this player.
;         It will disable useless features according to your songs, saving for memory and CPU! Check the manual for more details, or more simply the testers.
;       - Set PLY_AKG_USE_HOOKS to 0 to remove the three hooks just below to save 9 bytes (yay!).
;       - Set PLY_AKG_STOP_SOUNDS to 0 if you don't intent to stop the music via the PLY_AKG_Stop method.
;       - If you play your song "one shot" (i.e. without restarting it again), you can set the PLY_AKG_FULL_INIT_CODE to 0, some
;         initialization code will not be assembled.

;       Sound effects:
;       --------------
;       Sound effects are disabled by default. Declare PLY_AKG_MANAGE_SOUND_EFFECTS to enable it:
;       PLY_AKG_MANAGE_SOUND_EFFECTS = 1
;       Check the sound effect tester to see how it enables it.
;       Note that the PRESENCE of this variable is tested, NOT its value.

;       Additional note:
;       - There can be a slightly difference when using volume in/out effects compared to the PC side, because the volume management is
;         different. This means there can be a difference of 1 at certain frames. As it shouldn't be a bother, I let it this way.
;         This allows the Z80 code to be faster and simpler.
;
;       -------------------------------------------------------

; _main::
.module cpct_audio
        .include "../../CPCteleraHW.src"
        .include "arkostrackerAkg_var.src"

PLY_AKG_Start:
 
.equ PLY_AKG_Rom ,     0
;A nice trick to manage the offset using the same instructions, according to the player (ROM or not).
       .if PLY_AKG_Rom
.equ PLY_AKG_Offset1b , 0
.equ PLY_AKG_Offset2b , 0         ;Used for instructions such as ld iyh,xx
       .else
.equ PLY_AKG_Offset1b , 1
.equ PLY_AKG_Offset2b , 2
       .endif

       .ifeq PLY_AKG_Rom
.equ PLY_AKG_OPCODE_OR_A , #0xb7                        ;Opcode for "or a".
.equ PLY_AKG_OPCODE_SCF , #0x37                         ;Opcode for "scf".
       .else
        ;Another trick for the ROM player. The original opcodes are converted to number, which will be multiplied by 2, provoking a carry or not.
.equ PLY_AKG_OPCODE_OR_A , 0                          ;0 * 2 = 0, no carry.
.equ PLY_AKG_OPCODE_SCF , #0xff                         ;255 * 2 = carry.
.equ PLY_AKG_OPCODE_JP , #0xc3
       .endif

.equ PLY_AKG_OPCODE_ADD_HL_BC_LSB , #0x09               ;Opcode for "add hl,bc", LSB.
.equ PLY_AKG_OPCODE_ADD_HL_BC_MSB , #0x00               ;Opcode for "add hl,bc", MSB (fake, it is only 8 bits).
.equ PLY_AKG_OPCODE_SBC_HL_BC_LSB , #0x42               ;Opcode for "sbc hl,bc", LSB.
.equ PLY_AKG_OPCODE_SBC_HL_BC_MSB , #0xed               ;Opcode for "sbc hl,bc", MSB.
.equ PLY_AKG_OPCODE_INC_HL , #0x23                      ;Opcode for "inc hl".
.equ PLY_AKG_OPCODE_DEC_HL , #0x2b                      ;Opcode for "dec hl".
.equ PLY_AKG_OPCODE_ADD_A_IMMEDIATE , #0xc6             ;Opcode for "add a,x".
.equ PLY_AKG_OPCODE_SUB_IMMEDIATE , #0xd6               ;Opcode for "sub x".
        
        ;Hooks for external calls. Can be removed if not needed.
       .if PLY_AKG_USE_HOOKS
                jp PLY_AKG_Init                         ;PLY_AKG_Start + 0.
                jp PLY_AKG_Play                         ;PLY_AKG_Start + 3.
               .if PLY_AKG_STOP_SOUNDS
                        jp PLY_AKG_Stop                         ;PLY_AKG_Start + 6.
               .endif ;PLY_AKG_STOP_SOUNDS
       .endif ;PLY_AKG_USE_HOOKS

        ;Includes the sound effects player, if wanted. Important to do it as soon as possible, so that
        ;its code can react to the Player Configuration and possibly alter it.
       .if PLY_AKG_MANAGE_SOUND_EFFECTS
               .include "arkostrackerAkg_SoundEffects.src"
       .endif ;PLY_AKG_MANAGE_SOUND_EFFECTS
        ;[[INSERT_SOUND_EFFECT_SOURCE]]                 ;A tag for test units. Don't touch or you're dead.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKG_musicInit
;;
;;    Sets up a music into Arkos Tracker Player to be played later on with
;; <cpct_akpAKG_musicPlay>.
;;
;; C Definition:
;;    void <cpct_akpAKG_musicInit> (void* *songdata*, song number)
;;
;; Input Parameters (2 bytes):
;;    (2B HL) songdata - Pointer to the start of the array containing song's data in AKS binary format
;;    (1B A) song number
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKG_musicInit_asm
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

_cpct_akpAKG_musicInit::
   ld   hl, #2    ;; [10] Retrieve parameters from stack
   add  hl, sp    ;; [11]
   ld    e, (hl)  ;; [ 7] DE = Pointer to the start of music
   inc  hl        ;; [ 6]
   ld    d, (hl)  ;; [ 7]
   inc  hl
   ld    a, (hl)
   ex   de,hl
cpct_akpAKG_musicInit_asm::   ;; Entry point for assembly calls using registers for parameter passing 

;Initializes the player.
;IN:    HL = music address.
;       A = subsong index (>=0).
PLY_AKG_InitDisarkGenerateExternalLabel:
PLY_AKG_Init:
        
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        ;Skips the tag.
        ld de,#0x0004
        add hl,de
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld de,#PLY_AKG_ArpeggiosTable + PLY_AKG_Offset1b
        ldi
        ldi
                               .else
                inc hl
                inc hl
                               .endif
                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld de,#PLY_AKG_PitchesTable + PLY_AKG_Offset1b
        ldi
        ldi
                               .else
                inc hl
                inc hl
                               .endif ;PLY_CFG_UseEffect_PitchTable
                       .else
                ;No effects. Skips the tag and the arp/pitch table.
        ld de,#0x0004 + 2 + 2
        add hl,de
                       .endif ;PLY_CFG_UseEffects
        ld de,#PLY_AKG_InstrumentsTable + PLY_AKG_Offset1b
        ldi
        ldi
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (PLY_AKG_Channel_ReadEffects_EffectBlocks1 + PLY_AKG_Offset1b),bc
                               .ifeq PLY_AKG_Rom
        ;Not used in ROM, the same value is used.
        ld (PLY_AKG_Channel_ReadEffects_EffectBlocks2 + PLY_AKG_Offset1b),bc
                               .endif
                       .else
                ;No effects. Skips the effect block table.
                inc hl
                inc hl
                       .endif ;PLY_CFG_UseEffects

        
        ;We have reached the Subsong addresses. Which one to use?
        add a,a
        ld e,a
        ld d,#0x00
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ;HL points on the Subsong metadata.
        ld de,#0x0005         ;Skips the replay frequency, digichannel, psg count, loop ^art index, end index.
        add hl,de
        ld de,#PLY_AKG_CurrentSpeed + PLY_AKG_Offset1b       ;Reads the initial speed (>0).
        ldi
        ld de,#PLY_AKG_BaseNoteIndex + PLY_AKG_Offset1b      ;Reads the base note of the note that is considered "optimized", contrary to "escaped".
        ldi
        ld (PLY_AKG_ReadLinker_PtLinker + PLY_AKG_Offset1b),hl

        ;Initializes values. You can remove this part if you don't stop/restart your song.
       .if PLY_AKG_FULL_INIT_CODE
                ld hl,#PLY_AKG_InitTable0
                ld bc,#((PLY_AKG_InitTable0_End - PLY_AKG_InitTable0) / 2 + 1) * 256 + 0
                call PLY_AKG_Init_ReadWordsAndFill
                inc c
                ld hl,#PLY_AKG_InitTable1
                ld b,#(PLY_AKG_InitTable1_End - PLY_AKG_InitTable1) / 2 + 1
                call PLY_AKG_Init_ReadWordsAndFill
                ld hl,#PLY_AKG_InitTableOrA
                ld bc,#((PLY_AKG_InitTableOrA_End - PLY_AKG_InitTableOrA) / 2 + 1) * 256 + PLY_AKG_OPCODE_OR_A
                call PLY_AKG_Init_ReadWordsAndFill
                
               .if PLY_AKG_Rom
                        ;The ROM version requires a bit more of setup.        
                        ld hl,#PLY_AKG_InitTableJp
                        ld bc,#((PLY_AKG_InitTableJp_End - PLY_AKG_InitTableJp) / 2 + 1) * 256 + PLY_AKG_OPCODE_JP
                        call PLY_AKG_Init_ReadWordsAndFill
               .endif
                
                       .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
                ld a,#0xff
                ld (PLY_AKG_PSGReg13_OldValue + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseRetrig
       .endif

        ;Stores the address to the empty instrument *data* (header skipped).
        ld hl,(PLY_AKG_InstrumentsTable + PLY_AKG_Offset1b)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        inc hl                  ;Skips the header.
        ld (PLY_AKG_EmptyInstrumentDataPt + PLY_AKG_Offset1b),hl
        ;Sets all the instrument to "empty".
        ld (PLY_AKG_Channel1_PtInstrument + PLY_AKG_Offset1b),hl
        ld (PLY_AKG_Channel2_PtInstrument + PLY_AKG_Offset1b),hl
        ld (PLY_AKG_Channel3_PtInstrument + PLY_AKG_Offset1b),hl
        
        ;The ROM version requires a bit more of setup.        
       .if PLY_AKG_Rom
               .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide            ;CONFIG SPECIFIC
                        xor a
                                ;In the non-ROM code, the MSB is always 0, the LSB is updated. The MSB must be reset for ROM version.
                                ld (PLY_AKG_Channel1_PitchTrack + 1),a
                        
                                ld hl,#PLY_AKG_Channel1_PitchTrackIntegerAddOrSubReturn
                                ld (PLY_AKG_Channel1_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress + 1),hl
                                ld hl,#PLY_AKG_Channel1_PitchTrackAddOrSbc_16bitsReturn
                                ld (PLY_AKG_Channel1_PitchTrackAfterAddOrSbcJumpInstrAndAddress + 1),hl
                                
                                ld hl,#PLY_AKG_Channel1_PitchTrackDecimalInstrAndValueReturnAfterJp
                                ld (PLY_AKG_Channel1_PitchTrackDecimalInstrAndValueReturnJp + 1),hl
                                ;In the non-ROM code, the MSB is always 0, the LSB is updated. The MSB must be reset for ROM version.
                                ld (PLY_AKG_Channel2_PitchTrack + 1),a
                        
                                ld hl,#PLY_AKG_Channel2_PitchTrackIntegerAddOrSubReturn
                                ld (PLY_AKG_Channel2_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress + 1),hl
                                ld hl,#PLY_AKG_Channel2_PitchTrackAddOrSbc_16bitsReturn
                                ld (PLY_AKG_Channel2_PitchTrackAfterAddOrSbcJumpInstrAndAddress + 1),hl
                                
                                ld hl,#PLY_AKG_Channel2_PitchTrackDecimalInstrAndValueReturnAfterJp
                                ld (PLY_AKG_Channel2_PitchTrackDecimalInstrAndValueReturnJp + 1),hl
                                ;In the non-ROM code, the MSB is always 0, the LSB is updated. The MSB must be reset for ROM version.
                                ld (PLY_AKG_Channel3_PitchTrack + 1),a
                        
                                ld hl,#PLY_AKG_Channel3_PitchTrackIntegerAddOrSubReturn
                                ld (PLY_AKG_Channel3_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress + 1),hl
                                ld hl,#PLY_AKG_Channel3_PitchTrackAddOrSbc_16bitsReturn
                                ld (PLY_AKG_Channel3_PitchTrackAfterAddOrSbcJumpInstrAndAddress + 1),hl
                                
                                ld hl,#PLY_AKG_Channel3_PitchTrackDecimalInstrAndValueReturnAfterJp
                                ld (PLY_AKG_Channel3_PitchTrackDecimalInstrAndValueReturnJp + 1),hl
               .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
       .endif
        
        ;If sound effects, clears the SFX state.
       .if PLY_AKG_MANAGE_SOUND_EFFECTS
                ld hl,#0x0000
                ld (PLY_AKG_Channel1_SoundEffectData),hl
                ld (PLY_AKG_Channel2_SoundEffectData),hl
                ld (PLY_AKG_Channel3_SoundEffectData),hl
       .endif ;PLY_AKG_MANAGE_SOUND_EFFECTS
        
   .if HARDWARE_ENTERPRISE
        jp     ayReset
   .else
        ret
   .endif


       .if PLY_AKG_FULL_INIT_CODE
;Fills all the read addresses with a byte.
;IN:    HL = table where the addresses are.
;       B = how many items in the table + 1.
;       C = byte to fill.
PLY_AKG_Init_ReadWordsAndFill_Loop:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,c
        ld (de),a
PLY_AKG_Init_ReadWordsAndFill:
        djnz PLY_AKG_Init_ReadWordsAndFill_Loop
        ret

;Table initializing some data with 0.
PLY_AKG_InitTable0:
       .dw PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1  ;PLY_AKG_Offset2b must NOT be used here.
       .dw PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1
       .dw PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
       .dw PLY_AKG_Channel1_Pitch + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel1_Pitch + PLY_AKG_Offset1b + 1
       .dw PLY_AKG_Channel2_Pitch + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel2_Pitch + PLY_AKG_Offset1b + 1
       .dw PLY_AKG_Channel3_Pitch + PLY_AKG_Offset1b
       .dw PLY_AKG_Channel3_Pitch + PLY_AKG_Offset1b + 1
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
                       .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
       .dw PLY_AKG_Retrig + 1
                       .endif ;PLY_CFG_UseRetrig
PLY_AKG_InitTable0_End:

PLY_AKG_InitTable1:
       .dw PLY_AKG_PatternDecreasingHeight + PLY_AKG_Offset1b
       .dw PLY_AKG_TickDecreasingCounter + PLY_AKG_Offset1b
PLY_AKG_InitTable1_End:

PLY_AKG_InitTableOrA:
                       .if PLY_AKG_UseEffect_VolumeSlide             ;CONFIG SPECIFIC
       .dw PLY_AKG_Channel1_IsVolumeSlide
       .dw PLY_AKG_Channel2_IsVolumeSlide
       .dw PLY_AKG_Channel3_IsVolumeSlide
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .dw PLY_AKG_Channel1_IsArpeggioTable
       .dw PLY_AKG_Channel2_IsArpeggioTable
       .dw PLY_AKG_Channel3_IsArpeggioTable
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
       .dw PLY_AKG_Channel1_IsPitchTable
       .dw PLY_AKG_Channel2_IsPitchTable
       .dw PLY_AKG_Channel3_IsPitchTable
                       .endif ;PLY_CFG_UseEffect_PitchTable
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
       .dw PLY_AKG_Channel1_IsPitch
       .dw PLY_AKG_Channel2_IsPitch
       .dw PLY_AKG_Channel3_IsPitch
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
PLY_AKG_InitTableOrA_End:
       .endif           ;PLY_AKG_FULL_INIT_CODE

       .if PLY_AKG_Rom
PLY_AKG_InitTableJp:
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
       .dw PLY_AKG_Channel1_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress
       .dw PLY_AKG_Channel2_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress
       .dw PLY_AKG_Channel3_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress
       .dw PLY_AKG_Channel1_PitchTrackAfterAddOrSbcJumpInstrAndAddress
       .dw PLY_AKG_Channel2_PitchTrackAfterAddOrSbcJumpInstrAndAddress
       .dw PLY_AKG_Channel3_PitchTrackAfterAddOrSbcJumpInstrAndAddress
       .dw PLY_AKG_Channel1_PitchTrackDecimalInstrAndValueReturnJp
       .dw PLY_AKG_Channel2_PitchTrackDecimalInstrAndValueReturnJp
       .dw PLY_AKG_Channel3_PitchTrackDecimalInstrAndValueReturnJp
       .endif
        
       .if PLY_CFG_UseEffects
       .dw PLY_AKG_Channel_ReadEffects_EndJumpInstrAndAddress
       .endif
       .dw PLY_AKG_TempPlayInstrumentJumpInstrAndAddress
PLY_AKG_InitTableJp_End:
       .endif

       .if PLY_AKG_STOP_SOUNDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKG_stop
;;
;;    Stops playing musing and sound effects on all 3 channels.
;;
;; C Definition:
;;    void <cpct_akpAKG_stop> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKG_stop_asm
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
_cpct_akpAKG_stop::
cpct_akpAKG_stop_asm::  ;; Entry point for assembly calls   
;Stops the music. This code can be removed if you don't intend to stop it!
PLY_AKG_StopDisarkGenerateExternalLabel:
PLY_AKG_Stop:
        ld (PLY_AKG_SaveSP + PLY_AKG_Offset1b),sp              ;Only useful because the PLY_AKG_SendPSGRegisters restores it at the end.
        
        ;All the volumes to 0, all sound/noise channels stopped.
        xor a
        ld l,a
        ld h,a
        ld (PLY_AKG_PSGReg8),a
        ld (PLY_AKG_PSGReg9_10_Instr + PLY_AKG_Offset1b),hl
       .if PLY_AKG_HARDWARE_MSX
                ld a,#0b10111111          ;On MSX, bit 7 must be 1, bit 6 0.
       .else
                ld a,#0b00111111          ;On CPC, bit 6 must be 0. Other platforms don't care.
       .endif
        jp PLY_AKG_SendPSGRegisters
       .endif ;PLY_AKG_STOP_SOUNDS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKG_musicPlay
;;
;;    Plays next music cycle of the present song with Arkos Tracker Player. Song 
;; has had to be previously established with <cpct_akp_musicInit>.
;;
;; C Definition:
;;    void <cpct_akpAKG_musicPlay> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKG_musicPlay_asm
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

_cpct_akpAKG_musicPlay::
cpct_akpAKG_musicPlay_asm::   ;; Entry point for assembly calls   

;Plays one frame of the subsong.
PLY_AKG_PlayDisarkGenerateExternalLabel:
PLY_AKG_Play:
        ld (PLY_AKG_SaveSP + PLY_AKG_Offset1b),sp

                       .if PLY_CFG_UseEventTracks            ;CONFIG SPECIFIC
        xor a
        ld (PLY_AKG_Event),a
                       .endif ;PLY_CFG_UseEventTracks

        ;Decreases the tick counter. If 0 is reached, a new line must be read.
       .ifeq PLY_AKG_Rom
PLY_AKG_TickDecreasingCounter: ld a,#0x01
       .else
        ld a,(PLY_AKG_TickDecreasingCounter)
       .endif
        dec a
        jp nz,PLY_AKG_SetSpeedBeforePlayStreams                 ;Jumps if there is no new line: continues playing the sound stream.

        ;New line! Is the Pattern ended? Not as long as there are lines to read.
       .ifeq PLY_AKG_Rom
PLY_AKG_PatternDecreasingHeight: ld a,#0x01
       .else
        ld a,(PLY_AKG_PatternDecreasingHeight)
       .endif
        dec a
        jr nz,PLY_AKG_SetCurrentLineBeforeReadLine  ;Jumps if the pattern isn't ended.

        ;New pattern!
        ;Reads the Linker. This is called at the start of the song, or at the end of every position.
PLY_AKG_ReadLinker:
       .ifeq PLY_AKG_Rom

PLY_AKG_ReadLinker_PtLinker: ld sp,#0x0000
       .else
        ld sp,(PLY_AKG_ReadLinker_PtLinker)
       .endif
        ;Reads the address of each Track.
        pop hl
        ld a,l
        or h
        jr nz,PLY_AKG_ReadLinker_NoLoop         ;Reached the end of the song?
        ;End of the song.
        pop hl          ;HL is the loop address.
        ld sp,hl
        pop hl          ;Reads once again the address of Track 1, in the pattern looped to.
PLY_AKG_ReadLinker_NoLoop:
        ld (PLY_AKG_Channel1_PtTrack + PLY_AKG_Offset1b),hl
        pop hl
        ld (PLY_AKG_Channel2_PtTrack + PLY_AKG_Offset1b),hl
        pop hl
        ld (PLY_AKG_Channel3_PtTrack + PLY_AKG_Offset1b),hl
        ;Reads the address of the LinkerBlock.
        pop hl
        ld (PLY_AKG_ReadLinker_PtLinker + PLY_AKG_Offset1b),sp
        ld sp,hl

        ;Reads the LinkerBlock. SP = LinkerBlock.
        ;Reads the height and transposition1.
        pop hl
        ld c,l                                ;Stores the pattern height, used below.
                       .if PLY_CFG_UseTranspositions            ;CONFIG SPECIFIC
        ld a,h
        ld (PLY_AKG_Channel1_Transposition + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseTranspositions
        ;Reads the transposition2 and 3.
                       .if PLY_AKG_UseSpecialTracks                  ;CONFIG SPECIFIC
                               .ifeq PLY_CFG_UseTranspositions            ;CONFIG SPECIFIC
                                ;Transpositions not used? We could stop here. BUT the SpecialTracks, if present, must access their data after.
                                ;So in this case, the transpositions must be skipped.
                                pop hl
                               .endif ;PLY_CFG_UseTranspositions
                       .endif ;PLY_AKG_UseSpecialTracks
                       .if PLY_CFG_UseTranspositions            ;CONFIG SPECIFIC
        pop hl
        ld a,l
        ld (PLY_AKG_Channel2_Transposition + PLY_AKG_Offset1b),a
        ld a,h
        ld (PLY_AKG_Channel3_Transposition + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseTranspositions
                       .if PLY_AKG_UseSpecialTracks                  ;CONFIG SPECIFIC
        ;Reads the special Tracks addresses.
        pop hl          ;Must be performed even SpeedTracks not used, because EventTracks might be present, the word must be skipped.
                               .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC
        ld (PLY_AKG_SpeedTrack_PtTrack + PLY_AKG_Offset1b),hl
                               .endif ;PLY_CFG_UseSpeedTracks
        
                               .if PLY_CFG_UseEventTracks            ;CONFIG SPECIFIC
        pop hl
        ld (PLY_AKG_EventTrack_PtTrack + PLY_AKG_Offset1b),hl
                               .endif ;PLY_CFG_UseEventTracks
                       .endif ;PLY_AKG_UseSpecialTracks

        xor a
        ;Forces the reading of every Track and Special Track.
                       .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC
        ld (PLY_AKG_SpeedTrack_WaitCounter + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseSpeedTracks
                       .if PLY_CFG_UseEventTracks            ;CONFIG SPECIFIC
        ld (PLY_AKG_EventTrack_WaitCounter + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEventTracks
        ld (PLY_AKG_Channel1_WaitCounter + PLY_AKG_Offset1b),a
        ld (PLY_AKG_Channel2_WaitCounter + PLY_AKG_Offset1b),a
        ld (PLY_AKG_Channel3_WaitCounter + PLY_AKG_Offset1b),a
        ld a,c
PLY_AKG_SetCurrentLineBeforeReadLine:
        ld (PLY_AKG_PatternDecreasingHeight + PLY_AKG_Offset1b),a


        ;Reads the new line (notes, effects, Special Tracks, etc.).
PLY_AKG_ReadLine:
        ;Reads the Speed Track.
                       .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC
        ;-------------------------------------------------------------------
       .ifeq PLY_AKG_Rom
PLY_AKG_SpeedTrack_WaitCounter: ld a,#0x00      ;Lines to wait?
       .else
        ld a,(PLY_AKG_SpeedTrack_WaitCounter)
       .endif
        sub #0x01
        jr nc,PLY_AKG_SpeedTrack_MustWait       ;Jump if there are still lines to wait.
        ;No more lines to wait. Reads a new data. It may be an event value or a wait value.
       .ifeq PLY_AKG_Rom

PLY_AKG_SpeedTrack_PtTrack: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_SpeedTrack_PtTrack)
       .endif
        ld a,(hl)
        inc hl
        srl a           ;Bit 0: wait?
        jr c,PLY_AKG_SpeedTrack_StorePointerAndWaitCounter      ;Jump if wait: A is the wait value.
        ;Value found. If 0, escape value (rare).
        jr nz,PLY_AKG_SpeedTrack_NormalValue
        ;Escape code. Reads the right value.
        ld a,(hl)
        inc hl
PLY_AKG_SpeedTrack_NormalValue:
        ld (PLY_AKG_CurrentSpeed + PLY_AKG_Offset1b),a

        xor a                   ;Next time, a new value is read.
PLY_AKG_SpeedTrack_StorePointerAndWaitCounter:
        ld (PLY_AKG_SpeedTrack_PtTrack + PLY_AKG_Offset1b),hl
PLY_AKG_SpeedTrack_MustWait:
        ld (PLY_AKG_SpeedTrack_WaitCounter + PLY_AKG_Offset1b),a
PLY_AKG_SpeedTrack_End:
                       .endif ;PLY_CFG_UseSpeedTracks

        
   


        ;Reads the Event Track.
        ;-------------------------------------------------------------------
                       .if PLY_CFG_UseEventTracks            ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_EventTrack_WaitCounter: ld a,#0x00          ;Lines to wait?
       .else
        ld a,(PLY_AKG_EventTrack_WaitCounter)
       .endif
        sub #0x01
        jr nc,PLY_AKG_EventTrack_MustWait       ;Jump if there are still lines to wait.
        ;No more lines to wait. Reads a new data. It may be an event value or a wait value.
       .ifeq PLY_AKG_Rom

PLY_AKG_EventTrack_PtTrack: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_EventTrack_PtTrack)
       .endif
        ld a,(hl)
        inc hl
        srl a           ;Bit 0: wait?
        jr c,PLY_AKG_EventTrack_StorePointerAndWaitCounter      ;Jump if wait: A is the wait value.
        ;Value found. If 0, escape value (rare).
        jr nz,PLY_AKG_EventTrack_NormalValue
        ;Escape code. Reads the right value.
        ld a,(hl)
        inc hl
PLY_AKG_EventTrack_NormalValue:
        ld (PLY_AKG_Event),a

        xor a                   ;Next time, a new value is read.
PLY_AKG_EventTrack_StorePointerAndWaitCounter:
        ld (PLY_AKG_EventTrack_PtTrack + PLY_AKG_Offset1b),hl
PLY_AKG_EventTrack_MustWait:
        ld (PLY_AKG_EventTrack_WaitCounter + PLY_AKG_Offset1b),a
PLY_AKG_EventTrack_End:
                       .endif ;PLY_CFG_UseEventTracks




        ;Generates the code for each channel, from the macro above.
        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 1, 2 and 3. Use a Macro for each channel, but the code is duplicated.
        ;-------------------------------------------------------------------------

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_WaitCounter: ld a,#0x00      ;Lines to wait?
       .else
        ld a,(PLY_AKG_Channel1_WaitCounter)
       .endif
        sub #0x01
        jr c,PLY_AKG_Channel1_ReadTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel1_WaitCounter + PLY_AKG_Offset1b),a
        jp PLY_AKG_Channel1_ReadCellEnd
        
PLY_AKG_Channel1_ReadTrack:
       .ifeq PLY_AKG_Rom

PLY_AKG_Channel1_PtTrack: ld hl,#0x0000      ;Points on the Cell to read.
       .else
        ld hl,(PLY_AKG_Channel1_PtTrack)
       .endif
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and #0b111111     ;A = data.
        cp #0x3c           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel1_Note
        sub #0x3c
        jp z,PLY_AKG_Channel1_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel1_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel1_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel1_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel1_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rlca
        rlca
        and #0b11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel1_WaitCounter + PLY_AKG_Offset1b),a
        jr PLY_AKG_Channel1_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel1_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel1_WaitCounter + PLY_AKG_Offset1b),a
        inc hl
        jr PLY_AKG_Channel1_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel1_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PtBaseInstrument: ld de,#0x0000
       .else
        ld de,(PLY_AKG_Channel1_PtBaseInstrument)
       .endif 
        ld (PLY_AKG_Channel1_PtInstrument + PLY_AKG_Offset1b),de
        jr PLY_AKG_Channel1_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel1_Note:
               .ifeq PLY_AKG_Rom
PLY_AKG_BaseNoteIndex: add a,#0x00                  ;The encoded note is only from a 4 octave range, but the first note depends on he best window, determined by the song generator.
               .else
                ld b,a
                ld a,(PLY_AKG_BaseNoteIndex + PLY_AKG_Offset1b)
                add a,b
               .endif
PLY_AKG_Channel1_AfterNoteKnown:
                       .if PLY_CFG_UseTranspositions                  ;CONFIG SPECIFIC
                               .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_Transposition: add a,#0x00           ;Adds the Track transposition.
                               .else
                                ld b,a
                                ld a,(PLY_AKG_Channel1_Transposition + PLY_AKG_Offset1b)
                                add a,b
                               .endif
                       .endif ;PLY_CFG_UseTranspositions
        ld (PLY_AKG_Channel1_TrackNote + PLY_AKG_Offset1b),a
 
        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel1_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld l,a
                ld h,#0x00
                add hl,hl
               .ifeq PLY_AKG_Rom
PLY_AKG_InstrumentsTable: ld de,#0x0000           ;Points on the Instruments table of the music (set on song initialization).
               .else
                        ld de,(PLY_AKG_InstrumentsTable + PLY_AKG_Offset1b)
               .endif
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                        ;No need to store an "original speed" if "force instrument speed" effect is not used.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
                                ld (PLY_AKG_Channel1_InstrumentOriginalSpeed + PLY_AKG_Offset1b),a
                       .else
                                ld (PLY_AKG_Channel1_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
                ld (PLY_AKG_Channel1_PtInstrument + PLY_AKG_Offset1b),hl
                ld (PLY_AKG_Channel1_PtBaseInstrument + PLY_AKG_Offset1b),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel1_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, instrument step are reset.
        xor a
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel1_Pitch + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel1_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel1_PitchTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_PitchTable
        ld (PLY_AKG_Channel1_InstrumentStep + PLY_AKG_Offset2b),a
        
                        ;If the "force instrument speed" effect is used, the instrument speed must be reset to its original value.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_InstrumentOriginalSpeed: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel1_InstrumentOriginalSpeed)
       .endif
        ld (PLY_AKG_Channel1_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
        
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel1_IsPitch),a
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
        
        ;Resets the speed of the Arpeggio and the Pitch.
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel1_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel1_ArpeggioTableSpeed),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel1_PitchBaseSpeed)
        ld (PLY_AKG_Channel1_PitchTableSpeed),a        
                       .endif ;PLY_CFG_UseEffect_PitchTable

                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel1_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel1_ArpeggioTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel1_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel1_PitchTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_CFG_UseEffect_PitchTable

        ex de,hl
        
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel1_ReadEffects
                       .endif ;PLY_CFG_UseEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel1_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel1_PtTrack + PLY_AKG_Offset1b),hl
PLY_AKG_Channel1_ReadCellEnd:

        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 1, 2 and 3. Use a Macro for each channel, but the code is duplicated.
        ;-------------------------------------------------------------------------

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_WaitCounter: ld a,#0x00      ;Lines to wait?
       .else
        ld a,(PLY_AKG_Channel2_WaitCounter)
       .endif
        sub #0x01
        jr c,PLY_AKG_Channel2_ReadTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel2_WaitCounter + PLY_AKG_Offset1b),a
        jp PLY_AKG_Channel2_ReadCellEnd
        
PLY_AKG_Channel2_ReadTrack:
       .ifeq PLY_AKG_Rom

PLY_AKG_Channel2_PtTrack: ld hl,#0x0000      ;Points on the Cell to read.
       .else
        ld hl,(PLY_AKG_Channel2_PtTrack)
       .endif
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and #0b111111     ;A = data.
        cp #0x3c           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel2_Note
        sub #0x3c
        jp z,PLY_AKG_Channel2_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel2_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel2_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel2_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel2_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rlca
        rlca
        and #0b11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel2_WaitCounter + PLY_AKG_Offset1b),a
        jr PLY_AKG_Channel2_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel2_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel2_WaitCounter + PLY_AKG_Offset1b),a
        inc hl
        jr PLY_AKG_Channel2_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel2_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PtBaseInstrument: ld de,#0x0000
       .else
        ld de,(PLY_AKG_Channel2_PtBaseInstrument)
       .endif 
        ld (PLY_AKG_Channel2_PtInstrument + PLY_AKG_Offset1b),de
        jr PLY_AKG_Channel2_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel2_Note:
                ld b,a
                ld a,(PLY_AKG_BaseNoteIndex + PLY_AKG_Offset1b)
                add a,b
PLY_AKG_Channel2_AfterNoteKnown:
                       .if PLY_CFG_UseTranspositions                  ;CONFIG SPECIFIC
                               .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_Transposition: add a,#0x00           ;Adds the Track transposition.
                               .else
                                ld b,a
                                ld a,(PLY_AKG_Channel2_Transposition + PLY_AKG_Offset1b)
                                add a,b
                               .endif
                       .endif ;PLY_CFG_UseTranspositions
        ld (PLY_AKG_Channel2_TrackNote + PLY_AKG_Offset1b),a
 
        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel2_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld e,a
                ld d,#0x00
                ld hl,(PLY_AKG_InstrumentsTable + PLY_AKG_Offset1b)           ;Points on the Instruments table of the music (set on song initialization).
                add hl,de
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                        ;No need to store an "original speed" if "force instrument speed" effect is not used.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
                                ld (PLY_AKG_Channel2_InstrumentOriginalSpeed + PLY_AKG_Offset1b),a
                       .else
                                ld (PLY_AKG_Channel2_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
                ld (PLY_AKG_Channel2_PtInstrument + PLY_AKG_Offset1b),hl
                ld (PLY_AKG_Channel2_PtBaseInstrument + PLY_AKG_Offset1b),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel2_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, instrument step are reset.
        xor a
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel2_Pitch + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel2_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel2_PitchTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_PitchTable
        ld (PLY_AKG_Channel2_InstrumentStep + PLY_AKG_Offset2b),a
        
                        ;If the "force instrument speed" effect is used, the instrument speed must be reset to its original value.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_InstrumentOriginalSpeed: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel2_InstrumentOriginalSpeed)
       .endif
        ld (PLY_AKG_Channel2_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
        
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel2_IsPitch),a
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
        
        ;Resets the speed of the Arpeggio and the Pitch.
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel2_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel2_ArpeggioTableSpeed),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel2_PitchBaseSpeed)
        ld (PLY_AKG_Channel2_PitchTableSpeed),a        
                       .endif ;PLY_CFG_UseEffect_PitchTable

                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel2_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel2_ArpeggioTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel2_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel2_PitchTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_CFG_UseEffect_PitchTable

        ex de,hl
        
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel2_ReadEffects
                       .endif ;PLY_CFG_UseEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel2_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel2_PtTrack + PLY_AKG_Offset1b),hl
PLY_AKG_Channel2_ReadCellEnd:

        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 1, 2 and 3. Use a Macro for each channel, but the code is duplicated.
        ;-------------------------------------------------------------------------

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_WaitCounter: ld a,#0x00      ;Lines to wait?
       .else
        ld a,(PLY_AKG_Channel3_WaitCounter)
       .endif
        sub #0x01
        jr c,PLY_AKG_Channel3_ReadTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel3_WaitCounter + PLY_AKG_Offset1b),a
        jp PLY_AKG_Channel3_ReadCellEnd
        
PLY_AKG_Channel3_ReadTrack:
       .ifeq PLY_AKG_Rom

PLY_AKG_Channel3_PtTrack: ld hl,#0x0000      ;Points on the Cell to read.
       .else
        ld hl,(PLY_AKG_Channel3_PtTrack)
       .endif
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and #0b111111     ;A = data.
        cp #0x3c           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel3_Note
        sub #0x3c
        jp z,PLY_AKG_Channel3_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel3_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel3_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel3_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel3_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rlca
        rlca
        and #0b11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel3_WaitCounter + PLY_AKG_Offset1b),a
        jr PLY_AKG_Channel3_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel3_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel3_WaitCounter + PLY_AKG_Offset1b),a
        inc hl
        jr PLY_AKG_Channel3_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel3_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PtBaseInstrument: ld de,#0x0000
       .else
        ld de,(PLY_AKG_Channel3_PtBaseInstrument)
       .endif 
        ld (PLY_AKG_Channel3_PtInstrument + PLY_AKG_Offset1b),de
        jr PLY_AKG_Channel3_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel3_Note:
                ld b,a
                ld a,(PLY_AKG_BaseNoteIndex + PLY_AKG_Offset1b)
                add a,b
PLY_AKG_Channel3_AfterNoteKnown:
                       .if PLY_CFG_UseTranspositions                  ;CONFIG SPECIFIC
                               .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_Transposition: add a,#0x00           ;Adds the Track transposition.
                               .else
                                ld b,a
                                ld a,(PLY_AKG_Channel3_Transposition + PLY_AKG_Offset1b)
                                add a,b
                               .endif
                       .endif ;PLY_CFG_UseTranspositions
        ld (PLY_AKG_Channel3_TrackNote + PLY_AKG_Offset1b),a
 
        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel3_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld e,a
                ld d,#0x00
                ld hl,(PLY_AKG_InstrumentsTable + PLY_AKG_Offset1b)           ;Points on the Instruments table of the music (set on song initialization).
                add hl,de
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                        ;No need to store an "original speed" if "force instrument speed" effect is not used.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
                                ld (PLY_AKG_Channel3_InstrumentOriginalSpeed + PLY_AKG_Offset1b),a
                       .else
                                ld (PLY_AKG_Channel3_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
                ld (PLY_AKG_Channel3_PtInstrument + PLY_AKG_Offset1b),hl
                ld (PLY_AKG_Channel3_PtBaseInstrument + PLY_AKG_Offset1b),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel3_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, instrument step are reset.
        xor a
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel3_Pitch + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel3_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld (PLY_AKG_Channel3_PitchTableCurrentStep + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_PitchTable
        ld (PLY_AKG_Channel3_InstrumentStep + PLY_AKG_Offset2b),a
        
                        ;If the "force instrument speed" effect is used, the instrument speed must be reset to its original value.
                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_InstrumentOriginalSpeed: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel3_InstrumentOriginalSpeed)
       .endif
        ld (PLY_AKG_Channel3_InstrumentSpeed + PLY_AKG_Offset1b),a
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
        
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel3_IsPitch),a
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
        
        ;Resets the speed of the Arpeggio and the Pitch.
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel3_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel3_ArpeggioTableSpeed),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld a,(PLY_AKG_Channel3_PitchBaseSpeed)
        ld (PLY_AKG_Channel3_PitchTableSpeed),a        
                       .endif ;PLY_CFG_UseEffect_PitchTable

                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel3_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel3_ArpeggioTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld hl,(PLY_AKG_Channel3_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel3_PitchTable + PLY_AKG_Offset1b),hl
                       .endif ;PLY_CFG_UseEffect_PitchTable

        ex de,hl
        
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel3_ReadEffects
                       .endif ;PLY_CFG_UseEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel3_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel3_PtTrack + PLY_AKG_Offset1b),hl
PLY_AKG_Channel3_ReadCellEnd:




       .ifeq PLY_AKG_Rom
PLY_AKG_CurrentSpeed: ld a,#0x00      ;>0.
       .else
        ld a,(PLY_AKG_CurrentSpeed)
       .endif
PLY_AKG_SetSpeedBeforePlayStreams:
        ld (PLY_AKG_TickDecreasingCounter + PLY_AKG_Offset1b),a




        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 1, 2, 3. Uses a macro instead of duplicating the code.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
        ;----------------------------
               .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal)
       .endif
.equ PLY_AKG_Channel1_InvertedVolumeInteger , PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1
                       .if PLY_AKG_UseEffect_VolumeSlide             ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel1_IsVolumeSlide)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel1_VolumeSlide_End
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_VolumeSlideValue: ld de,#0x0000              ;May be negative.
       .else
        ld de,(PLY_AKG_Channel1_VolumeSlideValue)
       .endif
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel1_VolumeNotOverflow
        ld h,#0x00                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel1_VolumeSetAgain
PLY_AKG_Channel1_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp #0x10
        jr c,PLY_AKG_Channel1_VolumeSetAgain
        ld h,#0x0f
PLY_AKG_Channel1_VolumeSetAgain:
        ld (PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b),hl
        
PLY_AKG_Channel1_VolumeSlide_End:
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        ld a,h
        ld (PLY_AKG_Channel1_GeneratedCurrentInvertedVolume + PLY_AKG_Offset1b),a
        
        
        
        
        
        ;Use Arpeggio table? OUT: C = value.
        ;----------------------------------------
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld c,#0x00  ;Default value of the arpeggio.

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel1_IsArpeggioTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel1_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_ArpeggioTable: ld hl,#0x0000                 ;Points on the data, after the header.
       .else
        ld hl,(PLY_AKG_Channel1_ArpeggioTable)
       .endif
        ld a,(hl)
        cp #0x80                  ;Loop?
        jr nz,PLY_AKG_Channel1_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel1_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel1_ArpeggioTableSpeed)
        ld d,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_ArpeggioTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel1_ArpeggioTableCurrentStep)
       .endif
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel1_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel1_ArpeggioTable + PLY_AKG_Offset1b),hl

        xor a
PLY_AKG_Channel1_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel1_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel1_ArpeggioTable_End:
                       .endif ;PLY_AKS_UseEffect_Arpeggio



        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        
        ld de,#0x0000         ;Default value.
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel1_IsPitchTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel1_PitchTable_End
        
        ;Read the Pitch table for a value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTable: ld sp,#0x0000                 ;Points on the data, after the header.
       .else
        ld sp,(PLY_AKG_Channel1_PitchTable)
       .endif
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel1_PitchTableSpeed)
        ld b,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel1_PitchTableCurrentStep)
       .endif
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel1_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel1_PitchTable + PLY_AKG_Offset1b),hl
        
        xor a
PLY_AKG_Channel1_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel1_PitchTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel1_PitchTable_End:        
                       .endif ;PLY_CFG_UseEffect_PitchTable



        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not without Pitch).
        ;Do NOT modify C or DE.
        ;------------------------------------------------------------------------------------------
                       .ifeq PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
                        ld hl,#0x0000 ;No pitch.
                               .ifeq PLY_AKG_Rom              ;Nothing to declare if ROM.
                                ;Some dirty duplication in case there is no pitch up/down/glide. The "real" vars are a bit below.
PLY_AKG_Channel1_SoundStream_RelativeModifierAddress:                 ;Put here, no need for better place (see the real label below, with the same name).
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                                        jr PLY_AKG_Channel1_AfterArpeggioPitchVariables
                                
                                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel1_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel1_ArpeggioBaseSpeed:  .db 0
PLY_AKG_Channel1_ArpeggioTableBase:  .dw 0
                                               .endif ;PLY_AKS_UseEffect_Arpeggio
                                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel1_PitchTableSpeed:  .db 0
PLY_AKG_Channel1_PitchBaseSpeed:   .db 0
PLY_AKG_Channel1_PitchTableBase:   .dw 0
                                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel1_AfterArpeggioPitchVariables:
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
                               .endif ;PLY_AKG_ROM       
                       .else ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_Pitch: ld hl,#0x0000
PLY_AKG_Channel1_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
       .else
        ld hl,(PLY_AKG_Channel1_Pitch)
        ld a,(PLY_AKG_Channel1_IsPitch)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel1_Pitch_End
        ;C must NOT be modified, stores it.
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .db #0xdd,#0x69      ;ld ixl,c
                               .endif ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTrack: ld bc,#0x0000                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.
       .else
        ld bc,(PLY_AKG_Channel1_PitchTrack)
       .endif

        or a                                            ;Required if the code is changed to sbc.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits: nop 
        add hl,bc                                       ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.
       .else
        jp PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits   ;Calls a code that holds the instruction.
PLY_AKG_Channel1_PitchTrackAddOrSbc_16bitsReturn:
       .endif
        
        ;Makes the decimal part evolves.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTrackDecimalCounter: ld a,#0x00
PLY_AKG_Channel1_PitchTrackDecimalInstr: add a,#0x00              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
.equ PLY_AKG_Channel1_PitchTrackDecimalValue , PLY_AKG_Channel1_PitchTrackDecimalInstr + 1
       .else
        ld a,(PLY_AKG_Channel1_PitchTrackDecimalValue)
        ld b,a
        ld a,(PLY_AKG_Channel1_PitchTrackDecimalCounter)
        ;Add a,b or sub b? Lets the subcode decide. It will return just below.
        jp PLY_AKG_Channel1_PitchTrackDecimalInstrAndValue
PLY_AKG_Channel1_PitchTrackDecimalInstrAndValueReturnAfterJp:
       .endif
        ld (PLY_AKG_Channel1_PitchTrackDecimalCounter + PLY_AKG_Offset1b),a

        jr nc,PLY_AKG_Channel1_PitchNoCarry
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl
       .else
        jp PLY_AKG_Channel1_PitchTrackIntegerAddOrSub   ;Calls a code that holds the instruction.
PLY_AKG_Channel1_PitchTrackIntegerAddOrSubReturn:
       .endif
PLY_AKG_Channel1_PitchNoCarry:
        ld (PLY_AKG_Channel1_Pitch + PLY_AKG_Offset1b),hl

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
        ;Glide?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_GlideDirection: ld a,#0x00         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
       .else
        ld a,(PLY_AKG_Channel1_GlideDirection)
       .endif
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel1_Glide_End

        ld (PLY_AKG_Channel1_Glide_SaveHL + PLY_AKG_Offset1b),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel1_TrackNote + PLY_AKG_Offset1b)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,#0x00
        ld sp,#PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_GlideToReach: ld bc,#0x0000                  ;Period to reach (note given by the user, converted to period).
       .else
        ld bc,(PLY_AKG_Channel1_GlideToReach)
       .endif
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel1_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel1_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel1_GlideOver

PLY_AKG_Channel1_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel1_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel1_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel1_Pitch + PLY_AKG_Offset1b),hl
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel1_IsPitch),a
        ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        jr PLY_AKG_Channel1_Glide_End
                               .else
       .ifeq PLY_AKG_Rom
                ;Skips the variables below, if there are present.
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                jr PLY_AKG_Channel1_AfterArpeggioPitchVariables
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
       .endif ;PLY_AKG_Rom
                               .endif ;PLY_CFG_UseEffect_PitchGlide
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
        ;Note that the vars just below are duplicated due to the conditional assembling (they are a bit above).
       .ifeq PLY_AKG_Rom
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel1_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel1_ArpeggioBaseSpeed: .db 0
PLY_AKG_Channel1_ArpeggioTableBase: .dw 0
                               .endif ;PLY_AKS_UseEffect_Arpeggio
                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel1_PitchTableSpeed: .db 0
PLY_AKG_Channel1_PitchBaseSpeed: .db 0
PLY_AKG_Channel1_PitchTableBase: .dw 0
                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel1_AfterArpeggioPitchVariables:
       .endif ;PLY_AKG_Rom

                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
PLY_AKG_Channel1_Glide_BeforeEnd:
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_Glide_SaveHL: ld hl,#0x0000               ;Restores HL.
       .else
        ld hl,(PLY_AKG_Channel1_Glide_SaveHL)
       .endif
PLY_AKG_Channel1_Glide_End:
                               .endif ;PLY_CFG_UseEffect_PitchGlide
                        
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .db #0xdd,#0x4d      ;ld c,ixl                                        ;Restores C (arp), saved before.
                               .endif ;PLY_AKS_UseEffect_Arpeggio

PLY_AKG_Channel1_Pitch_End:
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                        
                        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel1_GeneratedCurrentPitch + PLY_AKG_Offset1b),hl
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,c
        ld (PLY_AKG_Channel1_GeneratedCurrentArpNote + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio

        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 1, 2, 3. Uses a macro instead of duplicating the code.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
        ;----------------------------
               .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal)
       .endif
.equ PLY_AKG_Channel2_InvertedVolumeInteger , PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1
                       .if PLY_AKG_UseEffect_VolumeSlide             ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel2_IsVolumeSlide)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel2_VolumeSlide_End
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_VolumeSlideValue: ld de,#0x0000              ;May be negative.
       .else
        ld de,(PLY_AKG_Channel2_VolumeSlideValue)
       .endif
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel2_VolumeNotOverflow
        ld h,#0x00                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel2_VolumeSetAgain
PLY_AKG_Channel2_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp #0x10
        jr c,PLY_AKG_Channel2_VolumeSetAgain
        ld h,#0x0f        
PLY_AKG_Channel2_VolumeSetAgain:
        ld (PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b),hl
        
PLY_AKG_Channel2_VolumeSlide_End:
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        ld a,h
        ld (PLY_AKG_Channel2_GeneratedCurrentInvertedVolume + PLY_AKG_Offset1b),a
        
        
        
        
        
        ;Use Arpeggio table? OUT: C = value.
        ;----------------------------------------
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld c,#0x00  ;Default value of the arpeggio.

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel2_IsArpeggioTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel2_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_ArpeggioTable: ld hl,#0x0000                 ;Points on the data, after the header.
       .else
        ld hl,(PLY_AKG_Channel2_ArpeggioTable)
       .endif
        ld a,(hl)
        cp #0x80                  ;Loop?
        jr nz,PLY_AKG_Channel2_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel2_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel2_ArpeggioTableSpeed)
        ld d,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_ArpeggioTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel2_ArpeggioTableCurrentStep)
       .endif
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel2_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel2_ArpeggioTable + PLY_AKG_Offset1b),hl

        xor a
PLY_AKG_Channel2_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel2_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel2_ArpeggioTable_End:
                       .endif ;PLY_AKS_UseEffect_Arpeggio



        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        
        ld de,#0x0000         ;Default value.
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel2_IsPitchTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel2_PitchTable_End
        
        ;Read the Pitch table for a value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTable: ld sp,#0x0000                 ;Points on the data, after the header.
       .else
        ld sp,(PLY_AKG_Channel2_PitchTable)
       .endif
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel2_PitchTableSpeed)
        ld b,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel2_PitchTableCurrentStep)
       .endif
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel2_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel2_PitchTable + PLY_AKG_Offset1b),hl
        
        xor a
PLY_AKG_Channel2_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel2_PitchTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel2_PitchTable_End:        
                       .endif ;PLY_CFG_UseEffect_PitchTable



        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not without Pitch).
        ;Do NOT modify C or DE.
        ;------------------------------------------------------------------------------------------
                       .ifeq PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
                        ld hl,#0x0000 ;No pitch.
                               .ifeq PLY_AKG_Rom              ;Nothing to declare if ROM.
                                ;Some dirty duplication in case there is no pitch up/down/glide. The "real" vars are a bit below.
PLY_AKG_Channel2_SoundStream_RelativeModifierAddress:                 ;Put here, no need for better place (see the real label below, with the same name).
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                                        jr PLY_AKG_Channel2_AfterArpeggioPitchVariables
                                
                                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel2_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel2_ArpeggioBaseSpeed: .db 0
PLY_AKG_Channel2_ArpeggioTableBase: .dw 0
                                               .endif ;PLY_AKS_UseEffect_Arpeggio
                                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel2_PitchTableSpeed: .db 0
PLY_AKG_Channel2_PitchBaseSpeed: .db 0
PLY_AKG_Channel2_PitchTableBase: .dw 0
                                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel2_AfterArpeggioPitchVariables:
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
                               .endif ;PLY_AKG_ROM       
                       .else ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_Pitch: ld hl,#0x0000
PLY_AKG_Channel2_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
       .else
        ld hl,(PLY_AKG_Channel2_Pitch)
        ld a,(PLY_AKG_Channel2_IsPitch)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel2_Pitch_End
        ;C must NOT be modified, stores it.
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        .db #0xdd,#0x69      ;ld ixl,c
                               .endif ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTrack: ld bc,#0x0000                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.
       .else
        ld bc,(PLY_AKG_Channel2_PitchTrack)
       .endif

        or a                                            ;Required if the code is changed to sbc.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTrackAddOrSbc_16bits: nop 
        add hl,bc                                       ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.
       .else
        jp PLY_AKG_Channel2_PitchTrackAddOrSbc_16bits   ;Calls a code that holds the instruction.
PLY_AKG_Channel2_PitchTrackAddOrSbc_16bitsReturn:
       .endif
        
        ;Makes the decimal part evolves.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTrackDecimalCounter: ld a,#0x00
PLY_AKG_Channel2_PitchTrackDecimalInstr: add a,#0x00              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
.equ PLY_AKG_Channel2_PitchTrackDecimalValue , PLY_AKG_Channel2_PitchTrackDecimalInstr + 1
       .else
        ld a,(PLY_AKG_Channel2_PitchTrackDecimalValue)
        ld b,a
        ld a,(PLY_AKG_Channel2_PitchTrackDecimalCounter)
        ;Add a,b or sub b? Lets the subcode decide. It will return just below.
        jp PLY_AKG_Channel2_PitchTrackDecimalInstrAndValue
PLY_AKG_Channel2_PitchTrackDecimalInstrAndValueReturnAfterJp:
       .endif
        ld (PLY_AKG_Channel2_PitchTrackDecimalCounter + PLY_AKG_Offset1b),a

        jr nc,PLY_AKG_Channel2_PitchNoCarry
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl
       .else
        jp PLY_AKG_Channel2_PitchTrackIntegerAddOrSub   ;Calls a code that holds the instruction.
PLY_AKG_Channel2_PitchTrackIntegerAddOrSubReturn:
       .endif
PLY_AKG_Channel2_PitchNoCarry:
        ld (PLY_AKG_Channel2_Pitch + PLY_AKG_Offset1b),hl

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
        ;Glide?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_GlideDirection: ld a,#0x00         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
       .else
        ld a,(PLY_AKG_Channel2_GlideDirection)
       .endif
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel2_Glide_End

        ld (PLY_AKG_Channel2_Glide_SaveHL + PLY_AKG_Offset1b),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel2_TrackNote + PLY_AKG_Offset1b)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,#0x00
        ld sp,#PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_GlideToReach: ld bc,#0x0000                  ;Period to reach (note given by the user, converted to period).
       .else
        ld bc,(PLY_AKG_Channel2_GlideToReach)
       .endif
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel2_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel2_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel2_GlideOver

PLY_AKG_Channel2_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel2_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel2_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel2_Pitch + PLY_AKG_Offset1b),hl
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel2_IsPitch),a
        ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        jr PLY_AKG_Channel2_Glide_End
                               .else
       .ifeq PLY_AKG_Rom
                ;Skips the variables below, if there are present.
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                jr PLY_AKG_Channel2_AfterArpeggioPitchVariables
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
       .endif ;PLY_AKG_Rom
                               .endif ;PLY_CFG_UseEffect_PitchGlide
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
        ;Note that the vars just below are duplicated due to the conditional assembling (they are a bit above).
       .ifeq PLY_AKG_Rom
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel2_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel2_ArpeggioBaseSpeed: .db 0
PLY_AKG_Channel2_ArpeggioTableBase: .dw 0
                               .endif ;PLY_AKS_UseEffect_Arpeggio
                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel2_PitchTableSpeed: .db 0
PLY_AKG_Channel2_PitchBaseSpeed: .db 0
PLY_AKG_Channel2_PitchTableBase: .dw 0
                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel2_AfterArpeggioPitchVariables:
       .endif ;PLY_AKG_Rom

                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
PLY_AKG_Channel2_Glide_BeforeEnd:
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_Glide_SaveHL: ld hl,#0x0000               ;Restores HL.
       .else
        ld hl,(PLY_AKG_Channel2_Glide_SaveHL)
       .endif
PLY_AKG_Channel2_Glide_End:
                               .endif ;PLY_CFG_UseEffect_PitchGlide
                        
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        .db #0xdd,#0x4d      ;ld c,ixl                                        ;Restores C (arp), saved before.
                               .endif ;PLY_AKS_UseEffect_Arpeggio

PLY_AKG_Channel2_Pitch_End:
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                        
                        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel2_GeneratedCurrentPitch + PLY_AKG_Offset1b),hl
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,c
        ld (PLY_AKG_Channel2_GeneratedCurrentArpNote + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio

        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 1, 2, 3. Uses a macro instead of duplicating the code.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
        ;----------------------------
               .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal)
       .endif
.equ PLY_AKG_Channel3_InvertedVolumeInteger , PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b + 1
                       .if PLY_AKG_UseEffect_VolumeSlide             ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel3_IsVolumeSlide)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel3_VolumeSlide_End
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_VolumeSlideValue: ld de,#0x0000              ;May be negative.
       .else
        ld de,(PLY_AKG_Channel3_VolumeSlideValue)
       .endif
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel3_VolumeNotOverflow
        ld h,#0x00                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel3_VolumeSetAgain
PLY_AKG_Channel3_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp #0x10
        jr c,PLY_AKG_Channel3_VolumeSetAgain
        ld h,#0x0f        
PLY_AKG_Channel3_VolumeSetAgain:
        ld (PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + PLY_AKG_Offset1b),hl
        
PLY_AKG_Channel3_VolumeSlide_End:
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        ld a,h
        ld (PLY_AKG_Channel3_GeneratedCurrentInvertedVolume + PLY_AKG_Offset1b),a
        
        
        
        
        
        ;Use Arpeggio table? OUT: C = value.
        ;----------------------------------------
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld c,#0x00  ;Default value of the arpeggio.

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel3_IsArpeggioTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel3_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_ArpeggioTable: ld hl,#0x0000                 ;Points on the data, after the header.
       .else
        ld hl,(PLY_AKG_Channel3_ArpeggioTable)
       .endif
        ld a,(hl)
        cp #0x80                  ;Loop?
        jr nz,PLY_AKG_Channel3_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel3_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel3_ArpeggioTableSpeed)
        ld d,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_ArpeggioTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel3_ArpeggioTableCurrentStep)
       .endif
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel3_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel3_ArpeggioTable + PLY_AKG_Offset1b),hl

        xor a
PLY_AKG_Channel3_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel3_ArpeggioTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel3_ArpeggioTable_End:
                       .endif ;PLY_AKS_UseEffect_Arpeggio



        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        
        ld de,#0x0000         ;Default value.
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
       .else
        ld a,(PLY_AKG_Channel3_IsPitchTable)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel3_PitchTable_End
        
        ;Read the Pitch table for a value.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTable: ld sp,#0x0000                 ;Points on the data, after the header.
       .else
        ld sp,(PLY_AKG_Channel3_PitchTable)
       .endif
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel3_PitchTableSpeed)
        ld b,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTableCurrentStep: ld a,#0x00
       .else
        ld a,(PLY_AKG_Channel3_PitchTableCurrentStep)
       .endif
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel3_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel3_PitchTable + PLY_AKG_Offset1b),hl
        
        xor a
PLY_AKG_Channel3_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel3_PitchTableCurrentStep + PLY_AKG_Offset1b),a
PLY_AKG_Channel3_PitchTable_End:        
                       .endif ;PLY_CFG_UseEffect_PitchTable



        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not without Pitch).
        ;Do NOT modify C or DE.
        ;------------------------------------------------------------------------------------------
                       .ifeq PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
                        ld hl,#0x0000 ;No pitch.
                               .ifeq PLY_AKG_Rom              ;Nothing to declare if ROM.
                                ;Some dirty duplication in case there is no pitch up/down/glide. The "real" vars are a bit below.
PLY_AKG_Channel3_SoundStream_RelativeModifierAddress:                 ;Put here, no need for better place (see the real label below, with the same name).
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                                        jr PLY_AKG_Channel3_AfterArpeggioPitchVariables
                                
                                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel3_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel3_ArpeggioBaseSpeed: .db 0
PLY_AKG_Channel3_ArpeggioTableBase: .dw 0
                                               .endif ;PLY_AKS_UseEffect_Arpeggio
                                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel3_PitchTableSpeed: .db 0
PLY_AKG_Channel3_PitchBaseSpeed: .db 0
PLY_AKG_Channel3_PitchTableBase: .dw 0
                                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel3_AfterArpeggioPitchVariables:
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
                               .endif ;PLY_AKG_ROM       
                       .else ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_Pitch: ld hl,#0x0000
PLY_AKG_Channel3_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
       .else
        ld hl,(PLY_AKG_Channel3_Pitch)
        ld a,(PLY_AKG_Channel3_IsPitch)
        add a,a         ;Creates the carry or not.
       .endif
        jr nc,PLY_AKG_Channel3_Pitch_End
        ;C must NOT be modified, stores it.
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        .db #0xdd,#0x69      ;ld ixl,c
                               .endif ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTrack: ld bc,#0x0000                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.
       .else
        ld bc,(PLY_AKG_Channel3_PitchTrack)
       .endif

        or a                                            ;Required if the code is changed to sbc.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTrackAddOrSbc_16bits: nop 
        add hl,bc                                       ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.
       .else
        jp PLY_AKG_Channel3_PitchTrackAddOrSbc_16bits   ;Calls a code that holds the instruction.
PLY_AKG_Channel3_PitchTrackAddOrSbc_16bitsReturn:
       .endif
        
        ;Makes the decimal part evolves.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTrackDecimalCounter: ld a,#0x00
PLY_AKG_Channel3_PitchTrackDecimalInstr: add a,#0x00              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
.equ PLY_AKG_Channel3_PitchTrackDecimalValue , PLY_AKG_Channel3_PitchTrackDecimalInstr + 1
       .else
        ld a,(PLY_AKG_Channel3_PitchTrackDecimalValue)
        ld b,a
        ld a,(PLY_AKG_Channel3_PitchTrackDecimalCounter)
        ;Add a,b or sub b? Lets the subcode decide. It will return just below.
        jp PLY_AKG_Channel3_PitchTrackDecimalInstrAndValue
PLY_AKG_Channel3_PitchTrackDecimalInstrAndValueReturnAfterJp:
       .endif
        ld (PLY_AKG_Channel3_PitchTrackDecimalCounter + PLY_AKG_Offset1b),a

        jr nc,PLY_AKG_Channel3_PitchNoCarry
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl
       .else
        jp PLY_AKG_Channel3_PitchTrackIntegerAddOrSub   ;Calls a code that holds the instruction.
PLY_AKG_Channel3_PitchTrackIntegerAddOrSubReturn:
       .endif
PLY_AKG_Channel3_PitchNoCarry:
        ld (PLY_AKG_Channel3_Pitch + PLY_AKG_Offset1b),hl

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
        ;Glide?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_GlideDirection: ld a,#0x00         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
       .else
        ld a,(PLY_AKG_Channel3_GlideDirection)
       .endif
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel3_Glide_End

        ld (PLY_AKG_Channel3_Glide_SaveHL + PLY_AKG_Offset1b),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel3_TrackNote + PLY_AKG_Offset1b)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,#0x00
        ld sp,#PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).
        
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_GlideToReach: ld bc,#0x0000                  ;Period to reach (note given by the user, converted to period).
       .else
        ld bc,(PLY_AKG_Channel3_GlideToReach)
       .endif
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel3_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel3_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel3_GlideOver

PLY_AKG_Channel3_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel3_Glide_BeforeEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel3_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel3_Pitch + PLY_AKG_Offset1b),hl
        ld a,#PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel3_IsPitch),a
        ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        jr PLY_AKG_Channel3_Glide_End
                               .else
       .ifeq PLY_AKG_Rom
                ;Skips the variables below, if there are present.
                                       .if PLY_AKS_UseEffect_ArpeggioTableOrPitchTable       ;CONFIG SPECIFIC
                jr PLY_AKG_Channel3_AfterArpeggioPitchVariables
                                       .endif ;PLY_AKS_UseEffect_ArpeggioTableOrPitchTable
       .endif ;PLY_AKG_Rom
                               .endif ;PLY_CFG_UseEffect_PitchGlide
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
        ;Note that the vars just below are duplicated due to the conditional assembling (they are a bit above).
       .ifeq PLY_AKG_Rom
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Channel3_ArpeggioTableSpeed: .db 0
PLY_AKG_Channel3_ArpeggioBaseSpeed: .db 0
PLY_AKG_Channel3_ArpeggioTableBase: .dw 0
                               .endif ;PLY_AKS_UseEffect_Arpeggio
                               .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
PLY_AKG_Channel3_PitchTableSpeed: .db 0
PLY_AKG_Channel3_PitchBaseSpeed: .db 0
PLY_AKG_Channel3_PitchTableBase: .dw 0
                               .endif ;PLY_CFG_UseEffect_PitchTable
PLY_AKG_Channel3_AfterArpeggioPitchVariables:
       .endif ;PLY_AKG_Rom

                               .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
PLY_AKG_Channel3_Glide_BeforeEnd:
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_Glide_SaveHL: ld hl,#0x0000               ;Restores HL.
       .else
        ld hl,(PLY_AKG_Channel3_Glide_SaveHL)
       .endif
PLY_AKG_Channel3_Glide_End:
                               .endif ;PLY_CFG_UseEffect_PitchGlide
                        
                               .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        .db #0xdd,#0x4d      ;ld c,ixl                                        ;Restores C (arp), saved before.
                               .endif ;PLY_AKS_UseEffect_Arpeggio

PLY_AKG_Channel3_Pitch_End:
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                        
                        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel3_GeneratedCurrentPitch + PLY_AKG_Offset1b),hl
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld a,c
        ld (PLY_AKG_Channel3_GeneratedCurrentArpNote + PLY_AKG_Offset1b),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio














        ;The stack must NOT be diverted during the Play Streams!
        ld sp,(PLY_AKG_SaveSP + PLY_AKG_Offset1b)


;-------------------------------------------------------------------------------------
;Plays the instrument on channel 1, 2, 3. The PSG registers related to the channels are set.
;A macro is used instead of duplicating the code.
;-------------------------------------------------------------------------------------     
        
        ;Generates the code for all channels using the macro above.
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
        
        ;What note to play?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_GeneratedCurrentPitch: ld hl,#0x0000 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
       .else
        ld hl,(PLY_AKG_Channel1_GeneratedCurrentPitch)
       .endif
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_TrackNote: ld a,#0x00
PLY_AKG_Channel1_GeneratedCurrentArpNote: add a,#0x00                           ;Adds the arpeggio value.
       .else
        ld a,(PLY_AKG_Channel1_TrackNote)
        ld e,a
        ld a,(PLY_AKG_Channel1_GeneratedCurrentArpNote)
        add a,e
       .endif
                ld e,a
                ld d,#0x00
                       .else ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_TrackNote: ld de,#0x0000               ;Not automodified, stays this way.
       .else
        ld a,(PLY_AKG_Channel1_TrackNote)        ;In ROM, MUST pass by a variable anyway to be analog to if Arpeggio is used (see above).
        ld e,a
        ld d,#0x00
       .endif
                       .endif ;PLY_AKS_UseEffect_Arpeggio
        exx
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_InstrumentStep: .db #0xfd,#0x2e,#0x00      ;ld iyl,0
PLY_AKG_Channel1_PtInstrument: ld hl,#0x0000       ;Instrument data to read (past the header).
PLY_AKG_Channel1_GeneratedCurrentInvertedVolume: ld de,#0b11100000 * 256 + 15             ;R7, shift twice TO THE LEFT. By default, the noise is cut (111), the sound is on (most usual case).
       .else
        ld a,(PLY_AKG_Channel1_InstrumentStep)
        ld iyl,a
        ld hl,(PLY_AKG_Channel1_PtInstrument)
        ld a,(PLY_AKG_Channel1_GeneratedCurrentInvertedVolume)
        ld e,a
                ;For the first channel, sets the R7 value to no noise, all channel on by default ().
                ld d,#0b11100000
       .endif
        
;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
       .if PLY_AKG_Rom
        ld a,(PLY_AKG_Channel1_InstrumentSpeed)
        ld b,a
       .endif
       .db #0xfd,#0x7d      ;ld a,iyl
        inc a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel1_InstrumentSpeed: cp #0x00          ;(>0)
       .else
        cp b
       .endif
        jr c,PLY_AKG_Channel1_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel1_PtInstrument + PLY_AKG_Offset1b),hl
        xor a
PLY_AKG_Channel1_SetInstrumentStep:
        ld (PLY_AKG_Channel1_InstrumentStep + PLY_AKG_Offset2b),a

        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg8),a          ;Reaches register/label 8/9/10.
        
               .if PLY_AKG_HARDWARE_CPC
                        srl d           ;Shift D to the right to let room for the other channels. Use SRL, not RR, to make sure bit 6 is 0 at the end (else, no more keyboard on CPC!).
               .else
                       .if PLY_AKG_HARDWARE_MSX
                                        srl d           ;R7 bit 6 on MSX must be 0.
                       .else
                                rr d            ;On other platform, we don't care.
                       .endif
               .endif
        
        exx
                        ld (PLY_AKG_PSGReg01_Instr + PLY_AKG_Offset1b),hl

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
        
        ;What note to play?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_GeneratedCurrentPitch: ld hl,#0x0000 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
       .else
        ld hl,(PLY_AKG_Channel2_GeneratedCurrentPitch)
       .endif
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_TrackNote: ld a,#0x00
PLY_AKG_Channel2_GeneratedCurrentArpNote: add a,#0x00                           ;Adds the arpeggio value.
       .else
        ld a,(PLY_AKG_Channel2_TrackNote)
        ld e,a
        ld a,(PLY_AKG_Channel2_GeneratedCurrentArpNote)
        add a,e
       .endif
                ld e,a
                ld d,#0x00
                       .else ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_TrackNote: ld de,#0x0000               ;Not automodified, stays this way.
       .else
        ld a,(PLY_AKG_Channel2_TrackNote)        ;In ROM, MUST pass by a variable anyway to be analog to if Arpeggio is used (see above).
        ld e,a
        ld d,#0x00
       .endif
                       .endif ;PLY_AKS_UseEffect_Arpeggio
        exx
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_InstrumentStep: .db #0xfd,#0x2e,#0x00      ;ld iyl,0
PLY_AKG_Channel2_PtInstrument: ld hl,#0x0000       ;Instrument data to read (past the header).

PLY_AKG_Channel2_GeneratedCurrentInvertedVolume: ld e,#0x0f
                nop                     ;Stupid, but required for relative registers to reach addresses independently of the channels.
       .else
        ld a,(PLY_AKG_Channel2_InstrumentStep)
        ld iyl,a
        ld hl,(PLY_AKG_Channel2_PtInstrument)
        ld a,(PLY_AKG_Channel2_GeneratedCurrentInvertedVolume)
        ld e,a
       .endif
        
;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
       .if PLY_AKG_Rom
        ld a,(PLY_AKG_Channel2_InstrumentSpeed)
        ld b,a
       .endif
       .db #0xfd,#0x7d      ;ld a,iyl
        inc a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel2_InstrumentSpeed: cp #0x00          ;(>0)
       .else
        cp b
       .endif
        jr c,PLY_AKG_Channel2_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel2_PtInstrument + PLY_AKG_Offset1b),hl
        xor a
PLY_AKG_Channel2_SetInstrumentStep:
        ld (PLY_AKG_Channel2_InstrumentStep + PLY_AKG_Offset2b),a

        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg9),a          ;Reaches register/label 8/9/10.
        
               .if PLY_AKG_HARDWARE_CPC
                        srl d           ;Shift D to the right to let room for the other channels. Use SRL, not RR, to make sure bit 6 is 0 at the end (else, no more keyboard on CPC!).
               .else
                       .if PLY_AKG_HARDWARE_MSX
                                        scf             ;R7 bit 7 on MSX must be 1.
                                        rr d
                       .else
                                rr d            ;On other platform, we don't care.
                       .endif
               .endif
        
        exx
                        ld (PLY_AKG_PSGReg23_Instr + PLY_AKG_Offset1b),hl

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.
       .endif
        
        ;What note to play?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_GeneratedCurrentPitch: ld hl,#0x0000 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
       .else
        ld hl,(PLY_AKG_Channel3_GeneratedCurrentPitch)
       .endif
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_TrackNote: ld a,#0x00
PLY_AKG_Channel3_GeneratedCurrentArpNote: add a,#0x00                           ;Adds the arpeggio value.
       .else
        ld a,(PLY_AKG_Channel3_TrackNote)
        ld e,a
        ld a,(PLY_AKG_Channel3_GeneratedCurrentArpNote)
        add a,e
       .endif
                ld e,a
                ld d,#0x00
                       .else ;PLY_AKS_UseEffect_Arpeggio
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_TrackNote: ld de,#0x0000               ;Not automodified, stays this way.
       .else
        ld a,(PLY_AKG_Channel3_TrackNote)        ;In ROM, MUST pass by a variable anyway to be analog to if Arpeggio is used (see above).
        ld e,a
        ld d,#0x00
       .endif
                       .endif ;PLY_AKS_UseEffect_Arpeggio
        exx
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_InstrumentStep: .db #0xfd,#0x2e,#0x00      ;ld iyl,0
PLY_AKG_Channel3_PtInstrument: ld hl,#0x0000       ;Instrument data to read (past the header).

PLY_AKG_Channel3_GeneratedCurrentInvertedVolume: ld e,#0x0f
                nop                     ;Stupid, but required for relative registers to reach addresses independently of the channels.
       .else
        ld a,(PLY_AKG_Channel3_InstrumentStep)
        ld iyl,a
        ld hl,(PLY_AKG_Channel3_PtInstrument)
        ld a,(PLY_AKG_Channel3_GeneratedCurrentInvertedVolume)
        ld e,a
       .endif
        
;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
       .if PLY_AKG_Rom
        ld a,(PLY_AKG_Channel3_InstrumentSpeed)
        ld b,a
       .endif
       .db #0xfd,#0x7d      ;ld a,iyl
        inc a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel3_InstrumentSpeed: cp #0x00          ;(>0)
       .else
        cp b
       .endif
        jr c,PLY_AKG_Channel3_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel3_PtInstrument + PLY_AKG_Offset1b),hl
        xor a
PLY_AKG_Channel3_SetInstrumentStep:
        ld (PLY_AKG_Channel3_InstrumentStep + PLY_AKG_Offset2b),a

        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg10),a          ;Reaches register/label 8/9/10.
        
                ;Gets the R7.
                ld a,d        
        exx
                        ld (PLY_AKG_PSGReg45_Instr + PLY_AKG_Offset1b),hl
        
        
        
 
          
;Plays the sound effects, if desired.
;-------------------------------------------
       .if PLY_AKG_MANAGE_SOUND_EFFECTS
                ;IN : A = R7
                ;OUT: A = R7, possibly modified.
                call PLY_AKG_PlaySoundEffectsStream
       .endif ;PLY_AKG_MANAGE_SOUND_EFFECTS
     


; -----------------------------------------------------------------------------------
; PSG access.
; -----------------------------------------------------------------------------------

;Sends the registers to the PSG. Only general registers are sent, the specific ones have already been sent.
;IN:    A = R7.
PLY_AKG_SendPSGRegisters:
       .if PLY_AKG_HARDWARE_ENTERPRISE
PLY_AKG_SaveSP: ld sp,#0x0000
        push    af
        ld      c,#0x00
        ;Register 0 and 1.
PLY_AKG_PSGReg01_Instr: ld de,#0x0000
        call    ayRegisterWriteE
        ld      e,d
        call    ayRegisterWriteE
     
        ;Register 2 and 3.
PLY_AKG_PSGReg23_Instr: ld de,#0x0000
        call    ayRegisterWriteE
        ld      e,d
        call    ayRegisterWriteE
        
        ;Register 4 and 5.
PLY_AKG_PSGReg45_Instr: ld de,#0x0000
        call    ayRegisterWriteE
        ld      e,d
        call    ayRegisterWriteE
        
        ;Register 6.
                       .if PLY_AKG_Use_NoiseRegister         ;CONFIG SPECIFIC
PLY_AKG_PSGReg6_8_Instr: ld de,#0x0000          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg6 , PLY_AKG_PSGReg6_8_Instr + 1
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg6_8_Instr + 2
        call    ayRegisterWriteE
                       .else
                ;No noise. But R8 must still be set.
PLY_AKG_PSGReg8_Instr: ld d,#0x00
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg8_Instr + 1
                       .endif ;PLY_AKG_Use_NoiseRegister
                                
        ;Register 7. The value is A.
        pop     af
        call    ayRegisterWrite
        
        ;Register 8. The value is loaded above via HL.
        ld      e,d
        call    ayRegisterWriteE


PLY_AKG_PSGReg9_10_Instr: ld de,#0x0000          ;L is R9, H is R10. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg9 , PLY_AKG_PSGReg9_10_Instr + 1
.equ PLY_AKG_PSGReg10 , PLY_AKG_PSGReg9_10_Instr + 2
        ;Register 9.
        call    ayRegisterWriteE
        
        ;Register 10.
        ld      e,d
        call    ayRegisterWriteE

        
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;Register 11 and 12.
PLY_AKG_PSGHardwarePeriod_Instr: ld de,#0x0000
        call    ayRegisterWriteE
        ld      e,d
        call    ayRegisterWriteE

                               .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
PLY_AKG_PSGReg13_OldValue: ld a,#0xff
PLY_AKG_Retrig: or #0x00                    ;0 = no retrig. Else, should be >0xf to be sure the old value becomes a sentinel (i.e. unreachable) value.
PLY_AKG_PSGReg13_Instr: ld l,#0x00          ;Register 13.
        cp l                            ;Is the new value still the same? If yes, the new value must not be set again.
        ret z
        ;Different R13.
        ld a,l
                               .else ;PLY_CFG_UseRetrig
PLY_AKG_PSGReg13_Instr: ld a,#0x00          ;Register 13.
PLY_AKG_PSGReg13_OldValue: cp #0xff
        ret z
                               .endif ;PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
        ld (PLY_AKG_PSGReg13_OldValue + PLY_AKG_Offset1b),a

        call    ayRegisterWrite
                               .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
        xor a
        ld (PLY_AKG_Retrig + PLY_AKG_Offset1b),a
                               .endif ;PLY_CFG_UseRetrig
                       .endif ;PLY_CFG_UseHardwareSounds
                        ret
       .endif   
       
       .if PLY_AKG_HARDWARE_CPC
            ld bc,#0xf680
            ld e,#0xc0
        	out (c),e	;#f6c0          ;Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
        exx
        ld bc,#0xf401                     ;C is the PSG register.

        ;Register 0 and 1.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg01_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg01_Instr)
       .endif
        .db #0xed,#0x71     ;out (c),#0x00                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
     
        ;Register 2 and 3.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg23_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg23_Instr)
       .endif
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 4 and 5.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg45_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg45_Instr)
       .endif
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 6.
                       .if PLY_AKG_Use_NoiseRegister         ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg6_8_Instr: ld hl,#0x0000          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg6 , PLY_AKG_PSGReg6_8_Instr + 1
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg6_8_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg6_8_Instr)
       .endif
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
                       .else
                ;No noise. But R8 must still be set.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg8_Instr: ld h,#0x00
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg8_Instr + 1
       .else
        ld hl,(PLY_AKG_PSGReg6_8_Instr) ;L was not useful, but A must not be modified yet.
       .endif
                inc c
                       .endif ;PLY_AKG_Use_NoiseRegister
                                
        ;Register 7. The value is A.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),a                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 8. The value is loaded above via HL.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx

       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg9_10_Instr: ld hl,#0x0000          ;L is R9, H is R10. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg9 , PLY_AKG_PSGReg9_10_Instr + 1
.equ PLY_AKG_PSGReg10 , PLY_AKG_PSGReg9_10_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg9_10_Instr)
       .endif
        ;Register 9.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 10.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;Register 11 and 12.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGHardwarePeriod_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGHardwarePeriod_Instr)
       .endif
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx  

        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
                       .endif ;PLY_CFG_UseHardwareSounds
       .endif
       .if PLY_AKG_HARDWARE_SPECTRUM + PLY_AKG_HARDWARE_PENTAGON
        
        ex af,af'       ;Saves R7.
        ld de,#0xbfff
        ld bc,#0xfffd
        
        ld a,#0x01          ;Register.
        
        ;Register 0 and 1.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg01_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg01_Instr)
       .endif
        .db #0xed,#0x71     ;out (c),#0x00       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
        
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
      
        ;Register 2 and 3.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg23_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg23_Instr)
       .endif
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
        
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
        
        ;Register 4 and 5.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg45_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg45_Instr)
       .endif
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
        
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
        
        ;Register 6.
                       .if PLY_AKG_Use_NoiseRegister         ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg6_8_Instr: ld hl,#0x0000          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg6 , PLY_AKG_PSGReg6_8_Instr + 1
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg6_8_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg6_8_Instr)
       .endif
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
                       .else
                ;No noise. But R8 must still be set.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg8_Instr: ld h,#0x00
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg8_Instr + 1
       .else
        ld hl,(PLY_AKG_PSGReg6_8_Instr)         ;L not useful, but A needs to be not modified.
       .endif
                inc a
                       .endif ;PLY_AKG_Use_NoiseRegister
     
        ;Register 7. The value is A.
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        ex af,af'       ;Retrieves R7.
        out (c),a       ;#bffd + value
        ex af,af'
        ld b,e
        
        ;Register 8. The value is loaded above via HL.
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
        
        ;Register 9 and 10.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg9_10_Instr: ld hl,#0x0000
.equ PLY_AKG_PSGReg9 , PLY_AKG_PSGReg9_10_Instr + 1
.equ PLY_AKG_PSGReg10 , PLY_AKG_PSGReg9_10_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg9_10_Instr)
       .endif
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
        
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
        
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;Register 11 and 12.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGHardwarePeriod_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGHardwarePeriod_Instr)
       .endif
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),l       ;#bffd + value
        ld b,e
        
        inc a
        out (c),a       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
        ld b,e
                       .endif ;PLY_CFG_UseHardwareSounds

       .endif
       .if PLY_AKG_HARDWARE_MSX
       
        ld b,a          ;Preserves R7.
        ld a,7
        out (#0xa0),a     ;Register.
        ld a,b
        out (#0xa1),a     ;Value.

       .ifeq PLY_AKG_Rom
       
PLY_AKG_PSGReg01_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg01_Instr)
       .endif
        xor a
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.

        ld a,#0x01
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
        
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg23_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg23_Instr)
       .endif
        ld a,2
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.

        ld a,3
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
        
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg45_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGReg45_Instr)
       .endif
        ld a,4
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.

        ld a,5
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
        
        ;Register 6.
                       .if PLY_AKG_Use_NoiseRegister         ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg6_8_Instr: ld hl,#0x0000          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
.equ PLY_AKG_PSGReg6 , PLY_AKG_PSGReg6_8_Instr + 1
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg6_8_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg6_8_Instr)
       .endif
        ld a,6
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.
        
        ld a,#0x08
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
                       .else
                ;No noise. Takes care of R8.
                ld a,#0x08
                out (#0xa0),a     ;Register.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg8_Instr: ld a,#0x00
.equ PLY_AKG_PSGReg8 , PLY_AKG_PSGReg8_Instr + 1
       .else
        ld a,(PLY_AKG_PSGReg8)
       .endif
                out (#0xa1),a     ;Value.
                       .endif ;PLY_AKG_Use_NoiseRegister
        
        ;Register 9 and 10.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg9_10_Instr: ld hl,#0x0000
.equ PLY_AKG_PSGReg9 , PLY_AKG_PSGReg9_10_Instr + 1
.equ PLY_AKG_PSGReg10 , PLY_AKG_PSGReg9_10_Instr + 2
       .else
        ld hl,(PLY_AKG_PSGReg9_10_Instr)
       .endif
        ld a,#0x09
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.
        
        ld a,#0x0a
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
        
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;Register 11 and 12.
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGHardwarePeriod_Instr: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_PSGHardwarePeriod_Instr)
       .endif
        ld a,#0x0b
        out (#0xa0),a     ;Register.
        ld a,l
        out (#0xa1),a     ;Value.
        
        ld a,#0x0c
        out (#0xa0),a     ;Register.
        ld a,h
        out (#0xa1),a     ;Value.
                       .endif ;PLY_CFG_UseHardwareSounds
        
       .endif
        
      .ifeq PLY_AKG_HARDWARE_ENTERPRISE
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;R13.
       .if PLY_AKG_HARDWARE_MSX
        ld a,#0x0d        ;Selects R13 now, even if not changed, because A will be modified.
        out (#0xa0),a     ;Register.
       .endif
       .if PLY_AKG_HARDWARE_SPECTRUM + PLY_AKG_HARDWARE_PENTAGON
        inc a           ;Selects R13 now, even if not changed, because A will be modified.
        out (c),a       ;#fffd + register.
       .endif
       
                               .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg13_OldValue: ld a,#0xff
PLY_AKG_Retrig: or #0x00                    ;0 = no retrig. Else, should be >0xf to be sure the old value becomes a sentinel (i.e. unreachable) value.
PLY_AKG_PSGReg13_Instr: ld l,#0x00          ;Register 13.
       .else
        ld a,(PLY_AKG_PSGReg13_Instr)
        ld l,a
        ld a,(PLY_AKG_Retrig)
        ld h,a
        ld a,(PLY_AKG_PSGReg13_OldValue)
        or h
       .endif
        cp l                            ;Is the new value still the same? If yes, the new value must not be set again.
        jr z,PLY_AKG_PSGReg13_End
        ;Different R13.
        ld a,l
                               .else ;PLY_CFG_UseRetrig
       .ifeq PLY_AKG_Rom
PLY_AKG_PSGReg13_Instr: ld a,#0x00          ;Register 13.
PLY_AKG_PSGReg13_OldValue: cp #0xff
       .else
        ld a,(PLY_AKG_PSGReg13_OldValue)
        ld l,a
        ld a,(PLY_AKG_PSGReg13_Instr)
        cp l
       .endif
        jr z,PLY_AKG_PSGReg13_End
                               .endif ;PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
        ld (PLY_AKG_PSGReg13_OldValue + PLY_AKG_Offset1b),a

       .if PLY_AKG_HARDWARE_CPC
        inc c
        out (c),c                       ;#f400 + register.
        exx
                .db #0xed,#0x71     ;out (c),#0x00               ;#f600.
        exx
        out (c),a                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        ;exx
        
       .endif
       .if PLY_AKG_HARDWARE_MSX
        out (#0xa1),a     ;Value.
       .endif
       .if PLY_AKG_HARDWARE_SPECTRUM + PLY_AKG_HARDWARE_PENTAGON
        ld b,d
        out (c),a       ;#bffd + value
        
       .endif
                               .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
        xor a
        ld (PLY_AKG_Retrig + PLY_AKG_Offset1b),a
                               .endif ;PLY_CFG_UseRetrig
PLY_AKG_PSGReg13_End:
                       .endif ;PLY_CFG_UseHardwareSounds
       .ifeq PLY_AKG_Rom
PLY_AKG_SaveSP: ld sp,#0x0000
       .else
        ld sp,(PLY_AKG_SaveSp)
       .endif
        ret
      .endif
        

PLY_AKG_Channel1_MaybeEffects:
        ;There is one wait in all cases.
        ;xor a                  ;A is supposed to be 0.
        ld (PLY_AKG_Channel1_WaitCounter + PLY_AKG_Offset1b),a
                       .ifeq PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        jp PLY_AKG_Channel1_BeforeEnd_StoreCellPointer
                       .else
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel1_BeforeEnd_StoreCellPointer
        ;Manage effects.
        
;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel1_ReadEffects:
        ld iy,#PLY_AKG_Channel1_SoundStream_RelativeModifierAddress
        ld ix,#PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress
        ld de,#PLY_AKG_Channel1_BeforeEnd_StoreCellPointer
        ;Only adds a jump if this is not the last channel, as the code only need to jump below.
                jr PLY_AKG_Channel_ReadEffects
                       .endif ;PLY_CFG_UseEffects
PLY_AKG_Channel1_ReadEffectsEnd:

PLY_AKG_Channel2_MaybeEffects:
        ;There is one wait in all cases.
        ;xor a                  ;A is supposed to be 0.
        ld (PLY_AKG_Channel2_WaitCounter + PLY_AKG_Offset1b),a
                       .ifeq PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        jp PLY_AKG_Channel2_BeforeEnd_StoreCellPointer
                       .else
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel2_BeforeEnd_StoreCellPointer
        ;Manage effects.
        
;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel2_ReadEffects:
        ld iy,#PLY_AKG_Channel2_SoundStream_RelativeModifierAddress
        ld ix,#PLY_AKG_Channel2_PlayInstrument_RelativeModifierAddress
        ld de,#PLY_AKG_Channel2_BeforeEnd_StoreCellPointer
        ;Only adds a jump if this is not the last channel, as the code only need to jump below.
                jr PLY_AKG_Channel_ReadEffects
                       .endif ;PLY_CFG_UseEffects
PLY_AKG_Channel2_ReadEffectsEnd:

PLY_AKG_Channel3_MaybeEffects:
        ;There is one wait in all cases.
        ;xor a                  ;A is supposed to be 0.
        ld (PLY_AKG_Channel3_WaitCounter + PLY_AKG_Offset1b),a
                       .ifeq PLY_CFG_UseEffects                ;CONFIG SPECIFIC
        jp PLY_AKG_Channel3_BeforeEnd_StoreCellPointer
                       .else
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel3_BeforeEnd_StoreCellPointer
        ;Manage effects.
        
;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel3_ReadEffects:
        ld iy,#PLY_AKG_Channel3_SoundStream_RelativeModifierAddress
        ld ix,#PLY_AKG_Channel3_PlayInstrument_RelativeModifierAddress
        ld de,#PLY_AKG_Channel3_BeforeEnd_StoreCellPointer
        ;Only adds a jump if this is not the last channel, as the code only need to jump below.
                       .endif ;PLY_CFG_UseEffects
PLY_AKG_Channel3_ReadEffectsEnd:


        ;** NO CODE between the code above and below! **
                    
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
;IN:    HL = Points on the effect blocks
;       DE = Where to go to when over.
;       IX = Address from which the data of the instrument are modified.
;       IY = Address from which data of the channels (pitch, volume, etc) are modified.
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel_ReadEffects:
        
       .ifeq PLY_AKG_Rom
                ld (PLY_AKG_Channel_ReadEffects_EndJump + PLY_AKG_Offset1b),de
       .else
                ld (PLY_AKG_Channel_ReadEffects_EndJumpInstrAndAddress + 1),de
       .endif
        ;HL will be very useful, so we store the pointer in DE.
        ex de,hl

        ;Reads the effect block. It may be an index or a relative address.        
        ld a,(de)
        inc de
        sla a
        jr c,PLY_AKG_Channel_ReadEffects_RelativeAddress
        ;Index.
        exx
                ld l,a
                ld h,#0x00

       .ifeq PLY_AKG_Rom
PLY_AKG_Channel_ReadEffects_EffectBlocks1: ld de,#0x0000
       .else
        ld de,(PLY_AKG_Channel_ReadEffects_EffectBlocks1)
       .endif
                add hl,de               ;The index is already *2.
                ld e,(hl)               ;Gets the address referred by the table.
                inc hl
                ld d,(hl)
PLY_AKG_Channel_RE_EffectAddressKnown:
                ;DE points on the current effect block header/data.
                ld a,(de)               ;Gets the effect number/more effect flag.
                inc de
                ld (PLY_AKG_Channel_RE_ReadNextEffectInBlock + PLY_AKG_Offset1b),a     ;Stores the flag indicating whether there are more effects.
                
                ;Gets the effect number.
                and #0b11111110
                ld l,a
                ld h,#0x00
                ld sp,#PLY_AKG_EffectTable
                add hl,sp                ;Effect is already * 2.
                ld sp,hl                ;Jumps to the effect code.
                ret
                ;All the effects return here.
PLY_AKG_Channel_RE_EffectReturn:
                ;Is there another effect?
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel_RE_ReadNextEffectInBlock: ld a,#0x00                ;Bit 0 indicates whether there are more effects.
       .else
                ld a,(PLY_AKG_Channel_RE_ReadNextEffectInBlock)
       .endif
                rra
                jr c,PLY_AKG_Channel_RE_EffectAddressKnown
                ;No more effects.
        exx
        
        ;Put back in HL the point on the Track Cells.
        ex de,hl
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel_ReadEffects_EndJump: jp 0        ;PLY_AKG_Channel1/2/3_BeforeEnd_StoreCellPointer
       .else
        jp PLY_AKG_Channel_ReadEffects_EndJumpInstrAndAddress
       .endif

PLY_AKG_Channel_ReadEffects_RelativeAddress:
        srl a           ;A was the relative MSB. Only 7 relevant bits.
        exx
                ld h,a
        exx
        ld a,(de)       ;Reads the relative LSB.
        inc de
        exx
                ld l,a
       .ifeq PLY_AKG_Rom
PLY_AKG_Channel_ReadEffects_EffectBlocks2: ld de,#0x0000
       .else
        ld de,(PLY_AKG_Channel_ReadEffects_EffectBlocks1)       ;In ROM, reads the first value, it is the same. Duplicating it is only an optimization for RAM player to avoid reading memory.
       .endif
                add hl,de
                jr PLY_AKG_Channel_RE_EffectAddressKnown
                       .endif ;PLY_CFG_UseEffects





;---------------------------------
;Codes that read InstrumentCells.
;IN:    HL = pointer on the Instrument data cell to read.
;       IX = can be modified.
;       IYL = Instrument step (>=0). Useful for retrig.
;       SP = normal use of the stack, do not pervert it!
;       D = register 7, as if it was the channel 3 (so, bit 2 and 5 filled only).
;             By default, the noise is OFF, the sound is ON, so no need to do anything if these values match.
;       E = inverted volume.
;       A = SET BELOW: first byte of the data, shifted of 3 bits to the right.
;       B = SET BELOW: first byte of the data, unmodified.
;       HL' = track pitch.
;       DE' = 0 / note (instrument + Track transposition).
;       BC' = temp, use at will.

;OUT:   HL = new pointer on the Instrument (may be on the empty sound). If not relevant, any value can be returned, it doesn't matter.
;       IYL = Not 0 if retrig for this channel.
;       D = register 7, updated, as if it was the channel 1 (so, bit 2 and 5 filled only).
;       E = volume to encode (0-16).
;       HL' = software period. If not relevant, do not set it.
;       DE' = output period.

.equ PLY_AKG_BitForSound , 2
.equ PLY_AKG_BitForNoise , 5


PLY_AKG_ReadInstrumentCell:
        ld a,(hl)               ;Gets the first byte of the cell.
        inc hl
        ld b,a                  ;Stores the first byte, handy in many cases.
        
        ;What type if the cell?
        rra
        jp c,PLY_AKG_S_Or_H_Or_SaH_Or_EndWithLoop
        ;No Soft No Hard, or Soft To Hard, or Hard To Soft, or End without loop.
        rra
       .ifeq PLY_AKG_Rom
                jr c,PLY_AKG_StH_Or_EndWithoutLoop
       .else
                jp c,PLY_AKG_StH_Or_EndWithoutLoop
       .endif
        ;No Soft No Hard, or Hard to Soft.
        rra
                       .if PLY_CFG_HardToSoft       ;CONFIG SPECIFIC
        jr c,PLY_AKG_HardToSoft
                       .endif ;PLY_CFG_HardToSoft
        
        
        
        
        
        
        ;-------------------------------------------------
        ;"No soft, no hard".
        ;-------------------------------------------------
PLY_AKG_NoSoftNoHard:
        and #0b1111               ;Necessary, we don't know what crap is in the 4th bit of A.
        sub e                   ;Decreases the volume, watching for overflow.
        jr nc,. + 3
        xor a
        
        ld e,a                  ;Sets the volume.

                       .if PLY_CFG_NoSoftNoHard_Noise                ;CONFIG SPECIFIC
        rl b            ;Noise?
        jr nc,PLY_AKG_NSNH_NoNoise
        ;Noise.
        ld a,(hl)
        inc hl
        ld (PLY_AKG_PSGReg6),a
        set PLY_AKG_BitForSound,d      ;Noise, no sound (both non-default values).
        res PLY_AKG_BitForNoise,d
        ret
PLY_AKG_NSNH_NoNoise:
                       .endif ;PLY_CFG_NoSoftNoHard_Noise
        set PLY_AKG_BitForSound,d      ;No noise (default), no sound.
        ret







        ;-------------------------------------------------
        ;"Soft only".
        ;-------------------------------------------------
                       .if PLY_CFG_SoftOnly          ;CONFIG SPECIFIC
PLY_AKG_Soft:
        ;Calculates the volume.
        and #0b1111               ;Necessary, we don't know what crap is in the 4th bit of A.
        
        sub e                   ;Decreases the volume, watching for overflow.
        jr nc,. + 3             ;Checks for overflow.
        xor a
    
        ld e,a                  ;Sets the volume.
                       .endif ;PLY_CFG_SoftOnly
                       .if PLY_AKG_UseSoftOnlyOrHardOnly     ;CONFIG SPECIFIC
PLY_AKG_SoftOnly_HardOnly_TestSimple_Common:        ;This code is also used by "Hard only".
        ;Simple sound? Gets the bit, let the subroutine do the job.
        rl b
        jr nc,PLY_AKG_S_NotSimple
        ;Simple.
        ld c,#0x00                  ;This will force the noise to 0.
        jr PLY_AKG_S_AfterSimpleTest
PLY_AKG_S_NotSimple:
        ;Not simple. Reads and keeps the next byte, containing the noise. WARNING, the following code must NOT modify the Carry!
        ld b,(hl)
        ld c,b
        inc hl
PLY_AKG_S_AfterSimpleTest:

        call PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod
        
                               .if PLY_AKG_UseSoftOnlyOrHardOnly_Noise       ;CONFIG SPECIFIC
        ;Noise?
        ld a,c
        and #0b11111
        ret z                                   ;if noise not present, sound present, we can stop here, R7 is fine.
        ;Noise is present.
        ld (PLY_AKG_PSGReg6),a
        res PLY_AKG_BitForNoise,d               ;Noise present.
                               .endif ;PLY_AKG_UseSoftOnlyOrHardOnly_Noise
        ret
                       .endif ;PLY_AKG_UseSoftOnlyOrHardOnly
        




        ;-------------------------------------------------
        ;"Hard to soft".
        ;-------------------------------------------------
                       .if PLY_CFG_HardToSoft       ;CONFIG SPECIFIC
PLY_AKG_HardToSoft:
        call PLY_AKG_StoH_HToS_SandH_Common
        ;We have the ratio jump calculated and the primary period too. It must be divided to get the software frequency.
        
       .ifeq PLY_AKG_Rom
        ld (PLY_AKG_HS_JumpRatio + 1),a
       .else
        ;Stores where to jump after the JumpRatio label. Only BC' is free...
        exx
                ld bc,#PLY_AKG_HS_JumpRatio
                add a,c
                ld c,a
                ld a,b
                adc a,#0x00
                ld b,a
                ld (PLY_AKG_TempPlayInstrumentJumpInstrAndAddress + 1),bc         ;The first byte has a jump.
        exx
       .endif
        
        ;Gets B, we need the bit to know if a software pitch shift is added.
                               .if PLY_CFG_HardToSoft_SoftwarePitch  ;CONFIG SPECIFIC
        ld a,b
                               .endif ;PLY_CFG_HardToSoft_SoftwarePitch
        exx
                ;The hardware period can be stored.
                ld (PLY_AKG_PSGHardwarePeriod_Instr + PLY_AKG_Offset1b),hl
       .ifeq PLY_AKG_Rom
PLY_AKG_HS_JumpRatio: jr . + 2               ;Automodified by the line above to jump on the right code.
       .else
                jp PLY_AKG_TempPlayInstrumentJumpInstrAndAddress        ;If ROM, jumps to the buffer, it will jump back just after according to the ratio.
PLY_AKG_HS_JumpRatio:
       .endif
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                ;Any Software pitch shift?
                               .if PLY_CFG_HardToSoft_SoftwarePitch  ;CONFIG SPECIFIC
                rla
                jr nc,PLY_AKG_SH_NoSoftwarePitchShift
;Pitch shift. Reads it.
        exx
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a        
PLY_AKG_SH_NoSoftwarePitchShift:
                               .endif ;PLY_CFG_HardToSoft_SoftwarePitch
        exx
        
        ret
                       .endif ;PLY_CFG_HardToSoft
        


        ;-------------------------------------------------
        ;End without loop. Put here to satisfy the JR range below.
        ;-------------------------------------------------
PLY_AKG_EndWithoutLoop:
        ;Loops to the "empty" instrument, and makes another iteration.
       .ifeq PLY_AKG_Rom
PLY_AKG_EmptyInstrumentDataPt: ld hl,#0x0000
       .else
        ld hl,(PLY_AKG_EmptyInstrumentDataPt)
       .endif
        ;No need to read the data, consider a void value.
        inc hl
        xor a
        ld b,a
       .ifeq PLY_AKG_Rom
                jr PLY_AKG_NoSoftNoHard
       .else
                jp PLY_AKG_NoSoftNoHard
       .endif
        
        
        
        ;-----------------------------------------
PLY_AKG_StH_Or_EndWithoutLoop:
        rra
                       .ifeq PLY_CFG_SoftToHard                ;CONFIG SPECIFIC
        jr PLY_AKG_EndWithoutLoop
                       .else
        jr c,PLY_AKG_EndWithoutLoop
        
        ;-------------------------------------------------
        ;"Soft to Hard".
        ;-------------------------------------------------
                        
        call PLY_AKG_StoH_HToS_SandH_Common
        ;We have the ratio jump calculated and the primary period too. It must be divided to get the hardware frequency.

       .ifeq PLY_AKG_Rom
        ld (PLY_AKG_SH_JumpRatio + 1),a
       .else
        ;Stores where to jump after the JumpRatio label. Only BC' is free...
        exx
                ld bc,#PLY_AKG_SH_JumpRatio
                add a,c
                ld c,a
                ld a,b
                adc a,#0x00
                ld b,a
                ld (PLY_AKG_TempPlayInstrumentJumpInstrAndAddress + 1),bc         ;The first byte has a jump.
        exx
       .endif
        
        ;Gets B, we need the bit to know if a hardware pitch shift is added.
                               .if PLY_CFG_SoftToHard_HardwarePitch          ;CONFIG SPECIFIC
        ld a,b
                               .endif ;PLY_CFG_SoftToHard_HardwarePitch
        exx
                ;Saves the original frequency in DE.
                ld e,l
                ld d,h
       .ifeq PLY_AKG_Rom
PLY_AKG_SH_JumpRatio: jr . + 2               ;Automodified by the line above to jump on the right code.
       .else
                jp PLY_AKG_TempPlayInstrumentJumpInstrAndAddress        ;If ROM, jumps to the buffer, it will jump back just after according to the ratio.
PLY_AKG_SH_JumpRatio:
       .endif
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
                jr nc,PLY_AKG_SH_JumpRatioEnd
                inc hl
PLY_AKG_SH_JumpRatioEnd:
                               .if PLY_CFG_SoftToHard_HardwarePitch          ;CONFIG SPECIFIC
                ;Any Hardware pitch shift?
                rla
                jr nc,PLY_AKG_SH_NoHardwarePitchShift
                ;Pitch shift. Reads it.
        exx
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a        
PLY_AKG_SH_NoHardwarePitchShift:
                               .endif ;PLY_CFG_SoftToHard_HardwarePitch
                ld (PLY_AKG_PSGHardwarePeriod_Instr + PLY_AKG_Offset1b),hl
                
                ;Put back the frequency in HL.
                ex de,hl
        exx
        
        ret
                       .endif ;PLY_CFG_SoftToHard
        
        
        
       
PLY_AKG_S_Or_H_Or_SaH_Or_EndWithLoop:
        ;Second bit of the type.
        rra
        jr c,PLY_AKG_H_Or_EndWithLoop
        ;Third bit of the type.
        rra
                       .if PLY_CFG_SoftOnly          ;CONFIG SPECIFIC
        jp nc,PLY_AKG_Soft
                       .endif ;PLY_CFG_SoftOnly
        
                       .if PLY_CFG_SoftAndHard       ;CONFIG SPECIFIC
        ;-------------------------------------------------
        ;"Soft and Hard".
        ;-------------------------------------------------
        exx
                push hl         ;Saves the note and track pitch, because the first pass below will modify it, we need it for the second pass.
                push de
        exx
        
        call PLY_AKG_StoH_HToS_SandH_Common
        ;We have now calculated the hardware frequency. Stores it.
        exx
                ld (PLY_AKG_PSGHardwarePeriod_Instr + PLY_AKG_Offset1b),hl
                
                pop de          ;Get back the note and track pitch for the second pass.
                pop hl
        exx
        
        
        ;Now calculate the software frequency.
        rl b            ;Simple sound? Used by the sub-code.
        jp PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod    ;That's all!
                       .endif ;PLY_CFG_SoftAndHard
                
        
        

        
PLY_AKG_H_Or_EndWithLoop:
                       .if PLY_CFG_HardOnly          ;CONFIG SPECIFIC
        ;Third bit of the type. Only used for HardOnly, not in case of EndWithLoop.
        rra
                               .if PLY_CFG_UseInstrumentLoopTo       ;CONFIG SPECIFIC
        ;Ok to remove this jump if PLY_CFG_HardOnly variable absent, it will directly go to the code below.
        jr c,PLY_AKG_EndWithLoop
                               .endif

        ;-------------------------------------------------
        ;"Hard only".
        ;-------------------------------------------------
        
        ld e,#0x10                 ;Sets the hardware volume.

        ;Retrig?
        rra
                               .if PLY_CFG_HardOnly_Retrig           ;CONFIG SPECIFIC
        jr nc,PLY_AKG_H_AfterRetrig
        ld c,a
        ;Retrig is only set if we are on the first step of the instrument!
       .db #0xfd,#0x7d      ;ld a,iyl
        or a
        jr nz,PLY_AKG_H_RetrigEnd
        ld a,e
        ld (PLY_AKG_Retrig + PLY_AKG_Offset1b),a
PLY_AKG_H_RetrigEnd:
        ld a,c
PLY_AKG_H_AfterRetrig:
                               .endif ;PLY_CFG_HardOnly_Retrig

        ;Calculates the hardware envelope. The value given is from 8-15, but encoded as 0-7.
        and #0b111
        add a,#0x08
        ld (PLY_AKG_PSGReg13_Instr + PLY_AKG_Offset1b),a

        ;Use the code of Soft Only to calculate the period and the noise.
        call PLY_AKG_SoftOnly_HardOnly_TestSimple_Common

        ;The period is actually an hardware period. We don't care about the software period, the sound channel is cut.
        exx
                ld (PLY_AKG_PSGHardwarePeriod_Instr + PLY_AKG_Offset1b),hl
        exx
        
        ;Stops the sound.
        set PLY_AKG_BitForSound,d

        ret
                       .endif ;PLY_CFG_HardOnly
        
        ;** WARNING! ** Do not put instructions here between HardOnly and EndWithLoop, else conditional assembling will fail.
        
        ;-------------------------------------------------
        ;End with loop.
        ;-------------------------------------------------
                       .if PLY_CFG_UseInstrumentLoopTo       ;CONFIG SPECIFIC
PLY_AKG_EndWithLoop:
        ;Loops to the encoded pointer, and makes another iteration.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp PLY_AKG_ReadInstrumentCell
                       .endif ;PLY_CFG_UseInstrumentLoopTo
                        



     
;Common code for calculating the period, regardless of Soft or Hard. The same register constraints as the methods above apply.
;IN:    HL = the next bytes to read.
;       HL' = note + transposition.
;       B = contains three bits:
;               b7: forced period? (if yes, the two other bits are irrelevant)
;               b6: arpeggio?
;               b5: pitch?
;       C = do not modify.
;       Carry: Simple sound?
;OUT:   B = shift three times to the left.
;       C = unmodified.
;       HL = advanced.
;       HL' = calculated period.
PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod:

        ;Simple sound? Checks the carry.
                       .if PLY_AKG_UseInstrumentForcedPeriodsOrArpeggiosOrPitchs     ;CONFIG SPECIFIC
        jr nc,PLY_AKG_S_Or_H_NextByte
                       .endif ;PLY_AKG_UseInstrumentForcedPeriodsOrArpeggiosOrPitchs
        ;No more bytes to read, the sound is "simple". The software period must still be calculated.
        ;Calculates the note period from the note of the track. This is the same code as below.
        exx
                ex de,hl                        ;Now HL = track note + transp, DE is track pitch.
                add hl,hl
                ld bc,#PLY_AKG_PeriodTable
                add hl,bc
           
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                add hl,de                       ;Adds the track pitch.
        exx
        ;Important: the bits must be shifted so that B is in the same state as if it were not a "simple" sound.
        rl b
        rl b
        rl b
        ;No need to modify R7.
        ret
        
                       .if PLY_AKG_UseInstrumentForcedPeriodsOrArpeggiosOrPitchs     ;CONFIG SPECIFIC
PLY_AKG_S_Or_H_NextByte:
        ;Not simple. Reads the next bits to know if there is pitch/arp/forced software period.        
        ;Forced period?
        rl b
                       .if PLY_AKG_UseInstrumentForcedPeriods          ;CONFIG SPECIFIC
        jr c,PLY_AKG_S_Or_H_ForcedPeriod
                       .endif ;PLY_AKG_UseInstrumentForcedPeriods
        ;No forced period. Arpeggio?
        rl b
                       .if PLY_AKG_UseInstrumentArpeggios              ;CONFIG SPECIFIC
        jr nc,PLY_AKG_S_Or_H_AfterArpeggio
        ld a,(hl)
        inc hl
        exx
                add a,e                         ;We don't care about overflow, no time for that.
                ld e,a
        exx
PLY_AKG_S_Or_H_AfterArpeggio:
                       .endif ;PLY_AKG_UseInstrumentArpeggios
        ;Pitch?
        rl b
                       .if PLY_AKG_UseInstrumentPitchs                 ;CONFIG SPECIFIC
        jr nc,PLY_AKG_S_Or_H_AfterPitch
        ;Reads the pitch. Slow, but shouldn't happen so often.
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a                          ;Adds the cell pitch to the track pitch, in two passes.
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a
        exx
PLY_AKG_S_Or_H_AfterPitch:
                       .endif ;PLY_AKG_UseInstrumentPitchs
        
        ;Calculates the note period from the note of the track.
        exx
                ex de,hl                        ;Now HL = track note + transp, DE is track pitch.
                add hl,hl
                ld bc,#PLY_AKG_PeriodTable
                add hl,bc
                
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                add hl,de                       ;Adds the track pitch.
        exx

        ret
                       .endif ;PLY_AKG_UseInstrumentForcedPeriodsOrArpeggiosOrPitchs


                       .if PLY_AKG_UseInstrumentForcedPeriods          ;CONFIG SPECIFIC
PLY_AKG_S_Or_H_ForcedPeriod:
        ;Reads the period. A bit slow, but doesn't happen often.
        ld a,(hl)
        inc hl
        exx
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                ld h,a
        exx

        ;The pitch and arpeggios have been skipped, since the period is forced, the bits must be compensated.
        rl b
        rl b
        ret
                       .endif ;PLY_AKG_UseInstrumentForcedPeriods
        
        ;------------------------------------------------------------------
;Common code for SoftToHard and HardToSoft, and even Soft And Hard. The same register constraints as the methods above apply.
;OUT:   HL' = frequency.
;       A = shifted inverted ratio (xxx000), ready to be used in a JR to multiply/divide the frequency.
;       B = bit states, shifted four times to the left (for StoH/HtoS, the msb will be "pitch shift?") (hardware for SoftTohard, software for HardToSoft).
                       .if PLY_CFG_UseHardwareSounds                 ;CONFIG SPECIFIC
PLY_AKG_StoH_HToS_SandH_Common:
        ld e,#0x10                ;Sets the hardware volume.

        ;Retrig?
        rra
                               .if PLY_AKG_UseRetrig_StoH_HtoS_SandH         ;CONFIG SPECIFIC
        jr nc,PLY_AKG_SHoHS_AfterRetrig
        ld c,a
        ;Retrig is only set if we are on the first step of the instrument!
       .db #0xfd,#0x7d      ;ld a,iyl
        or a
        jr nz,PLY_AKG_SHoHS_RetrigEnd
        dec a
        ld (PLY_AKG_Retrig + PLY_AKG_Offset1b),a
PLY_AKG_SHoHS_RetrigEnd:
        ld a,c
PLY_AKG_SHoHS_AfterRetrig:
                               .endif ;PLY_AKG_UseRetrig_StoH_HtoS_SandH

        ;Calculates the hardware envelope. The value given is from 8-15, but encoded as 0-7.
        and #0b111
        add a,#0x08
        ld (PLY_AKG_PSGReg13_Instr + PLY_AKG_Offset1b),a
        
        ;Noise? If yes, reads the next byte.
        rl b
                               .if PLY_AKG_UseNoise_StoH_HtoS_SandH          ;CONFIG SPECIFIC
        jr nc,PLY_AKG_SHoHS_AfterNoise
        ;Noise is present.
        ld a,(hl)
        inc hl
        ld (PLY_AKG_PSGReg6),a
        res PLY_AKG_BitForNoise, d              ;Noise present.
PLY_AKG_SHoHS_AfterNoise:
                               .endif ;PLY_AKG_UseNoise_StoH_HtoS_SandH

        ;Read the next data byte.
        ld c,(hl)               ;C = ratio, kept for later.
        ld b,c
        inc hl
        
        rl b                    ;Simple (no need to test the other bits)? The carry is transmitted to the called code below.
        ;Call another common subcode.
        call PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod
        ;Let's calculate the hardware frequency from it.
        ld a,c                  ;Gets the ratio.
        rla
        rla
        and #0b11100
        
        ret
                       .endif ;PLY_CFG_UseHardwareSounds
        

        




        
; -----------------------------------------------------------------------------------
; Effects management.
; -----------------------------------------------------------------------------------
                       .if PLY_CFG_UseEffects                ;CONFIG SPECIFIC
;All the effects code.
PLY_AKG_EffectTable:
                       .if PLY_CFG_UseEffect_Reset           ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_ResetFullVolume                               ;0
       .dw PLY_AKG_Effect_Reset                                         ;1
                       .else
               .dw 0
               .dw 0
                       .endif ;PLY_CFG_UseEffect_Reset
        
                       .if PLY_CFG_UseEffect_SetVolume       ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_Volume                                        ;2
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_SetVolume
                        
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_ArpeggioTable                                 ;3
       .dw PLY_AKG_Effect_ArpeggioTableStop                             ;4
                       .else
               .dw 0
               .dw 0
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_PitchTable                                    ;5
       .dw PLY_AKG_Effect_PitchTableStop                                ;6
                       .else
               .dw 0
               .dw 0
                       .endif ;PLY_CFG_UseEffect_PitchTable
                       .if PLY_AKG_UseEffect_VolumeSlide     ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_VolumeSlide                                   ;7
       .dw PLY_AKG_Effect_VolumeSlideStop                               ;8
                       .else
               .dw 0
               .dw 0
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        
                       .if PLY_CFG_UseEffect_PitchUp         ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_PitchUp                                       ;9
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_PitchUp
                       .if PLY_CFG_UseEffect_PitchDown        ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_PitchDown                                     ;10
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_PitchDown
                        
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide    ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_PitchStop                                     ;11
                       .else
               .dw 0
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                        
                       .if PLY_CFG_UseEffect_PitchGlide              ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_GlideWithNote                                 ;12
       .dw PLY_AKG_Effect_GlideSpeed                                    ;13
                       .else
               .dw 0
               .dw 0
                       .endif ;PLY_CFG_UseEffect_PitchGlide
        
        
                       .if PLY_CFG_UseEffect_Legato          ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_Legato                                        ;14
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_Legato

                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed            ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_ForceInstrumentSpeed                          ;15
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
                        
                       .if PLY_CFG_UseEffect_ForceArpeggioSpeed              ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_ForceArpeggioSpeed                            ;16
                       .else
               .dw 0
                       .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
                        
                       .if PLY_CFG_UseEffect_ForcePitchTableSpeed    ;CONFIG SPECIFIC
       .dw PLY_AKG_Effect_ForcePitchSpeed                               ;17
                       .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
                        ;Last effect: no need to use padding with dw.
        
;Effects.
;----------------------------------------------------------------
;For all effects:
;IN:    DE' = Points on the data of this effect.
;       IX = Address from which the data of the instrument are modified.
;       IY = Address from which the data of the channels (pitch, volume, etc) are modified.
;       HL = Must NOT be modified.
;       WARNING, we are on auxiliary registers!

;       SP = Can be modified at will.

;OUT:   DE' = Points after on the data of this effect.
;       WARNING, remains on auxiliary registers!
;----------------------------------------------------------------

                       .if PLY_CFG_UseEffect_Reset           ;CONFIG SPECIFIC
PLY_AKG_Effect_ResetFullVolume:
        xor a           ;The inverted volume is 0 (full volume).
        jr PLY_AKG_Effect_ResetVolume_AfterReading
        
PLY_AKG_Effect_Reset:
        ld a,(de)       ;Reads the inverted volume.
        inc de
PLY_AKG_Effect_ResetVolume_AfterReading:
        ld PLY_AKG_Channel1_InvertedVolumeInteger - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        
        ;The current pitch is reset.
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
        xor a
        ld PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        ld PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),a
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide

        ld a,#PLY_AKG_OPCODE_OR_A
                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide        ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                       .endif ;PLY_CFG_UseEffect_PitchTable
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                       .endif ;PLY_AKS_UseEffect_Arpeggio
                       .if PLY_AKG_UseEffect_VolumeSlide             ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_Reset
                        
                        

                       .if PLY_CFG_UseEffect_SetVolume       ;CONFIG SPECIFIC
PLY_AKG_Effect_Volume:
        ld a,(de)       ;Reads the inverted volume.
        inc de
        
        ld PLY_AKG_Channel1_InvertedVolumeInteger - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        
                       .if PLY_AKG_UseEffect_VolumeSlide     ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_OR_A
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_SetVolume
        
        
                       .if PLY_AKS_UseEffect_Arpeggio        ;CONFIG SPECIFIC
PLY_AKG_Effect_ArpeggioTable:
        ld a,(de)       ;Reads the arpeggio table index.
        inc de
        
        ;Finds the address of the Arpeggio.
        ld l,a
        ld h,#0x00
        add hl,hl
       .ifeq PLY_AKG_Rom
PLY_AKG_ArpeggiosTable: ld bc,#0x0000
       .else
        ld bc,(PLY_AKG_ArpeggiosTable)
       .endif
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        
        ;Reads the speed.
        ld a,(bc)
        inc bc
        ld PLY_AKG_Channel1_ArpeggioTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy),a
        ld PLY_AKG_Channel1_ArpeggioBaseSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy),a
        
        ld PLY_AKG_Channel1_ArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),c
        ld PLY_AKG_Channel1_ArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),b
        ld PLY_AKG_Channel1_ArpeggioTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy),c
        ld PLY_AKG_Channel1_ArpeggioTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy),b
        
        ld PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_SCF
        xor a
        ld PLY_AKG_Channel1_ArpeggioTableCurrentStep - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        
        jp PLY_AKG_Channel_RE_EffectReturn

PLY_AKG_Effect_ArpeggioTableStop:
        ld PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_AKS_UseEffect_Arpeggio


                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
;Pitch table. Followed by the Pitch Table index.
PLY_AKG_Effect_PitchTable:
        ld a,(de)       ;Reads the Pitch table index.
        inc de
        
        ;Finds the address of the Pitch.
        ld l,a
        ld h,#0x00
        add hl,hl
       .ifeq PLY_AKG_Rom
PLY_AKG_PitchesTable: ld bc,#0x0000
       .else
        ld bc,(PLY_AKG_PitchesTable)
       .endif
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        
        ;Reads the speed.
        ld a,(bc)
        inc bc
        ld PLY_AKG_Channel1_PitchTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        ld PLY_AKG_Channel1_PitchBaseSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        
        ld PLY_AKG_Channel1_PitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),c
        ld PLY_AKG_Channel1_PitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),b
        ld PLY_AKG_Channel1_PitchTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy),c
        ld PLY_AKG_Channel1_PitchTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy),b
        
        ld PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_SCF
        
        xor a
        ld PLY_AKG_Channel1_PitchTableCurrentStep - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_PitchTable
        
                       .if PLY_CFG_UseEffect_PitchTable              ;CONFIG SPECIFIC
;Stops the pitch table.        
PLY_AKG_Effect_PitchTableStop:
        ;Only the pitch is stopped, but the value remains.
        ld PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_PitchTable

                       .if PLY_AKG_UseEffect_VolumeSlide     ;CONFIG SPECIFIC
;Volume slide effect. Followed by the volume, as a word.
PLY_AKG_Effect_VolumeSlide:
        ld a,(de)               ;Reads the slide.
        inc de
        ld PLY_AKG_Channel1_VolumeSlideValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_VolumeSlideValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),a
        
        ld PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_SCF
        jp PLY_AKG_Channel_RE_EffectReturn
        
;Volume slide stop effect.
PLY_AKG_Effect_VolumeSlideStop:
        ;Only stops the slide, don't reset the value.
        ld PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_AKG_UseEffect_VolumeSlide
  
;Pitch track effect. Followed by the pitch, as a word.
                       .if PLY_CFG_UseEffect_PitchDown        ;CONFIG SPECIFIC
PLY_AKG_Effect_PitchDown:
        ;Changes the sign of the operations.
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_ADD_HL_BC_MSB
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy), #PLY_AKG_OPCODE_ADD_HL_BC_LSB
        ld PLY_AKG_Channel1_PitchTrackDecimalInstr - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_ADD_A_IMMEDIATE
        ld PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_INC_HL
                       .endif ;PLY_CFG_UseEffect_PitchDown
                       .if PLY_AKS_UseEffect_PitchUpOrDown        ;CONFIG SPECIFIC
PLY_AKG_Effect_PitchUpDown_Common:              ;The Pitch up will jump here.
        ;Authorizes the pitch, disabled the glide.        
        ld PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_SCF
                       .if PLY_CFG_UseEffect_PitchGlide           ;CONFIG SPECIFIC
        ld PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),#0x00
                       .endif ;PLY_CFG_UseEffect_PitchGlide

        ld a,(de)       ;Reads the Pitch.
        inc de
        ld PLY_AKG_Channel1_PitchTrackDecimalValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_PitchTrack - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDown
        
                       .if PLY_CFG_UseEffect_PitchUp        ;CONFIG SPECIFIC
PLY_AKG_Effect_PitchUp:
        ;Changes the sign of the operations.
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_SBC_HL_BC_MSB
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy), #PLY_AKG_OPCODE_SBC_HL_BC_LSB
        ld PLY_AKG_Channel1_PitchTrackDecimalInstr - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_SUB_IMMEDIATE
        ld PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_DEC_HL
        jr PLY_AKG_Effect_PitchUpDown_Common
                       .endif ;PLY_CFG_UseEffect_PitchUp

                       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide    ;CONFIG SPECIFIC
;Pitch track stop. Used by Pitch up/down/glide.
PLY_AKG_Effect_PitchStop:
        ;Only stops the pitch, don't reset the value. No need to reset the Glide either.
        ld PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),#PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
        
                       .if PLY_CFG_UseEffect_PitchGlide        ;CONFIG SPECIFIC
;Glide, with a note.
PLY_AKG_Effect_GlideWithNote:
        ;Reads the note to reach.
        ld a,(de)
        inc de
        ld (PLY_AKG_Effect_GlideWithNoteSaveDE + PLY_AKG_Offset1b),de                        ;Have to save, no more registers. Damn.
        ;Finds the period related to the note, stores it.
        add a,a                 ;The note is 7 bits only, so it fits.
        ld l,a
        ld h,#0x00
        ld bc,#PLY_AKG_PeriodTable
        add hl,bc
        
        ld sp,hl
        pop de                  ;DE = period to reach.
        ld PLY_AKG_Channel1_GlideToReach - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),e
        ld PLY_AKG_Channel1_GlideToReach - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),d
        
        ;Calculates the period of the current note to calculate the difference.
        ld a,PLY_AKG_Channel1_TrackNote - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + PLY_AKG_Offset1b (ix)
        add a,a
        ld l,a
        ld h,#0x00
        add hl,bc
        
        ld sp,hl
        pop hl                  ;HL = current period.
        ;Adds the current Track Pitch to have the current period, else the direction may be biased.
        ld c,PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy)
        ld b,PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy)
        add hl,bc
        
        ;What is the difference?
        or a
        sbc hl,de
       .ifeq PLY_AKG_Rom
PLY_AKG_Effect_GlideWithNoteSaveDE: ld de,#0x0000                   ;Retrieves DE. This does not modified the Carry.
       .else
        ld de,(PLY_AKG_Effect_GlideWithNoteSaveDE)
       .endif
        jr c,PLY_AKG_Effect_Glide_PitchDown
        ;Pitch up.
        ld PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),#0x01
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_SBC_HL_BC_MSB
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy), #PLY_AKG_OPCODE_SBC_HL_BC_LSB
        ld PLY_AKG_Channel1_PitchTrackDecimalInstr - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_SUB_IMMEDIATE
        ld PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_DEC_HL
        
        ;Reads the Speed, which is actually the "pitch".
PLY_AKG_Effect_Glide_ReadSpeed:
PLY_AKG_Effect_GlideSpeed:                      ;This is an effect.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_PitchTrackDecimalValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a      ;No offset, the value is directly targeted.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_PitchTrack - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        
        ;Enables the pitch, as the Glide relies on it. The Glide is enabled below, via its direction.
        ld a,#PLY_AKG_OPCODE_SCF
        ld PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a

        jp PLY_AKG_Channel_RE_EffectReturn
PLY_AKG_Effect_Glide_PitchDown:
        ;Pitch down.
        ld PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),#0x02
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_ADD_HL_BC_MSB
        ld PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1 (iy), #PLY_AKG_OPCODE_ADD_HL_BC_LSB
        ld PLY_AKG_Channel1_PitchTrackDecimalInstr - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_ADD_A_IMMEDIATE
        ld PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0 (iy), #PLY_AKG_OPCODE_INC_HL
        jr PLY_AKG_Effect_Glide_ReadSpeed
                       .endif ;PLY_CFG_UseEffect_PitchGlide
        
        
                       .if PLY_CFG_UseEffect_Legato          ;CONFIG SPECIFIC
;Legato. Followed by the note to play.        
PLY_AKG_Effect_Legato:
        ;Reads and sets the new note to play.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_TrackNote - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + PLY_AKG_Offset1b (ix),a
        
        ;Stops the Pitch effect, resets the Pitch.
                               .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide    ;CONFIG SPECIFIC
        ld a,#PLY_AKG_OPCODE_OR_A
        ld PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
        xor a
        ld PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b (iy),a
        ld PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + PLY_AKG_Offset1b + 1 (iy),a
                               .endif ;PLY_AKS_UseEffect_PitchUpOrDownOrGlide
                                
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_Legato


                       .if PLY_CFG_UseEffect_ForceInstrumentSpeed    ;CONFIG SPECIFIC
;Forces the Instrument Speed. Followed by the speed.
PLY_AKG_Effect_ForceInstrumentSpeed:
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_InstrumentSpeed - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + PLY_AKG_Offset1b (ix),a
        
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
        
                        
                       .if PLY_CFG_UseEffect_ForceArpeggioSpeed      ;CONFIG SPECIFIC
;Forces the Arpeggio Speed. Followed by the speed.
PLY_AKG_Effect_ForceArpeggioSpeed:
                               .if PLY_AKS_UseEffect_Arpeggio                ;CONFIG SPECIFIC
                                ;Is IT possible to use a Force Arpeggio even if there is no Arpeggio. Unlikely, but...
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_ArpeggioTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                               .else
                inc de
                               .endif ;PLY_AKS_UseEffect_Arpeggio
        
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed

                       .if PLY_CFG_UseEffect_ForcePitchTableSpeed    ;CONFIG SPECIFIC
;Forces the Pitch Speed. Followed by the speed.
PLY_AKG_Effect_ForcePitchSpeed:
                               .if PLY_CFG_UseEffect_PitchTable                ;CONFIG SPECIFIC
                                ;Is IT possible to use a Force Arpeggio even if there is no Arpeggio. Unlikely, but...
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld PLY_AKG_Channel1_PitchTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress (iy),a
                               .else
                inc de
                               .endif ;PLY_CFG_UseEffect_PitchTable
        
        jp PLY_AKG_Channel_RE_EffectReturn
                       .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
        
                       .endif ;PLY_CFG_UseEffects                ;CONFIG SPECIFIC

        

                       .if PLY_CFG_UseEventTracks            ;CONFIG SPECIFIC
                       .ifeq PLY_AKG_Rom
PLY_AKG_Event: .db 0         ;Possible event sent from the music for the caller to interpret.
                       .endif
                       .endif ;PLY_CFG_UseEventTracks




;The period table for each note (from 0 to 127 included).
PLY_AKG_PeriodTable:
       .if PLY_AKG_HARDWARE_CPC + PLY_AKG_HARDWARE_ENTERPRISE
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
       .if PLY_AKG_HARDWARE_SPECTRUM + PLY_AKG_HARDWARE_MSX
        ;PSG running to 1773400 Hz.
	dw 6778, 6398, 6039, 5700, 5380, 5078, 4793, 4524, 4270, 4030, 3804, 3591	; Octave 0
	dw 3389, 3199, 3019, 2850, 2690, 2539, 2397, 2262, 2135, 2015, 1902, 1795	; Octave 1
	dw 1695, 1599, 1510, 1425, 1345, 1270, 1198, 1131, 1068, 1008, 951, 898	; Octave 2
	dw 847, 800, 755, 712, 673, 635, 599, 566, 534, 504, 476, 449	; Octave 3
	dw 424, 400, 377, 356, 336, 317, 300, 283, 267, 252, 238, 224	; Octave 4
	dw 212, 200, 189, 178, 168, 159, 150, 141, 133, 126, 119, 112	; Octave 5
	dw 106, 100, 94, 89, 84, 79, 75, 71, 67, 63, 59, 56	; Octave 6
	dw 53, 50, 47, 45, 42, 40, 37, 35, 33, 31, 30, 28	; Octave 7
	dw 26, 25, 24, 22, 21, 20, 19, 18, 17, 16, 15, 14	; Octave 8
	dw 13, 12, 12, 11, 11, 10, 9, 9, 8, 8, 7, 7	; Octave 9
	dw 7, 6, 6, 6, 5, 5, 5, 4	; Octave 10
       .endif
       .if PLY_AKG_HARDWARE_PENTAGON
        ;PSG running to 1750000 Hz.
       .dw 6689, 6314, 5959, 5625, 5309, 5011, 4730, 4464, 4214, 3977, 3754, 3543	; Octave 0
	dw 3344, 3157, 2980, 2812, 2655, 2506, 2365, 2232, 2107, 1989, 1877, 1772	; Octave 1
	dw 1672, 1578, 1490, 1406, 1327, 1253, 1182, 1116, 1053, 994, 939, 886	; Octave 2
	dw 836, 789, 745, 703, 664, 626, 591, 558, 527, 497, 469, 443	; Octave 3
	dw 418, 395, 372, 352, 332, 313, 296, 279, 263, 249, 235, 221	; Octave 4
	dw 209, 197, 186, 176, 166, 157, 148, 140, 132, 124, 117, 111	; Octave 5
	dw 105, 99, 93, 88, 83, 78, 74, 70, 66, 62, 59, 55	; Octave 6
	dw 52, 49, 47, 44, 41, 39, 37, 35, 33, 31, 29, 28	; Octave 7
	dw 26, 25, 23, 22, 21, 20, 18, 17, 16, 16, 15, 14	; Octave 8
	dw 13, 12, 12, 11, 10, 10, 9, 9, 8, 8, 7, 7	; Octave 9
	dw 7, 6, 6, 5, 5, 5, 5, 4	; Octave 10
       .endif



;Buffer used for the ROM player. This part needs to be set to RAM. PLY_AKG_ROM_Buffer must be set.
       .if PLY_AKG_Rom
        
        PLY_AKG_BufferOffset = 0

;Generic data.
       .if PLY_CFG_UseRetrig
.equ PLY_AKG_Event                                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_CurrentSpeed                           , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_BaseNoteIndex                          , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_PatternDecreasingHeight                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_TickDecreasingCounter                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_CFG_UseSpeedTracks
.equ PLY_AKG_SpeedTrack_WaitCounter                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEventTracks
.equ PLY_AKG_EventTrack_WaitCounter                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseHardwareSounds
.equ PLY_AKG_PSGReg13_OldValue                      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_PSGReg13_Instr                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
               .if PLY_CFG_UseRetrig
.equ PLY_AKG_Retrig                                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
               .endif
       .endif
.equ PLY_AKG_Channel_RE_ReadNextEffectInBlock       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
        ;Words
.equ PLY_AKG_ReadLinker_PtLinker                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_CFG_UseSpeedTracks
.equ PLY_AKG_SpeedTrack_PtTrack                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_CFG_UseEventTracks
.equ PLY_AKG_EventTrack_PtTrack                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_ArpeggiosTable                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_PitchesTable                           , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_InstrumentsTable                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_CFG_UseEffects
        ;For ROM, only one is used, the second is the same, but it makes it faster on non-ROM as it avoid reading the memory.
.equ PLY_AKG_Channel_ReadEffects_EffectBlocks1      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_EmptyInstrumentDataPt                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_SaveSp                                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg01_Instr                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg23_Instr                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg45_Instr                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg6_8_Instr                        , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg6                                , PLY_AKG_PSGReg6_8_Instr + 0
.equ PLY_AKG_PSGReg8                                , PLY_AKG_PSGReg6_8_Instr + 1
.equ PLY_AKG_PSGReg9_10_Instr                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_PSGReg9                                , PLY_AKG_PSGReg9_10_Instr + 0
.equ PLY_AKG_PSGReg10                               , PLY_AKG_PSGReg9_10_Instr + 1
       .if PLY_CFG_UseHardwareSounds
.equ PLY_AKG_PSGHardwarePeriod_Instr                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_Channel_ReadEffects_EndJumpInstrAndAddress , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3      ;3 bytes. JP xxxx
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Effect_GlideWithNoteSaveDE             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_TempPlayInstrumentJumpInstrAndAddress  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3      ;3 bytes. JP xxxx

        ;Section specific to each channel.
.equ PLY_AKG_Channel1_SoundStream_RelativeModifierAddress       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset
.equ PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset

        ;Bytes
       .if PLY_CFG_UseTranspositions
.equ PLY_AKG_Channel1_Transposition                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel1_WaitCounter                   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKG_UseEffect_VolumeSlide
.equ PLY_AKG_Channel1_IsVolumeSlide                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel1_IsArpeggioTable               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel1_IsPitchTable                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel1_IsPitch                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_ForceInstrumentSpeed
.equ PLY_AKG_Channel1_InstrumentOriginalSpeed       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel1_InstrumentSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_InstrumentStep                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel1_ArpeggioTableCurrentStep      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_GeneratedCurrentArpNote       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_ArpeggioBaseSpeed             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_ArpeggioTableSpeed            , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel1_PitchTableCurrentStep         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_PitchBaseSpeed                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_PitchTableSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel1_PitchTrackDecimal             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_PitchTrackDecimalCounter      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel1_TrackNote                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel1_GlideDirection                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel1_GeneratedCurrentInvertedVolume    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
        ;Words
.equ PLY_AKG_Channel1_PtTrack                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel1_ArpeggioTable                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_ArpeggioTableBase             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel1_PitchTrack                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel1_PitchTable                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_PitchTableBase                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_Channel1_EffectBlocks1                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_EffectBlocks2                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_Pitch                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_PtInstrument                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_PtBaseInstrument              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_VolumeSlideValue              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel1_GlideToReach                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_Glide_SaveHL                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel1_PitchTrackDecimalInstrAndValue    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2     ;Add/sub b, xx.
.equ PLY_AKG_Channel1_PitchTrackDecimalInstr        , PLY_AKG_Channel1_PitchTrackDecimalInstrAndValue + 0
.equ PLY_AKG_Channel1_PitchTrackDecimalValue        , PLY_AKG_Channel1_PitchTrackDecimalInstrAndValue + 1
        ;The add/sub must be followed by the return JP.
.equ PLY_AKG_Channel1_PitchTrackDecimalInstrAndValueReturnJp    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3  ;JP xxxx.
       .endif
        
.equ PLY_AKG_Channel1_GeneratedCurrentPitch         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
        ;3 bytes.
.equ PLY_AKG_Channel1_PitchTrackAfterAddOrSbcJumpInstrAndAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
.equ PLY_AKG_Channel1_PitchTrackIntegerAddOrSub     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
       .endif

.equ PLY_AKG_Channel1_SoundStream_RelativeModifierAddress       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset
.equ PLY_AKG_Channel2_PlayInstrument_RelativeModifierAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset

        ;Bytes
       .if PLY_CFG_UseTranspositions
.equ PLY_AKG_Channel2_Transposition                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel2_WaitCounter                   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKG_UseEffect_VolumeSlide
.equ PLY_AKG_Channel2_IsVolumeSlide                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel2_IsArpeggioTable               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel2_IsPitchTable                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel2_IsPitch                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_ForceInstrumentSpeed
.equ PLY_AKG_Channel2_InstrumentOriginalSpeed       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel2_InstrumentSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_InstrumentStep                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel2_ArpeggioTableCurrentStep      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_GeneratedCurrentArpNote       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_ArpeggioBaseSpeed             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_ArpeggioTableSpeed            , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel2_PitchTableCurrentStep         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_PitchBaseSpeed                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_PitchTableSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel2_PitchTrackDecimal             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_PitchTrackDecimalCounter      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel2_TrackNote                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel2_GlideDirection                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel2_GeneratedCurrentInvertedVolume    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
        ;Words
.equ PLY_AKG_Channel2_PtTrack                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel2_ArpeggioTable                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_ArpeggioTableBase             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel2_PitchTrack                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel2_PitchTable                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_PitchTableBase                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_Channel2_EffectBlocks1                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_EffectBlocks2                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_Pitch                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_PtInstrument                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_PtBaseInstrument              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_VolumeSlideValue              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel2_GlideToReach                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_Glide_SaveHL                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel2_PitchTrackDecimalInstrAndValue    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2     ;Add/sub b, xx.
.equ PLY_AKG_Channel2_PitchTrackDecimalInstr        , PLY_AKG_Channel2_PitchTrackDecimalInstrAndValue + 0
.equ PLY_AKG_Channel2_PitchTrackDecimalValue        , PLY_AKG_Channel2_PitchTrackDecimalInstrAndValue + 1
        ;The add/sub must be followed by the return JP.
.equ PLY_AKG_Channel2_PitchTrackDecimalInstrAndValueReturnJp    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3  ;JP xxxx.
       .endif
        
.equ PLY_AKG_Channel2_GeneratedCurrentPitch         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel2_PitchTrackAddOrSbc_16bits     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
        ;3 bytes.
.equ PLY_AKG_Channel2_PitchTrackAfterAddOrSbcJumpInstrAndAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
.equ PLY_AKG_Channel2_PitchTrackIntegerAddOrSub     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
       .endif

.equ PLY_AKG_Channel1_SoundStream_RelativeModifierAddress       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset
.equ PLY_AKG_Channel3_PlayInstrument_RelativeModifierAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset

        ;Bytes
       .if PLY_CFG_UseTranspositions
.equ PLY_AKG_Channel3_Transposition                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel3_WaitCounter                   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKG_UseEffect_VolumeSlide
.equ PLY_AKG_Channel3_IsVolumeSlide                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel3_IsArpeggioTable               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel3_IsPitchTable                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel3_IsPitch                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_ForceInstrumentSpeed
.equ PLY_AKG_Channel3_InstrumentOriginalSpeed       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel3_InstrumentSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_InstrumentStep                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel3_ArpeggioTableCurrentStep      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_GeneratedCurrentArpNote       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_ArpeggioBaseSpeed             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_ArpeggioTableSpeed            , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel3_PitchTableCurrentStep         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_PitchBaseSpeed                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_PitchTableSpeed               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel3_PitchTrackDecimal             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_PitchTrackDecimalCounter      , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel3_TrackNote                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel3_GlideDirection                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif
.equ PLY_AKG_Channel3_GeneratedCurrentInvertedVolume    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
        ;Words
.equ PLY_AKG_Channel3_PtTrack                       , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_Arpeggio
.equ PLY_AKG_Channel3_ArpeggioTable                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_ArpeggioTableBase             , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel3_PitchTrack                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_CFG_UseEffect_PitchTable
.equ PLY_AKG_Channel3_PitchTable                    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_PitchTableBase                , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
.equ PLY_AKG_Channel3_EffectBlocks1                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_EffectBlocks2                 , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal   , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_Pitch                         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_PtInstrument                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_PtBaseInstrument              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_VolumeSlideValue              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_CFG_UseEffect_PitchGlide
.equ PLY_AKG_Channel3_GlideToReach                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_Glide_SaveHL                  , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .endif
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel3_PitchTrackDecimalInstrAndValue    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2     ;Add/sub b, xx.
.equ PLY_AKG_Channel3_PitchTrackDecimalInstr        , PLY_AKG_Channel3_PitchTrackDecimalInstrAndValue + 0
.equ PLY_AKG_Channel3_PitchTrackDecimalValue        , PLY_AKG_Channel3_PitchTrackDecimalInstrAndValue + 1
        ;The add/sub must be followed by the return JP.
.equ PLY_AKG_Channel3_PitchTrackDecimalInstrAndValueReturnJp    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3  ;JP xxxx.
       .endif
        
.equ PLY_AKG_Channel3_GeneratedCurrentPitch         , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
       .if PLY_AKS_UseEffect_PitchUpOrDownOrGlide
.equ PLY_AKG_Channel3_PitchTrackAddOrSbc_16bits     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
        ;3 bytes.
.equ PLY_AKG_Channel3_PitchTrackAfterAddOrSbcJumpInstrAndAddress    , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
.equ PLY_AKG_Channel3_PitchTrackIntegerAddOrSub     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_PitchTrackIntegerAfterAddOrSubJumpInstrAndAddress , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3     ;3 bytes. JP xxxx.
       .endif

        ;The buffers for sound effects (if any), for each channel. They are treated apart, because they must be consecutive.
       .if PLY_AKG_MANAGE_SOUND_EFFECTS
.equ PLY_AKG_PtSoundEffectTable                     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_SoundEffectData               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel1_SoundEffectInvertedVolume     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_SoundEffectCurrentStep        , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel1_SoundEffectSpeed              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
               PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3 ;Padding of 3, but only necessary for channel 1 and 2.
.equ PLY_AKG_Channel2_SoundEffectData               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel2_SoundEffectInvertedVolume     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_SoundEffectCurrentStep        , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel2_SoundEffectSpeed              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
               PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 3 ;Padding of 3, but only necessary for channel 1 and 2.
.equ PLY_AKG_Channel3_SoundEffectData               , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 2
.equ PLY_AKG_Channel3_SoundEffectInvertedVolume     , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_SoundEffectCurrentStep        , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
.equ PLY_AKG_Channel3_SoundEffectSpeed              , PLY_AKG_ROM_Buffer + PLY_AKG_BufferOffset : PLY_AKG_BufferOffset = PLY_AKG_BufferOffset + 1
       .endif


       .endif ;PLY_AKG_Rom


PLY_AKG_End:

; =============================================================================
 .if PLY_AKG_HARDWARE_ENTERPRISE
  .ifeq NO_ENVELOPE_IRQ

envelopeInterrupt:

        push  hl
        push  bc
envelopeInterrupt.l1:    ld    hl,#0x0000                 ; * envelope counter
      .if ENABLE_1000HZ_IRQ
        ld    bc, #65536 - (((#62500 * #ENV_SRATE_DIV) + #500) / #1000)
      .else
        .if ENABLE_300HZ_IRQ
        ld    bc, #65536 - (((#62500 * #ENV_SRATE_DIV) + #150) / #300)
        .else
        ld    bc, #65536 - (((#62500 * #ENV_SRATE_DIV) + #25) / #50)
        .endif
      .endif
        add   hl, bc
envelopeInterrupt.l2:    jr    c, envelopeInterrupt.l19                   ; * JR if envelope is stopped
envelopeInterrupt.l3:    ld    bc, #0xffff               ; * envelope frequency
envelopeInterrupt.l4:    ld    a,#0x00                   ; * envelope state (0 to 15)
envelopeInterrupt.l5:    dec   a                         ; * envelope direction (INC A or DEC A)
        add   hl, bc
        jr    nc, envelopeInterrupt.l5
        ld    (envelopeInterrupt.l1 + 1), hl
        cp    #0x10
envelopeInterrupt.l6:    jr    nc, envelopeInterrupt.l21                  ; * envelope mode
envelopeInterrupt.l7:    ld    (envelopeInterrupt.l4 + 1), a
envelopeInterrupt.l8:    add   a,#<ayVolumeTable
        ld    l, a
        adc   a, #>ayVolumeTable
        sub   l
        ld    h,a
        or    a
envelopeInterrupt.l9:
        ld    a, (hl)
        pop   bc
envelopeInterrupt.l10:   jr    envelopeInterrupt.l12                      ; * envelope enable mode
envelopeInterrupt.l11:   out   (#0xa8 + ayDaveChnA), a    ; envelope on channel A only
    .ifeq ENABLE_STEREO
        out   (#0xac + ayDaveChnA), a
    .endif
envelopeInterrupt.l12:   pop   hl
        ret
envelopeInterrupt.l13:   out   (#0xa8 + ayDaveChnA), a    ; envelope on channels A and B
    .ifeq ENABLE_STEREO
        out   (#0xac + ayDaveChnA), a
    .endif
envelopeInterrupt.l14:
    .ifne ENABLE_STEREO
        ld    l, a                      ; envelope on channel B only (Carry=0)
        rra
        scf
        adc   a, l
        rra
    .endif
        out   (#0xa8 + ayDaveChnB), a
        out   (#0xac + ayDaveChnB), a
        pop   hl
        ret
envelopeInterrupt.l15:   out   (#0xa8 + ayDaveChnA), a    ; envelope on channels A and C
    .ifeq ENABLE_STEREO
        out   (#0xac + ayDaveChnA), a
    .endif
envelopeInterrupt.l16:
    .ifeq ENABLE_STEREO
        out   (#0xa8 + ayDaveChnC), a
    .endif
        out   (#0xac + ayDaveChnC), a    ; envelope on channel C only
        pop   hl
        ret
envelopeInterrupt.l17:   out   (#0xa8 + ayDaveChnA), a    ; envelope on channels A, B, and C
    .ifeq ENABLE_STEREO
        out   (#0xac + ayDaveChnA), a
    .endif
envelopeInterrupt.l18:
    .ifeq ENABLE_STEREO
        out   (#0xa8 + ayDaveChnC), a
    .endif
        out   (#0xac + ayDaveChnC), a    ; envelope on channels B and C
    .ifne ENABLE_STEREO
        ld    l, a                      ; NOTE: Carry is always 0 here
        rra
        scf
        adc   a, l
        rra
    .endif
        out   (#0xa8 + ayDaveChnB), a
        out   (#0xac + ayDaveChnB), a
        pop   hl
        ret
envelopeInterrupt.l19:   ld    (envelopeInterrupt.l1 + 1), hl
        pop   bc
        pop   hl
        ret
envelopeInterrupt.l20:   ld    l, #<(ayVolumeTable + 15)       ; envelope modes 11 and 13
        .db  #0x01                      ; = LD BC, nnnn
envelopeInterrupt.l21:   ld    l, #<ayVolumeTable      ; envelope modes 0 to 7, 9, and 15
        ld    h, #>ayVolumeTable
        ld    a, #0x18                  ; = JR +nn
        ld    (envelopeInterrupt.l2), a                  ; stop envelope
        jp    envelopeInterrupt.l9
envelopeInterrupt.l22:   and   #0x0f                     ; envelope modes 8 and 12
        jp    envelopeInterrupt.l7
envelopeInterrupt.l23:   jp    m, envelopeInterrupt.l24                   ; envelope modes 10 and 14
        xor   #0x1f
        ld    l, a
        ld    h,#0x3d                   ; set direction to DEC A
        ld    (envelopeInterrupt.l4 + 1), hl             ; assume .l5 = .l4 + 2
        jp    envelopeInterrupt.l8
envelopeInterrupt.l24:   cpl
        ld    l, a
        ld    h,#0x3c                   ; set direction to INC A
        ld    (envelopeInterrupt.l4 + 1), hl
        jp    envelopeInterrupt.l8

  .endif
; -----------------------------------------------------------------------------

ayVolumeTable:
        .db   0,  1,  2,  3,  4,  5,  6,  9
        .db  12, 17, 22, 28, 36, 44, 53, 63

ayRegisterMaskTable:
        .db  #0xff,#0x0f,#0xff,#0x0f,#0xff,#0x0f,#0x1f,#0xff
        .db  #0x1f,#0x1f,#0x1f,#0xff,#0xff,#0x0f,#0xff,#0xff

ayRegisters:
        .db  #0x00,#0x00,#0x00,#0x00,#0x00,#0x00,#0x00,#0x00
        .db  #0x00,#0x00,#0x00,#0x00,#0x00,#0x00,#0x00,#0x00

ayRegWriteTable:
        .db  <(ayRegisterWrite.l3 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l3 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l4 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l4 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l6 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l6 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l7 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l5 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l9 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l10 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l11 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l12 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l12 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l15 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l8 - (ayRegisterWrite.l1 + 2))
        .db  <(ayRegisterWrite.l8 - (ayRegisterWrite.l1 + 2))


    .ifeq NO_ENVELOPE_IRQ

envelopeModeTable:
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l22 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l23 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l20 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l22 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l20 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l23 - (envelopeInterrupt.l6 + 2))
        .db  <(envelopeInterrupt.l21 - (envelopeInterrupt.l6 + 2))

envelopeEnableTable:
        .db  <(envelopeInterrupt.l12 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l11 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l14 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l13 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l16 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l15 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l18 - envelopeInterrupt.l11)
        .db  <(envelopeInterrupt.l17 - envelopeInterrupt.l11)

    .endif

setChannelAmplitude:
        cp    #0x10
        jr    c, setChannelAmplitude.l1
    .ifeq NO_ENVELOPE_IRQ
        res   3, b
        ld    a, (envelopeInterrupt.l4 + 1)
    .else
        xor   a
    .endif
setChannelAmplitude.l1:                                    ; HL = ayRegWriteTable + (8 + channel)
        add     a,#<ayVolumeTable
        ld      l,a
        adc     a,#>ayVolumeTable
        sub     l
        ld      h,a
    .ifne ENABLE_STEREO
        bit     0,c                     ; Z = 0: channel B, Z = 1: channel A, C
    .endif
        ld    a, (hl)
    .ifne ENABLE_STEREO 
        jr    z, setChannelAmplitude.l2
        or    a
        ld    l, a                      ; NOTE: Carry is always 0 here
        rra
        scf
        adc   a, l
        rra
    .endif
        out   (c), a
        set   2, c
setChannelAmplitude.l2:    out   (c), a
    .ifeq NO_ENVELOPE_IRQ
setChannelAmplitude.l3:    ld      a,#0x00                   ; *
        ld      c,a
        or      b
        cp      #0x08
        jr      c,setChannelAmplitude.l4
        xor     b
setChannelAmplitude.l4:    cp      c
        jr      z, setChannelAmplitude.l5                    ; envelope enable bit has not changed ?
        ld      (setChannelAmplitude.l3+1), a
        ld      c,a
        ld      b,#0x00
        ld      hl,#envelopeEnableTable
        add     hl,bc
        ld      a,(hl)
        ld      (envelopeInterrupt.l10+1),a
    .endif
setChannelAmplitude.l5:    pop   bc
;        pop   af
        ret

setChannelAFreq:
        ld    c, #0xa0 + (ayDaveChnA * 2)
        ld    a, (ayRegisters + 7)
        ld    hl, (ayRegisters)
    .if toneAndNoiseModeAtone
        rrca
        jr    nc, setToneGenFrequency   ; tone generator enabled ?
        and   #0x04
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
    .endif
    .if toneAndNoiseModeAnoise
        bit   3, a
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
        rrca
        jr    nc, setToneGenFrequency   ; tone generator enabled ?
    .endif
    .if toneAndNoiseModeAtnns
        and   #0x09
        jr    z, setToneGenAAsNoise     ; tone + noise generator enabled ?
        cp    #0x08
        jr    z, setToneGenFrequency    ; tone generator only ?
        jr    c, setNoiseGenFreq        ; noise generator only ?
    .endif
        xor   a                         ; channel disabled
        out   (#0xa0 + (ayDaveChnA * 2)), a
        out   (#0xa1 + (ayDaveChnA * 2)), a
        ret

setChannelBFreq:
        ld    c, #0xa0 + (ayDaveChnB * 2)
        ld    a, (ayRegisters + 7)
        ld    hl, (ayRegisters + 2)
    .if toneAndNoiseModeBtone
        bit   1, a
        jr    z, setToneGenFrequency    ; tone generator enabled ?
        and   #0x10
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
    .endif
    .if toneAndNoiseModeBnoise
        bit   4, a
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
        and   #0x02
        jr    z, setToneGenFrequency    ; tone generator enabled ?
    .endif
    .if toneAndNoiseModeBtnns
        and   #0x12
        jr    z, setToneGenBAsNoise     ; tone + noise generator enabled ?
        cp    #0x10
        jr    z, setToneGenFrequency    ; tone generator only ?
        jr    c, setNoiseGenFreq        ; noise generator only ?
    .endif
        xor   a                         ; channel disabled
        out   (#0xa0 + (ayDaveChnB * 2)), a
        out   (#0xa1 + (ayDaveChnB * 2)), a
        ret

setChannelCFreq:
        ld    c, #0xa0 + (ayDaveChnC * 2)
        ld    a, (ayRegisters + 7)
        ld    hl, (ayRegisters + 4)
    .if toneAndNoiseModeCtone
        bit   2, a
        jr    z, setToneGenFrequency    ; tone generator enabled ?
        and   #0x20
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
    .endif
    .if toneAndNoiseModeCnoise
        bit   5, a
        jr    z, setNoiseGenFreq        ; noise generator enabled ?
        and   #0x04
        jr    z, setToneGenFrequency    ; tone generator enabled ?
    .endif
    .if toneAndNoiseModeCtnns
        and   #0x24
        jr    z, setToneGenCAsNoise     ; tone + noise generator enabled ?
        cp    #0x20
        jr    z, setToneGenFrequency    ; tone generator only ?
        jr    c, setNoiseGenFreq        ; noise generator only ?
    .endif
        xor   a                         ; channel disabled
        out   (#0xa0 + (ayDaveChnC * 2)), a
        out   (#0xa1 + (ayDaveChnC * 2)), a
        ret

    .if toneAndNoiseModeAtnns
setToneGenAAsNoise:
        ld    a,#0x30
        jp    setToneGenFrequency_
    .endif

    .if toneAndNoiseModeBtnns
setToneGenBAsNoise:
        ld    a,#0x30
        jp    setToneGenFrequency_
    .endif

    .if toneAndNoiseModeCtnns
setToneGenCAsNoise:
        ld    a,#0x30
        .db   #0xfe                      ; = CP nn
    .endif

setToneGenFrequency:
    .if toneAndNoiseModeAtnns + toneAndNoiseModeAtnns + toneAndNoiseModeAtnns
        xor   a
    .endif

setToneGenFrequency_:
        add   hl, hl
        dec   hl
        bit   4, h
        jr    nz, setToneGenFrequency_.l2                   ; overflow ?
setToneGenFrequency_.l1:
    .if toneAndNoiseModeAtnns + toneAndNoiseModeAtnns + toneAndNoiseModeAtnns
        or    h                         ; non-zero for tone + noise
    .endif
        out   (c), l
        inc   c
    .if toneAndNoiseModeAtnns + toneAndNoiseModeAtnns + toneAndNoiseModeAtnns
        out   (c), a
    .else
        out   (c), h
    .endif
        ret
setToneGenFrequency_.l2:    ld    l,#0x01
        inc   h
        jr    z, setToneGenFrequency_.l1
        ld    hl,#0x0fff
        jp    setToneGenFrequency_.l1

    .if (toneAndNoiseModeAtnns * toneAndNoiseModeAnoise)
setToneGenAAsNoise:
        ld    h,#0x30
        jp    setNoiseGenFreq_
    .endif

    .if (toneAndNoiseModeBtnns * toneAndNoiseModeBnoise)
setToneGenBAsNoise:
        ld    h,#0x30
        jp    setNoiseGenFreq_
    .endif

    .if (toneAndNoiseModeCtnns * toneAndNoiseModeCnoise)
setToneGenCAsNoise:
        ld    h,#0x30
        jp    setNoiseGenFreq_
    .endif

setNoiseGenFreq:
        ld    h,#0x30

setNoiseGenFreq_:
        ld    a, (ayRegisters + 6)
        add   a, a
        add   a, a
        jr    nz, setNoiseGenFreq_.l1
        ld    a,#0x04
setNoiseGenFreq_.l1:    dec   a
        out   (c), a
        inc   c
        out   (c), h
        ret
; -----------------------------------------------------------------------------
; reset AY-3-8912 emulation

ayReset:
;        di
        ld    hl, #ayRegisters - 1
        ld    bc, #0x10af
        xor   a
ayReset.l1:    inc   hl
        out   (c), a
        ld    (hl), a
        dec   c
        djnz  ayReset.l1
        res   3, l                      ; register 7
        ld    (hl), #0x3f
    .ifeq NO_ENVELOPE_IRQ
        ld    (envelopeInterrupt.l4 + 1), a
        ld    a, #0x18                    ; = JR +nn
        ld    (envelopeInterrupt.l2), a
        ld    hl, #MIN_ENV_FREQVAL
        ld    (envelopeInterrupt.l3 + 1), hl
        ld    a, #<(envelopeInterrupt.l12 - envelopeInterrupt.l11)
        ld    (envelopeInterrupt.l10 + 1), a
        xor     a
        ld    (setChannelAmplitude.l3 + 1), a
        ld      a,#0xc3
        ld      hl,#envelopeInterrupt
        ld      (#0x0029),hl
        ld      (#0x0028),a
    .endif
        ld    a, #0x04
        out   (#0xbf), a
        ld    c, b
        call  ayReset.l2
        ld    l, b
        call  ayReset.l2                       ; L = 1 kHz interrupts per video frame
        ld    a, #25
        cp    l
        ld    a, #0x03
        rla
        rla
        out   (#0xbf), a                 ; Z80 <= 5 MHz: 04h, > 5 MHz: 06h
        ld    a, #0x10                    ; use 17-bit noise generator
        out   (#0xa6), a
    .ifeq NO_ENVELOPE_IRQ
        ld    a, #0x33
    .else
        ld    a, #0x30
    .endif
        out   (#0xb4), a                 ; enable 1 kHz and video interrupts
        ret
ayReset.l2:    in    a, (#0xb4)
        and   #0x11
        or    c
        rlca
        and   #0x66
        ld    c, a                      ; -ON--ON-
        rlca                            ; ON--ON--
        xor   c                         ; OXN-OXN-
        bit   2, a
        jr    z, ayReset.l3
        inc   l                         ; 1 kHz interrupt
ayReset.l3:    cp    #0xc0
        jr    c, ayReset.l2                    ; not 50 Hz interrupt ?
        ret

;; read AY-3-8912 register A, returning the value in A
;
;ayRegisterRead:
;        and   0fh
;        or    <ayRegisters
;        ld    l, a
;        ld    h, >ayRegisters
;        ld    a, (hl)
;        or    a
;        ret

; write C to AY-3-8912 register A
; NOTE: interrupts may be enabled on return
ayRegisterWriteE:
        ld      a,e

ayRegisterWrite:
        ld      b,#0x00
        ld      hl,#ayRegisterMaskTable
        add     hl,bc
        inc     c
        and     (hl)
        push    bc
        ld      c,#0x10
        add     hl,bc                   ;ayRegisters
        cp      (hl)
        jr      z,ayRegisterWrite.l2                   ; register not changed ?
        ld      (hl),a
        add     hl,bc                   ;ayRegWriteTable
        ld      a,(hl)
        ld      (ayRegisterWrite.l1+1),a
ayRegisterWrite.l1:    jr      ayRegisterWrite.l8                     ; *
ayRegisterWrite.l2:    
    .ifeq NO_ENVELOPE_IRQ
        ld    a, l
        xor   #<(ayRegisters + 13)
        jr    z, ayRegisterWrite.l16                   ; envelope restart ?
    .endif
        pop     bc
;        pop   af
        ret
ayRegisterWrite.l3:    call  setChannelAFreq           ; tone generator A frequency
        pop   bc
;        pop   af
        ret
ayRegisterWrite.l4:    call  setChannelBFreq           ; tone generator B frequency
        pop   bc
;        pop   af
        ret
ayRegisterWrite.l5:    call  setChannelAFreq           ; mixer
        call  setChannelBFreq
ayRegisterWrite.l6:    call  setChannelCFreq           ; tone generator C frequency
        pop   bc
;        pop   af
        ret
ayRegisterWrite.l7:    ld    a, (ayRegisters + 7)      ; noise generator frequency
    .if toneAndNoiseModeAnoise
        ld    b, a
        and   #0x08
    .else
        xor   #0x07
        ld    b, a
        and   #0x09
    .endif
        call  z, setChannelAFreq
    .if toneAndNoiseModeBnoise
        bit   4, b
    .else
        ld    a, b
        and   #0x12
    .endif
        call  z, setChannelBFreq
    .if toneAndNoiseModeCnoise
        bit   5, b
    .else
        ld    a, b
        and   #0x24
    .endif
        call  z, setChannelCFreq
ayRegisterWrite.l8:    pop   bc
;        pop   af
        ret
ayRegisterWrite.l9:    ld    a, (ayRegisters + 8)      ; channel A amplitude / envelope enable
    .ifeq NO_ENVELOPE_IRQ
        ld    bc,#0x09a8 + ayDaveChnA
    .else
        ld    c,#0xa8 + ayDaveChnA
    .endif
        jp    setChannelAmplitude
ayRegisterWrite.l10:   ld    a, (ayRegisters + 9)      ; channel B amplitude / envelope enable
    .ifeq NO_ENVELOPE_IRQ
        ld    bc,#0x0aa8 + ayDaveChnB
    .else
        ld    c,#0xa8 + ayDaveChnB
    .endif
        jp    setChannelAmplitude
ayRegisterWrite.l11:   ld    a, (ayRegisters + 10)     ; channel C amplitude / envelope enable
    .ifeq ENABLE_STEREO
      .ifeq NO_ENVELOPE_IRQ
        ld    bc,#0x0ca8 + ayDaveChnC
      .else
        ld    c,#0xa8 + ayDaveChnC
      .endif
    .else
      .ifeq NO_ENVELOPE_IRQ
        ld    bc,#0x0cac + ayDaveChnC
      .else
        ld    c,#0xac + ayDaveChnC
      .endif
    .endif
        jp    setChannelAmplitude
ayRegisterWrite.l12:
    .ifeq NO_ENVELOPE_IRQ
        ld    hl, (ayRegisters + 11)    ; envelope generator frequency
        ld    a, h
        or    a
        jr    nz, ayRegisterWrite.l13
        ld    a, #MIN_ENV_FREQVAL
        cp    l
        jr    c, ayRegisterWrite.l13
        ld    l, a                      ; limit envelope frequency
ayRegisterWrite.l13:   ld    (envelopeInterrupt.l3 + 1), hl
        pop   bc
;        pop   af
        ret
    .else
        jr    ayRegisterWrite.l8
    .endif
ayRegisterWrite.l15:                                   ; envelope generator mode / restart
    .ifeq NO_ENVELOPE_IRQ
ayRegisterWrite.l16:   ld      hl,(envelopeInterrupt.l3+1)
        ld      (envelopeInterrupt.l1+1),hl
        ld      a,#0x38                     ; = JR C, +nn
        ld      (envelopeInterrupt.l2),a    ; enable envelope
        ld      a,(ayRegisters+13)
        ld      c,a
        ld      b,#0x00
        ld      hl,#envelopeModeTable
        add     hl,bc
        and     #0x04
        ld    a, (hl)
        ld    (envelopeInterrupt.l6 + 1), a
        ld    hl,#0x3c00                    ; INC A, state = 0
        ld    a, l
        jr    nz, ayRegisterWrite.l17                      ; attack ?
        ld    hl,#0x3d0f                    ; DEC A, state = 15
        ld    a,#0x3f
ayRegisterWrite.l17:   ld    (envelopeInterrupt.l4 + 1), hl    ; assume eInt.l5 = eInt.l4 + 2
        call  ayRegisterWrite.l18
        pop   bc
;        pop   af
        ret
ayRegisterWrite.l18:   call  envelopeInterrupt.l10     ; NOTE: this will pop return address
    .else
        jr    ayRegisterWrite.l8
    .endif

 .endif
; =============================================================================


   ;PLY_UseEnterprise_End 
 