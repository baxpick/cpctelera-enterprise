;       AKY music player - V1.0.
;       By Julien Névo a.k.a. Targhan/Arkos.
;       CPC PSG sending optimization trick by Madram/Overlanders.
;       December 2016.
;
;       This compiles with RASM. Please check the compatibility page on Arkos Tracker 2 website, there is a Source Converter (Disark) for ANY assembler!
;
;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.
;
;       Multi-PSG
;       ----------------------
;       This player only target 1 PSG, as it allows some nice optimizations.
;       For Multi-PSG hardware, such as PlayCity (CPC), TurboSound (Spectrum) or SpecNext, please check the PlayerAkyMultiPsg.asm!
;
;       Hardware target
;       ----------------------
;       This code can target Amstrad CPC, MSX, Spectrum and Pentagon. By default, it targets Amstrad CPC.
;       Simply use one of the follow line (BEFORE this player):
;       PLY_AKY_HARDWARE_CPC = 1
;       PLY_AKY_HARDWARE_MSX = 1
;       PLY_AKY_HARDWARE_SPECTRUM = 1
;       PLY_AKY_HARDWARE_PENTAGON = 1
;       Note that the PRESENCE of this variable is tested, NOT its value.
;
;       Sound effects
;       ----------------------
;       This player does not support sound effects. For this, use the AKY Multi-Psg (in the same folder).
;
;       ROM
;       ----------------------
;       To use a ROM player (no automodification, use of a small buffer to put in RAM):
;       PLY_AKY_ROM = 1
;       PLY_AKY_ROM_Buffer = #4000 (or wherever). The buffer is 29 bytes long (PLY_AKY_ROM_BufferSize).
;       This makes the player a bit slower and very slightly bigger.
;
;       Optimizations
;       ----------------------
;       - Use the Player Configuration of Arkos Tracker 2 to generate a configuration file to be included at the beginning of this player.
;         It will disable useless features according to your songs! Check the manual for more details, or more simply the testers.
;       - SIZE: The JP hooks at the beginning can be removed if you include this code in yours directly (see the PLY_AKY_UseHooks flag below).
;       - SIZE: If you don't play a song twice, all the code in PLY_AKY_Init can be removed, except the first lines that skip the header.
;       - SIZE: The header is only needed for players that want to load any song. Most of the time, you don't need it. Erase both the init code and the header bytes in the song.
;       - CPU:  We *could* save 3 NOPS by removing the first "jp PLY_AKY_ReadRegisterBlock" and stucking the whole code instead. But it would make the whole really ugly.
;
;       -------------------------------------------------------
; _main::
.module cpct_audio
        .include "../../CPCteleraHW.src"
        .include "arkostrackerAky_var.src"
.equ PLY_AKY_ROM                 ,   0

PLY_AKY_Start:

        ;A nice trick to manage the offset using the same instructions, according to the player (ROM or not).
       .if PLY_AKY_ROM
.equ PLY_AKY_Offset1b  , 0
       .else
.equ PLY_AKY_Offset1b  , 1
       .endif

       .ifeq PLY_AKY_ROM
.equ PLY_AKY_OPCODE_OR_A  , #0xb7                        ;Opcode for "or a".
.equ PLY_AKY_OPCODE_SCF  , #0x37                         ;Opcode for "scf".
       .else
        ;Another trick for the ROM player. The original opcodes are converted to number, which will be multiplied by 2, provoking a carry or not.
.equ PLY_AKY_OPCODE_OR_A  , 0                          ;0 * 2 = 0, no carry.
.equ PLY_AKY_OPCODE_SCF  , #0xff                         ;255 * 2 = carry.
       .endif

        ;Only 3 channels for this player.        
PLY_AKY_ChannelCount = 3

       
      ;-------------------------------------------------------

        ;Hooks for external calls. Can be removed if not needed.
        .if PLY_AKY_UseHooks
                jp PLY_AKY_Init             ;Player + 0.
                jp PLY_AKY_Play             ;Player + 3.
        .endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKY_musicInit
;;
;;    Sets up a music into Arkos Tracker Player to be played later on with
;; <cpct_akpAKY_musicPlay>.
;;
;; C Definition:
;;    void <cpct_akpAKY_musicInit> (void* *songdata*)
;;
;; Input Parameters (2 bytes):
;;    (2B HL) songdata - Pointer to the start of the array containing song's data in AKS binary format
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKY_musicInit_asm
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
;;    AF, AF', BC, DE, HL
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
_cpct_akpAKY_musicInit::
   ld   hl, #2    ;; [10] Retrieve parameters from stack
   add  hl, sp    ;; [11]
   ld    e, (hl)  ;; [ 7] DE = Pointer to the start of music
   inc  hl        ;; [ 6]
   ld    d, (hl)  ;; [ 7]
   ex   de,hl

cpct_akpAKY_musicInit_asm::   ;; Entry point for assembly calls using registers for parameter passing
   ;; First, set song loop times to 0 when we start
   xor   a                          ;; A = 0
   ld (_cpct_akpAKY_songLoopTimes), a  ;; _cpct_akpAKY_songLoopTimes = 0

;       Initializes the player.
;       HL = music address.
PLY_AKY_InitDisarkGenerateExternalLabel:
PLY_AKY_Init:
        ;Skips the header.
        inc hl                          ;Skips the format version.
        ld a,(hl)                       ;Channel count.
        inc hl
        ld de,#0x0004
PLY_AKY_Init_SkipHeaderLoop:                ;There is always at least one PSG to skip.
        add hl,de
        sub #0x03                           ;A PSG is three channels.
        jr z,PLY_AKY_Init_SkipHeadeENDM
        jr nc,PLY_AKY_Init_SkipHeaderLoop   ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKY_Init_SkipHeadeENDM:
        ld (PLY_AKY_PtLinker + PLY_AKY_Offset1b),hl        ;HL now points on the Linker.

        ld a,#PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld hl,#0x01
        ld (PLY_AKY_PatternFrameCounter + PLY_AKY_Offset1b),hl
   .if HARDWARE_ENTERPRISE
        jp     ayReset
   .else
        ret
   .endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKY_musicPlay
;;
;;    Plays next music cycle of the present song with Arkos Tracker Player. Song 
;; has had to be previously established with <cpct_akp_musicInit>.
;;
;; C Definition:
;;    void <cpct_akpAKY_musicPlay> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKY_musicPlay_asm
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
;;    AF, AF', BC, DE, HL
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

_cpct_akpAKY_musicPlay::
cpct_akpAKY_musicPlay_asm::   ;; Entry point for assembly calls  

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
PLY_AKY_PlayDisarkGenerateExternalLabel:
PLY_AKY_Play:
       .ifeq PLY_AKY_ROM
        ld (PLY_AKY_Exit + 1),sp
       .else
        ld (PLY_AKY_SaveSp),sp
       .endif


;Linker.
;----------------------------------------
       .ifeq PLY_AKY_ROM

PLY_AKY_PatternFrameCounter: ld hl,#0x01                ;How many frames left before reading the next Pattern.
       .else
        ld hl,(PLY_AKY_PatternFrameCounter)
       .endif
        dec hl
        ld a,l
        or h
        jr z,PLY_AKY_PatternFrameCounter_Over
        ld (PLY_AKY_PatternFrameCounter + PLY_AKY_Offset1b),hl
        ;The pattern is not over.
       .ifeq PLY_AKY_ROM
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock
       .else
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Start
       .endif

PLY_AKY_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
       .ifeq PLY_AKY_ROM

PLY_AKY_PtLinker: ld sp,#0x0000                                   ;Points on the Pattern of the linker.
       .else
        ld sp,(PLY_AKY_PtLinker)                            ;Points on the Pattern of the linker.
       .endif
        pop hl                                          ;Gets the duration of the Pattern, or 0 if end of the song.
        ld a,l
        or h
        jr nz,PLY_AKY_LinkerNotEndSong
   ;; Increment song loop times
   ld    a, (_cpct_akpAKY_songLoopTimes)
   inc   a
   ld (_cpct_akpAKY_songLoopTimes), a 
        ;End of the song. Where to loop?
        pop hl
        ;We directly point on the frame counter of the pattern to loop to.
        ld sp,hl
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        pop hl
PLY_AKY_LinkerNotEndSong:
        ld (PLY_AKY_PatternFrameCounter + PLY_AKY_Offset1b),hl

        pop hl
        ld (PLY_AKY_Channel1_PtTrack + PLY_AKY_Offset1b),hl
        pop hl
        ld (PLY_AKY_Channel2_PtTrack + PLY_AKY_Offset1b),hl
        pop hl
        ld (PLY_AKY_Channel3_PtTrack + PLY_AKY_Offset1b),hl

        ld (PLY_AKY_PtLinker + PLY_AKY_Offset1b),sp

        ;Resets the RegisterBlocks of the channel >1. The first one is skipped so there is no need to do so.
        ld a,#0x01
        ld (PLY_AKY_Channel2_WaitBeforeNextRegisterBlock + PLY_AKY_Offset1b),a
        ld (PLY_AKY_Channel3_WaitBeforeNextRegisterBlock + PLY_AKY_Offset1b),a
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Over
;; Loop times
;;    Read here to know the number of times a song has looped
_cpct_akpAKY_songLoopTimes:: .db 0 
;Reading the Tracks.
;----------------------------------------

       .ifeq PLY_AKY_ROM
PLY_AKY_Channel1_WaitBeforeNextRegisterBlock: ld a,#0x01        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
       .else
PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Start:
        ld a,(PLY_AKY_Channel1_WaitBeforeNextRegisterBlock)
       .endif
        dec a
        jr nz,PLY_AKY_Channel1_RegisterBlock_Process
PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Over:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,#PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
       .ifeq PLY_AKY_ROM

PLY_AKY_Channel1_PtTrack: ld sp,#0x0000                   ;Points on the Track.
       .else
        ld sp,(PLY_AKY_Channel1_PtTrack)
       .endif
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration.
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel1_PtTrack + PLY_AKY_Offset1b),sp
        ld (PLY_AKY_Channel1_PtRegisterBlock + PLY_AKY_Offset1b),hl

        ;A is the duration of the block.
PLY_AKY_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel1_WaitBeforeNextRegisterBlock + PLY_AKY_Offset1b),a
        

       .ifeq PLY_AKY_ROM
PLY_AKY_Channel2_WaitBeforeNextRegisterBlock: ld a,#0x01        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
       .else
PLY_AKY_Channel2_WaitBeforeNextRegisterBlock_Start:
        ld a,(PLY_AKY_Channel2_WaitBeforeNextRegisterBlock)
       .endif
        dec a
        jr nz,PLY_AKY_Channel2_RegisterBlock_Process
PLY_AKY_Channel2_WaitBeforeNextRegisterBlock_Over:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,#PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
       .ifeq PLY_AKY_ROM

PLY_AKY_Channel2_PtTrack: ld sp,#0x0000                   ;Points on the Track.
       .else
        ld sp,(PLY_AKY_Channel2_PtTrack)
       .endif
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration.
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel2_PtTrack + PLY_AKY_Offset1b),sp
        ld (PLY_AKY_Channel2_PtRegisterBlock + PLY_AKY_Offset1b),hl

        ;A is the duration of the block.
PLY_AKY_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel2_WaitBeforeNextRegisterBlock + PLY_AKY_Offset1b),a
        
       .ifeq PLY_AKY_ROM
PLY_AKY_Channel3_WaitBeforeNextRegisterBlock: ld a,#0x01        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
       .else
PLY_AKY_Channel3_WaitBeforeNextRegisterBlock_Start:
        ld a,(PLY_AKY_Channel3_WaitBeforeNextRegisterBlock)
       .endif
        dec a
        jr nz,PLY_AKY_Channel3_RegisterBlock_Process
PLY_AKY_Channel3_WaitBeforeNextRegisterBlock_Over:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,#PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
       .ifeq PLY_AKY_ROM

PLY_AKY_Channel3_PtTrack: ld sp,#0x0000                   ;Points on the Track.
       .else
        ld sp,(PLY_AKY_Channel3_PtTrack)
       .endif
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration.
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel3_PtTrack + PLY_AKY_Offset1b),sp
        ld (PLY_AKY_Channel3_PtRegisterBlock + PLY_AKY_Offset1b),hl

        ;A is the duration of the block.
PLY_AKY_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel3_WaitBeforeNextRegisterBlock + PLY_AKY_Offset1b),a
        



;Reading the RegisterBlock.
;----------------------------------------
        ;Auxiliary registers are for the PSG access.
          ld hl,#0x08                             ;H = first frequency register, L = first volume register.
       .if PLY_AKY_HARDWARE_CPC
          ld de,#0xf4f6                             ;PSG ports.
          ld bc,#0xf690                             ;#90 used for both #80 for the PSG, and volume 16!

          ld a,#0xc0                                ;Used for PSG.
          out (c),a                               ;f6c0. Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
        ex af,af'
       .endif

       .if PLY_AKY_HARDWARE_MSX
                ld c,#0x10                          ;Hardware volume.
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
          ld de,#0xbfff                             ;PSG ports. E is also used for Volume = Hardware (bit 5 to 1).
          ld bc,#0xfffd
       .endif
        exx

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ld bc,#0b11100000 * 256 + #0xff                     ;C is 255 to prevent the following LDIs to decrease B.

       .if PLY_AKY_HARDWARE_ENTERPRISE
        ld sp,(PLY_AKY_Exit+1)
       .else
        ld sp,#PLY_AKY_RetTable_ReadRegisterBlock
       .endif
        ;Channel 1
       .ifeq PLY_AKY_ROM

PLY_AKY_Channel1_PtRegisterBlock: ld hl,#0x0000                   ;Points on the data of the RegisterBlock to read.
       .else
        ld hl,(PLY_AKY_Channel1_PtRegisterBlock)
       .endif

       .ifeq PLY_AKY_ROM
PLY_AKY_Channel1_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
       .else
        ld a,(PLY_AKY_Channel1_RegisterBlockLineState_Opcode)
        add a,a                                             ;Carry is set according to the opcode.
       .endif
       .if PLY_AKY_HARDWARE_ENTERPRISE
        call PLY_AKY_ReadRegisterBlock
       .else
        jp PLY_AKY_ReadRegisterBlock
       .endif
PLY_AKY_Channel1_RegisterBlock_Return:
        ld a,#PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel1_PtRegisterBlock + PLY_AKY_Offset1b),hl        ;This is new pointer on the RegisterBlock.


        ;Channel 2
        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!
                        ;Also, on MSX, bit 6 must be 0.

       .ifeq PLY_AKY_ROM

PLY_AKY_Channel2_PtRegisterBlock: ld hl,#0x0000                   ;Points on the data of the RegisterBlock to read.
       .else
        ld hl,(PLY_AKY_Channel2_PtRegisterBlock)
       .endif

       .ifeq PLY_AKY_ROM
PLY_AKY_Channel2_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
       .else
        ld a,(PLY_AKY_Channel2_RegisterBlockLineState_Opcode)
        add a,a                                             ;Carry is set according to the opcode.
       .endif
       .if PLY_AKY_HARDWARE_ENTERPRISE
        call PLY_AKY_ReadRegisterBlock
       .else
        jp PLY_AKY_ReadRegisterBlock
       .endif
PLY_AKY_Channel2_RegisterBlock_Return:
        ld a,#PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_PtRegisterBlock + PLY_AKY_Offset1b),hl        ;This is new pointer on the RegisterBlock.

        
        ;Channel 3
        ;Shifts the R7 for the next channels.
       .if PLY_AKY_HARDWARE_MSX
                scf             ;On MSX, bit 7 must be 1.
                rr b
       .else
                rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.
       .endif

       .ifeq PLY_AKY_ROM

PLY_AKY_Channel3_PtRegisterBlock: ld hl,#0x0000                   ;Points on the data of the RegisterBlock to read.
       .else
        ld hl,(PLY_AKY_Channel3_PtRegisterBlock)
       .endif

       .ifeq PLY_AKY_ROM
PLY_AKY_Channel3_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
       .else
        ld a,(PLY_AKY_Channel3_RegisterBlockLineState_Opcode)
        add a,a                                             ;Carry is set according to the opcode.
       .endif
       .if PLY_AKY_HARDWARE_ENTERPRISE
        call PLY_AKY_ReadRegisterBlock
       .else
        jp PLY_AKY_ReadRegisterBlock
       .endif
PLY_AKY_Channel3_RegisterBlock_Return:
        ld a,#PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_PtRegisterBlock + PLY_AKY_Offset1b),hl        ;This is new pointer on the RegisterBlock.

        
        ;Register 7 to A.
        ld a,b

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).
        exx
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,#0x07
        call    ayRegisterWrite
;Register 6
       .if PLY_AKY_USE_Noise         ;CONFIG SPECIFIC
        ld      c,#0x06
        ld      a,(PLY_AKY_PsgRegister6)
        call    ayRegisterWrite
       .endif
        
       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ld      c,#0x0b
        ld      a,(PLY_AKY_PsgRegister11)
        call    ayRegisterWrite
        ld      c,#0x0c
        ld      a,(PLY_AKY_PsgRegister12)
        call    ayRegisterWrite
       .endif ;PLY_CFG_UseHardwareSounds
      .endif

       .if PLY_AKY_HARDWARE_CPC
                inc h           ;Was 6, so now 7!

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

;Register 6
                       .if PLY_AKY_USE_Noise         ;CONFIG SPECIFIC
                dec h

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600

                ld hl,#PLY_AKY_PsgRegister6
                dec b           ; -1, not -2 because of OUTI does -1 before doing the out.
                outi            ;f400 + value
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
                       .else
                        ;No noise. Still, makes HL points on the data after the noise.
                        ld hl,#PLY_AKY_PsgRegister6 + 1
                       .endif ;PLY_AKY_USE_Noise

                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
;Register 11
                ld a,#0x0b         ;Next register

                ld b,d
                out (c),a       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                dec b
                outi            ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'


;Register 12
                inc a           ;Next register

                ld b,d
                out (c),a       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                dec b
                outi            ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
                       .endif ;PLY_CFG_UseHardwareSounds
                
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                inc h           ;Was 6, so now 7!
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
        
                ;Register 6.
                       .if PLY_AKY_USE_Noise         ;CONFIG SPECIFIC
                dec h
                out (c),h       ;#fffd + register.
                ld b,d
                ld a,(PLY_AKY_PsgRegister6)     ;COULD be optimized, but I didn't want to change the code structure from one platform to another one.
                out (c),a       ;#bffd + value
                ld b,e
                       .endif ;PLY_AKY_USE_Noise

                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC

                ;Register 11.
                ld h,#0x0b
                out (c),h       ;#fffd + register.
                ld b,d
                ld a,(PLY_AKY_PsgRegister11)
                out (c),a       ;#bffd + value
                ld b,e
                
                ;Register 12.
                inc h
                out (c),h       ;#fffd + register.
                ld b,d
                ld a,(PLY_AKY_PsgRegister12)
                out (c),a       ;#bffd + value
                ld b,e
                       .endif ;PLY_CFG_UseHardwareSounds
                
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a          ;Preserves R7.
                ld a,#0x07
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
        
                       .if PLY_AKY_USE_Noise         ;CONFIG SPECIFIC
                ld a,#0x06
                out (#0xa0),a     ;Register.
                ld a,(PLY_AKY_PsgRegister6)     ;COULD be optimized, but I didn't want to change the code structure from one platform to another one.
                out (#0xa1),a     ;Value.
                       .endif ;PLY_AKY_USE_Noise
                
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
                ld a,#0x0b
                out (#0xa0),a     ;Register.
                ld a,(PLY_AKY_PsgRegister11)
                out (#0xa1),a     ;Value.
                
                ld a,#0x0c
                out (#0xa0),a     ;Register.
                ld a,(PLY_AKY_PsgRegister12)
                out (#0xa1),a     ;Value.
                       .endif ;PLY_CFG_UseHardwareSounds
       .endif

;Register 13
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
PLY_AKY_PsgRegister13_Code:
       .if PLY_AKY_ROM
                ld a,(PLY_AKY_PsgRegister13_Retrig)     ;ROM: needs to keep retrig in a register to compare A with it later.
                ld b,a
       .endif

       .if PLY_AKY_HARDWARE_CPC
                ld a,(hl)
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON + PLY_AKY_HARDWARE_ENTERPRISE + PLY_AKY_HARDWARE_MSX
                ld a,(PLY_AKY_PsgRegister13)
       .endif
        
       .ifeq PLY_AKY_ROM
PLY_AKY_PsgRegister13_Retrig: cp #0xff                         ;If IsRetrig?, force the R13 to be triggered.
       .else
                cp b
       .endif
                jr z,PLY_AKY_PsgRegister13_End
                ld (PLY_AKY_PsgRegister13_Retrig + PLY_AKY_Offset1b),a

      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,#0x0d
        jp      ayRegisterWrite
      .endif

       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                ld l,#0x0d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ;ex af,af'
                
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
               .if PLY_AKY_ROM
                        ld b,e  ;B has been modified if ROM.
               .endif
                ld l,#0x0d
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,#0x0d
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.           
       .endif
PLY_AKY_PsgRegister13_End:

                       .endif ;PLY_CFG_UseHardwareSounds

       .ifeq PLY_AKY_ROM

PLY_AKY_Exit: ld sp,#0x0000
       .else
        ld sp,(PLY_AKY_SaveSp)
       .endif
        ret








;Generic code interpreting the RegisterBlock
;IN:    HL = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKY_ReadRegisterBlock:
        ;Gets the first byte of the line. What type? Jump to the matching code.
        ld a,(hl)
        inc hl
        jp c,PLY_AKY_RRB_NonInitialState
        ;Initial state.
        rra
        jr c,PLY_AKY_RRB_IS_SoftwareOnlyOrSoftwareAndHardware
        rra
                       .if PLY_CFG_HardOnly  ;CONFIG SPECIFIC
        jr c,PLY_AKY_RRB_IS_HardwareOnly
                       .endif ;PLY_CFG_HardOnly
        ;jr PLY_AKY_RRB_IS_NoSoftwareNoHardware

;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    HL = Points after the first byte.
;       A = First byte, twice shifted to the right (type removed).
;       B = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       C = May be used as a temp. BUT must NOT be 0, as ldi will decrease it, we do NOT want B to be decreased!!
;       DE = free to use.
;       IX = free to use (not used!).
;       IY = free to use (not used!).

;       A' = free to use (not used).
;       DE' = f4f6
;       BC' = f680
;       L' = Volume register.
;       H' = LSB frequency register.

;OUT:   HL MUST point after the structure.
;       B = updated (ONLY bit 2 and 5).
;       L' = Volume register increased of 1 (*** IMPORTANT! The code MUST increase it, even if not using it! ***)
;       H' = LSB frequency register, increased of 2 (see above).
;       DE' = unmodified (f4f6)
;       BC' = unmodified (f680)

.equ PLY_AKY_RRB_NoiseChannelBit  , 5          ;Bit to modify to set/reset the noise channel.
.equ PLY_AKY_RRB_SoundChannelBit  , 2          ;Bit to modify to set/reset the sound channel.

                       .if PLY_CFG_NoSoftNoHard        ;CONFIG SPECIFIC
PLY_AKY_RRB_IS_NoSoftwareNoHardware:
        ;No software no hardware.
        rra                     ;Noise?
                       .if PLY_CFG_NoSoftNoHard_Noise        ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_NIS_NoSoftwareNoHardware_ReadVolume
        ;There is a noise. Reads it.
        ld de,#PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
                       .endif ;PLY_CFG_NoSoftNoHard_Noise
        ;The volume is now in b0-b3.
        ;and %1111      ;No need, the bit 7 was 0.

        exx
                ;Sends the volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
       .endif
                inc l           ;Increases the volume register.
                inc h           ;Increases the frequency register.
                inc h
        exx

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b
        ret
                       .endif ;PLY_CFG_NoSoftNoHard


;---------------------
                       .if PLY_CFG_HardOnly  ;CONFIG SPECIFIC
PLY_AKY_RRB_IS_HardwareOnly:
        ;Retrig?
        rra
                       .if PLY_CFG_HardOnly_Retrig   ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_IS_HO_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKY_PsgRegister13_Retrig + PLY_AKY_Offset1b),a
PLY_AKY_RRB_IS_HO_NoRetrig:
                       .endif ;PLY_CFG_HardOnly_Retrig

        ;Noise?
        rra
                       .if PLY_CFG_HardOnly_Noise   ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_IS_HO_NoNoise
        ;Reads the noise.
        ld de,#PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_HO_NoNoise:
                       .endif ;PLY_CFG_HardOnly_Noise

        ;The envelope.
        and #0b1111
        ld (PLY_AKY_PsgRegister13),a

        ;Copies the hardware period.
        ld de,#PLY_AKY_PsgRegister11
        ldi
        ldi

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        exx
                ;Sets the hardware volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ld      a,#0x10
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),c       ;f400 + value (volume to 16).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif

       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),e       ;#bffd + value (volume to 16).
                ld b,e        
       .endif

       .if PLY_AKY_HARDWARE_MSX
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,c
                out (#0xa1),a     ;Value (volume to 16).
       .endif

                inc l           ;Increases the volume register.
                inc h           ;Increases the frequency register (mandatory!).
                inc h
        exx
        ret
                       .endif ;PLY_CFG_HardOnly


;---------------------
PLY_AKY_RRB_IS_SoftwareOnlyOrSoftwareAndHardware:
        ;Another decision to make about the sound type.
        rra
                       .if PLY_AKY_USE_SoftAndHard_Agglomerated      ;CONFIG SPECIFIC
        jr c,PLY_AKY_RRB_IS_SoftwareAndHardware
                       .endif ;PLY_AKY_USE_SoftAndHard_Agglomerated

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        rra
                       .if PLY_CFG_SoftOnly_Noise    ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_IS_SoftwareOnly_NoNoise
        ;Noise. Reads it.
        ld de,#PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SoftwareOnly_NoNoise:
                       .endif ;PLY_CFG_SoftOnly_Noise
        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
        exx
                ;Sends the volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc l           ;Increases the volume register.
        exx

        ;Reads the software period.
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc h           ;Increases the frequency register.
        exx

        ld a,(hl)
        inc hl
        exx
                ;Sends the MSB software frequency.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc h           ;Increases the frequency register.
        exx

        ret





;---------------------
                       .if PLY_AKY_USE_SoftAndHard_Agglomerated      ;CONFIG SPECIFIC
PLY_AKY_RRB_IS_SoftwareAndHardware:
        ;Retrig?
        rra
                               .if PLY_CFG_UseRetrig      ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_IS_SAH_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKY_PsgRegister13_Retrig + PLY_AKY_Offset1b),a
PLY_AKY_RRB_IS_SAH_NoRetrig:
                               .endif ;PLY_CFG_UseRetrig

        ;Noise?
        rra
                               .if PLY_AKY_USE_SoftAndHard_Noise_Agglomerated
        jr nc,PLY_AKY_RRB_IS_SAH_NoNoise
        ;Reads the noise.
        ld de,#PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SAH_NoNoise:
                               .endif ;PLY_AKY_USE_SoftAndHard_Noise_Agglomerated

        ;The envelope.
        and #0b1111
        ld (PLY_AKY_PsgRegister13),a

        ;Reads the software period.
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc h           ;Increases the frequency register.
        exx

        ld a,(hl)
        inc hl
        exx
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ;Sends the MSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc h           ;Increases the frequency register.

                ;Sets the hardware volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ld      a,#0x10
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),c       ;f400 + value (volume to 16).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
                
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),e       ;#bffd + value (volume to 16).
                ld b,e
                
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,c
                out (#0xa1),a     ;Value (volume to 16).
                        
       .endif
                inc l           ;Increases the volume register.
        exx

        ;Copies the hardware period.
        ld de,#PLY_AKY_PsgRegister11
        ldi
        ldi
        ret
                       .endif ;PLY_AKY_USE_SoftAndHard_Agglomerated







        ;Manages the loop. This code is put here so that no jump needs to be coded when its job is done.
PLY_AKY_RRB_NIS_NoSoftwareNoHardware_Loop:
        ;Loops. Reads the next pointer to this RegisterBlock.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a

        ;Makes another iteration to read the new data.
        ;Since we KNOW it is not an initial state (because no jump goes to an initial state), we can directly go to the right branching.
        ;Reads the first byte.
        ld a,(hl)
        inc hl
        ;jr PLY_AKY_RRB_NonInitialState

;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKY_RRB_NonInitialState:
        rra
        jr c,PLY_AKY_RRB_NIS_SoftwareOnlyOrSoftwareAndHardware
        rra
                       .if PLY_CFG_HardOnly  ;CONFIG SPECIFIC
        jp c,PLY_AKY_RRB_NIS_HardwareOnly
                       .endif ;PLY_CFG_HardOnly

        ;No software, no hardware, OR loop.

        ld e,a
        and #0b11         ;Bit 3:loop?/volume bit 0, bit 2: volume?
        cp #0b10          ;If no volume, yet the volume is >0, it means loop.
        jr z,PLY_AKY_RRB_NIS_NoSoftwareNoHardware_Loop

        ;No loop: so "no software no hardware".
                       .if PLY_CFG_NoSoftNoHard        ;CONFIG SPECIFIC

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Volume? bit 2 - 2.
        ld a,e
        rra
        jr nc,PLY_AKY_RRB_NIS_NoVolume
        and #0b1111
        exx
                ;Sends the volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
        exx
PLY_AKY_RRB_NIS_NoVolume:
        ;Sadly, have to lose a bit of CPU here, as this must be done in all cases.
        exx
                inc l           ;Next volume register.
                inc h           ;Next frequency registers.
                inc h
        exx

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
                       .if PLY_CFG_NoSoftNoHard_Noise        ;CONFIG SPECIFIC
        bit 7 - 2, e
        ret z
        ;Noise.
        ld a,(hl)
        ld (PLY_AKY_PsgRegister6),a
        inc hl
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
                       .endif ;PLY_CFG_NoSoftNoHard_Noise
        ret
                       .endif ;PLY_CFG_NoSoftNoHard






PLY_AKY_RRB_NIS_SoftwareOnlyOrSoftwareAndHardware:
        ;Another decision to make about the sound type.
        rra
                       .if PLY_AKY_USE_SoftAndHard_Agglomerated      ;CONFIG SPECIFIC
        jp c,PLY_AKY_RRB_NIS_SoftwareAndHardware
                       .endif


;---------------------
                       .if PLY_CFG_SoftOnly  ;CONFIG SPECIFIC
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        ld e,a
        ;Gets the volume (already shifted).
        and #0b1111
        exx
                ;Sends the volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc l           ;Increases the volume register.
        exx

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        bit 6 - 2, e
        jr z,PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP
        ld a,(hl)
        inc hl
        exx
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ;Sends the LSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                ;H not incremented on purpose.
        exx
PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        bit 7 - 2, e
        jr nz,PLY_AKY_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
        ;Bit of loss of CPU, but has to be done in all cases.
        exx
                inc h
                inc h
        exx
        ret
PLY_AKY_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        ld a,(hl)       ;Useless bits at the end, not a problem.
        inc hl
        exx
                ;Sends the MSB software frequency.
                inc h           ;Was not increased before.

      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        push    af
        call    ayRegisterWrite
        pop     af
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                inc h           ;Increases the frequency register.
        exx
                               .if PLY_CFG_SoftOnly_Noise  ;CONFIG SPECIFIC
        rla     ;Carry is isNoise?
        ret nc

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b

        ;Is there a new noise value? If yes, gets the noise.
        rla
        ret nc
        ;Gets the noise.
        ld de,#PLY_AKY_PsgRegister6
        ldi
                               .endif ;PLY_CFG_SoftOnly_Noise
        ret
                       .endif ;PLY_CFG_SoftOnly


;---------------------
                       .if PLY_CFG_HardOnly  ;CONFIG SPECIFIC
PLY_AKY_RRB_NIS_HardwareOnly:
        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rla
        ld e,a
        and #0b1110
        ld (PLY_AKY_PsgRegister13),a

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Hardware volume.
        exx
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ld      a,#0x10
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),c       ;f400 + value (16, hardware volume).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),e       ;#bffd + value (volume to 16).
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,c
                out (#0xa1),a     ;Value (16, hardware volume).
       .endif

                inc l           ;Increases the volume register.

                inc h           ;Increases the frequency register.
                inc h
        exx

        ld a,e

        ;LSB for hardware period? Currently on b6.
        rla
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoLSB
        ld de,#PLY_AKY_PsgRegister11
        ldi
PLY_AKY_RRB_NIS_HardwareOnly_NoLSB:

        ;MSB for hardware period?
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoMSB
        ld de,#PLY_AKY_PsgRegister12
        ldi
PLY_AKY_RRB_NIS_HardwareOnly_NoMSB:

        ;Noise or retrig?
        rla
        jr c,PLY_AKY_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.

        ret
                       .endif ;PLY_CFG_HardOnly


;---------------------
                       .if PLY_AKY_USE_SoftAndHard_Agglomerated      ;CONFIG SPECIFIC
PLY_AKY_RRB_NIS_SoftwareAndHardware:
        ;Hardware volume.
        exx
                ;Sends the volume.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,l
        ex      af,af'
        ld      a,#0x10
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
        ex      af,af'
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),c       ;f400 + value (16 = hardware volume).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),l       ;#fffd + register.
                ld b,d
                out (c),e       ;#bffd + value (volume to 16).
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a          ;A must be preserved.
                ld a,l
                out (#0xa0),a     ;Register.
                ld a,c
                out (#0xa1),a     ;Value (16 = hardware volume).
                ld a,b
       .endif
        
                inc l           ;Increases the volume register.
        exx

        ;LSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBH
        ld de,#PLY_AKY_PsgRegister11
        ldi
PLY_AKY_RRB_NIS_SAHH_AfterLSBH:
        ;MSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBH
        ld de,#PLY_AKY_PsgRegister12
        ldi
PLY_AKY_RRB_NIS_SAHH_AfterMSBH:

        ;LSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBS
        ld e,a
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                ;H not increased on purpose.
        exx
        ld a,e
PLY_AKY_RRB_NIS_SAHH_AfterLSBS:

        ;MSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBS
        ld e,a
        ld a,(hl)
        inc hl
        exx
                ;Sends the MSB software frequency.
                inc h

      .if PLY_AKY_HARDWARE_ENTERPRISE
        ld      c,h
        ex      de,hl
        call    ayRegisterWrite
        ex      de,hl
      .endif
       .if PLY_AKY_HARDWARE_CPC
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                .db #0xed,#0x71     ;out (c),#0x00   ;#f600
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
       .endif
       .if PLY_AKY_HARDWARE_SPECTRUM + PLY_AKY_HARDWARE_PENTAGON
                out (c),h       ;#fffd + register.
                ld b,d
                out (c),a       ;#bffd + value.
                ld b,e
       .endif
       .if PLY_AKY_HARDWARE_MSX
                ld b,a
                ld a,h
                out (#0xa0),a     ;Register.
                ld a,b
                out (#0xa1),a     ;Value.
       .endif
                dec h           ;Yup. Will be compensated below.
        exx
        ld a,e
PLY_AKY_RRB_NIS_SAHH_AfterMSBS:
        ;A bit of loss of CPU, but this has to be done every time!
        exx
                inc h
                inc h
        exx

        ;New hardware envelope?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterEnvelope
        ld de,#PLY_AKY_PsgRegister13
        ldi
PLY_AKY_RRB_NIS_SAHH_AfterEnvelope:

        ;Retrig and/or noise?
        rra
        ret nc
                       .endif ;PLY_AKY_USE_SoftAndHard_Agglomerated

                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKY_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:
        ;Noise or retrig. Reads the next byte.
        ld a,(hl)
        inc hl

        ;Retrig?
        rra
                       .if PLY_CFG_UseRetrig         ;CONFIG SPECIFIC
        jr nc,PLY_AKY_RRB_NIS_S_NOR_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKY_PsgRegister13_Retrig + PLY_AKY_Offset1b),a
PLY_AKY_RRB_NIS_S_NOR_NoRetrig:
                       .endif ;PLY_CFG_UseRetrig

                       .if PLY_AKY_USE_SoftAndHard_Noise_Agglomerated        ;CONFIG SPECIFIC
        ;Noise? If no, nothing more to do.
        rra
        ret nc
        ;Noise. Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
        ;Is there a new noise value? If yes, gets the noise.
        rra
        ret nc
        ;Sets the noise.
        ld (PLY_AKY_PsgRegister6),a
                       .endif ;PLY_AKY_USE_SoftAndHard_Noise_Agglomerated
        ret
                       .endif ;PLY_CFG_UseHardwareSounds


       .ifeq PLY_AKY_ROM
;Some stored PSG registers. They MUST be consecutive.
PLY_AKY_PsgRegister6:   .db #0x00
               .if PLY_CFG_UseHardwareSounds
PLY_AKY_PsgRegister11:  .db #0x00
PLY_AKY_PsgRegister12:  .db #0x00
PLY_AKY_PsgRegister13:  .db #0x00
               .endif
       .endif

;RET table for the Read RegisterBlock code to know where to return.
PLY_AKY_RetTable_ReadRegisterBlock:
                .dw PLY_AKY_Channel1_RegisterBlock_Return
                .dw PLY_AKY_Channel2_RegisterBlock_Return
                .dw PLY_AKY_Channel3_RegisterBlock_Return

        
        
;Buffer used for the ROM player. This part needs to be set to RAM.
       .if PLY_AKY_ROM
        ;Bytes first.
.equ PLY_AKY_ROM_BufferSize , 0
.equ PLY_AKY_Channel1_WaitBeforeNextRegisterBlock     , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_Channel2_WaitBeforeNextRegisterBlock     , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_Channel3_WaitBeforeNextRegisterBlock     , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1

.equ PLY_AKY_Channel1_RegisterBlockLineState_Opcode   , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_Channel2_RegisterBlockLineState_Opcode   , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_Channel3_RegisterBlockLineState_Opcode   , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1

;Some stored PSG registers. They MUST be consecutive (assertion don't work in this case...).
.equ PLY_AKY_PsgRegister6                             , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
               .if PLY_CFG_UseHardwareSounds
.equ PLY_AKY_PsgRegister11                            , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_PsgRegister12                            , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_PsgRegister13                            , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
.equ PLY_AKY_PsgRegister13_Retrig                     , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 1
               .endif
        ;Words.
.equ PLY_AKY_PtLinker                                 , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_SaveSp                                   , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_PatternFrameCounter                      , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel1_PtTrack                         , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel2_PtTrack                         , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel3_PtTrack                         , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel1_PtRegisterBlock                 , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel2_PtRegisterBlock                 , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2
.equ PLY_AKY_Channel3_PtRegisterBlock                 , PLY_AKY_ROM_Buffer + PLY_AKY_ROM_BufferSize   PLY_AKY_ROM_BufferSize = PLY_AKY_ROM_BufferSize + 2

       .endif

; =============================================================================
 .if PLY_AKY_HARDWARE_ENTERPRISE
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
 