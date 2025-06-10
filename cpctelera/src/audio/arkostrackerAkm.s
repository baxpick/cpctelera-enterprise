;       Arkos Tracker 2 AKM (Minimalist) player (format V0).
;       By Targhan/Arkos.
;
;       Thanks to Hicks/Vanity for two small (but relevant!) optimizations.

;       This compiles with RASM. Check the compatibility page on the Arkos Tracker 2 website, it contains a source converter to any Z80 assembler!;

;       This is a Minimalist player. Only a subset of the generic player is used. Use this player for 4k demo or other productions
;       with a tight memory limitation. However, this remains a versatile and powerful player, so it may fit any production!
;
;       Though the player is optimized in speed, it is much slower than the generic one or the AKY player.
;       With effects used at the same time, it can reach 45 scanlines on a CPC, plus some few more if you are using sound effects.
;       So it's about as fast as the Soundtrakker 128 player, but smaller and more powerful (so what are you complaining about?).
;
;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.
;
;       Target hardware:
;       ---------------
;       This code can target Amstrad CPC, MSX, Spectrum and Pentagon. By default, it targets Amstrad CPC.
;       Simply use one of the follow line (BEFORE this player):
;       PLY_AKM_HARDWARE_CPC = 1
;       PLY_AKM_HARDWARE_MSX = 1
;       PLY_AKM_HARDWARE_SPECTRUM = 1
;       PLY_AKM_HARDWARE_PENTAGON = 1
;       Note that the PRESENCE of this variable is tested, NOT its value.

;       Some severe optimizations of CPU/memory can be performed:
;       ---------------------------------------------------------
;       - Use the Player Configuration of Arkos Tracker 2 to generate a configuration file to be included at the beginning of this player.
;         It will disable useless features according to your songs! Check the manual for more details, or more simply the testers.

;       Sound effects:
;       --------------
;       Sound effects are disabled by default. Declare PLY_AKM_MANAGE_SOUND_EFFECTS to enable it:
;       PLY_AKM_MANAGE_SOUND_EFFECTS = 1
;       Check the sound effect tester to see how it enables it.
;       Note that the PRESENCE of this variable is tested, NOT its value.
;
;       ROM
;       ----------------------
;       To use a ROM player (no automodification, use of a small buffer to put in RAM):
;       PLY_AKM_Rom = 1
;       PLY_AKM_ROM_Buffer = #4000 (or wherever).
;       This makes the player a bit slower and slightly bigger.
;       The buffer is PLY_AKM_ROM_BufferSize bytes long (199 bytes max).
;
;       -------------------------------------------------------
; _main::
.module cpct_audio
        .include "../../CPCteleraHW.src"
        .include "arkostrackerAkm_var.src"
PLY_AKM_Start:

.equ PLY_AKM_Rom ,     0
        
        ;Hooks for external calls. Can be removed if not needed.
       .if PLY_AKM_USE_HOOKS
                jp PLY_AKM_Init          ;Player + 0.
                jp PLY_AKM_Play          ;Player + 3.
               .if PLY_AKM_STOP_SOUNDS
                jp PLY_AKM_Stop          ;Player + 6.
               .endif
       .endif
        
        ;Includes the sound effects player, if wanted. Important to do it as soon as possible, so that
        ;its code can react to the Player Configuration and possibly alter it.
       .if PLY_AKM_MANAGE_SOUND_EFFECTS
		.include "arkostrackerAkm_SoundEffects.src"
       .endif
        ;[[INSERT_SOUND_EFFECT_SOURCE]]                 ;A tag for test units. Don't touch or you're dead.

        ;Is there a loaded Player Configuration source? If no, use a default configuration.

;A nice trick to manage the offset using the same instructions, according to the player (ROM or not).
       .if PLY_AKM_Rom
.equ PLY_AKM_Offset1b , 0
.equ PLY_AKM_Offset2b , 0         ;Used for instructions such as ld iyh,xx
       .else
.equ PLY_AKM_Offset1b , 1
.equ PLY_AKM_Offset2b , 2
       .endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKM_musicInit
;;
;;    Sets up a music into Arkos Tracker Player to be played later on with
;; <cpct_akpAKM_musicPlay>.
;;
;; C Definition:
;;    void <cpct_akpAKM_musicInit> (void* *songdata*, song number)
;;
;; Input Parameters (2 bytes):
;;    (2B HL) songdata - Pointer to the start of the array containing song's data in AKS binary format
;;    (1B A) song number
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKM_musicInit_asm
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

_cpct_akpAKM_musicInit::
   ld   hl, #2    ;; [10] Retrieve parameters from stack
   add  hl, sp    ;; [11]
   ld    e, (hl)  ;; [ 7] DE = Pointer to the start of music
   inc  hl        ;; [ 6]
   ld    d, (hl)  ;; [ 7]
   inc  hl
   ld    c, (hl)
   ex   de,hl
cpct_akpAKM_musicInit_asm::   ;; Entry point for assembly calls using registers for parameter passing 
   ;; First, set song loop times to 0 when we start
   xor   a                          ;; A = 0
   ld (_cpct_akpAKM_songLoopTimes), a  ;; _cpct_akpAKM_songLoopTimes = 0
   ld    a,c
   
;Initializes the song. MUST be called before actually playing the song.
;IN:    HL = Address of the song.
;       A = Index of the subsong to play (>=0).
PLY_AKM_InitDisarkGenerateExternalLabel:
PLY_AKM_Init:
        ;Reads the Song header.
        ;Reads the pointers to the various index tables.
        ld de,#PLY_AKM_PtInstruments + PLY_AKM_Offset1b
        ldi
        ldi
                       .if PLY_CFG_UseEffects                           ;CONFIG SPECIFIC
                               .if PLY_CFG_UseEffect_ArpeggioTable      ;CONFIG SPECIFIC
        ld de,#PLY_AKM_PtArpeggios + PLY_AKM_Offset1b
        ldi
        ldi
                               .else
                                inc hl
                                inc hl
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                               .if PLY_CFG_UseEffect_PitchTable         ;CONFIG SPECIFIC
        ld de,#PLY_AKM_PtPitches + PLY_AKM_Offset1b
        ldi
        ldi
                               .else
                                inc hl
                                inc hl
                               .endif ;PLY_CFG_UseEffect_PitchTable
                       .else
        ld de,#0x0004
        add hl,de
                       .endif ;PLY_CFG_UseEffects
                        
        ;Finds the address of the Subsong.
        ;HL points on the table, adds A * 2.
        ;Possible optimization: possible to set the Subsong directly.
        add a,a
        ld e,a
        ld d,#0x00
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a

        ;Reads the header of the Subsong, copies the values inside the code via a table.
        ld ix,#PLY_AKM_InitVars_Start
.equ varcount , (PLY_AKM_InitVars_End - PLY_AKM_InitVars_Start) / 2
        ld a,#varcount
PLY_AKM_InitVars_Loop:
        ld e,0 (ix)
        ld d,1 (ix)
        inc ix
        inc ix
        ldi
        dec a
        jr nz,PLY_AKM_InitVars_Loop

        ;A is zero, no need to reset it.        
        ld (PLY_AKM_PatternRemainingHeight + PLY_AKM_Offset1b),a       ;Optimization: this line can be removed if there is no need to reset the song (warning, A is used below).

        ;Stores the Linker address, just after.
        ex de,hl
        ld hl,#PLY_AKM_PtLinker + PLY_AKM_Offset1b
        ld (hl),e
        inc hl
        ld (hl),d

        ;A big LDIR to erase all the data blocks. Optimization: can be removed if there is no need to reset the song.
        ;A is considered 0!
        ld hl,#PLY_AKM_Track1_Data
        ld de,#PLY_AKM_Track1_Data + 1
        ld bc,#PLY_AKM_Track3_Data_End - PLY_AKM_Track1_Data - 1
        ld (hl),a
        ldir
        
        ;Resets this flag. Especially important for ROM.
       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
                ld (PLY_AKM_RT_ReadEffectsFlag + PLY_AKM_Offset1b),a
       .endif

        ;Forces a new line.
        ld a,(PLY_AKM_Speed + PLY_AKM_Offset1b)
        dec a
        ld (PLY_AKM_TickCounter + PLY_AKM_Offset1b),a

        ;Reads the first instrument, the empty one, and set-ups the pointers to the instrument to read.
        ;Optimization: needed if the song doesn't start with an instrument on all the channels..else, it can be removed.
        ld hl,(PLY_AKM_PtInstruments + PLY_AKM_Offset1b)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc de          ;Skips the header.
        ld (PLY_AKM_Track1_PtInstrument),de
        ld (PLY_AKM_Track2_PtInstrument),de
        ld (PLY_AKM_Track3_PtInstrument),de
        
        ;If sound effects, clears the SFX state.
       .if PLY_AKM_MANAGE_SOUND_EFFECTS
        ld hl,#0x0000
        ld (PLY_AKM_Channel1_SoundEffectData),hl
        ld (PLY_AKM_Channel2_SoundEffectData),hl
        ld (PLY_AKM_Channel3_SoundEffectData),hl
       .endif ;PLY_AKM_MANAGE_SOUND_EFFECTS
        
        ;For ROM, generates the RET table.
       .if PLY_AKM_Rom
        ld ix,#PLY_AKM_RegistersForRom           ;Source.
        ld iy,#PLY_AKM_Registers_RetTable        ;Destination.
        ld bc,#PLY_AKM_SendPsgRegister
        ld de,4
PLY_AKM_InitRom_Loop:
                ld a,(ix)                 ;Gets the register.
                ld h,a
                inc ix
                and #0b00111111
                ld 0 (iy),a             ;Writes the register.
                ld 1 (iy),0             ;Value is 0 for now.
                ld a,h
                and #0b11000000
                jr nz,PLY_AKM_InitRom_Special
                ;Encodes the "normal" SendPsgRegister code address.
                ld 2 (iy),c
                ld 3 (iy),b
                add iy,de
                jr PLY_AKM_InitRom_Loop
PLY_AKM_InitRom_Special:
               .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
                rl h
                jr c,PLY_AKM_InitRom_WriteEndCode
                ;Bit 6 must be set if we came here.
                ld bc,#PLY_AKM_SendPsgRegisterR13
                ld 2 (iy),c
                ld 3 (iy),b
                ld bc,#PLY_AKM_SendPsgRegisterAfterPop ;This one is a trick to send the register after R13 is managed.
                ld 4 (iy),c
                ld 5 (iy),b
                add iy,de               ;Only advance of 4, the code belows expects that.
               .endif ;PLY_CFG_UseHardwareSounds
                
PLY_AKM_InitRom_WriteEndCode:
                ld bc,#PLY_AKM_SendPsgRegisterEnd
                ld 2 (iy),c
                ld 3 (iy),b
       .endif
   .if HARDWARE_ENTERPRISE
        jp     ayReset
   .else
        ret
   .endif

        
        ;If ROM, the registers to send, IN THE ORDER they are declared in the ROM buffer!
        ;Bit 7 if ends (end DW to encode). Exclusive to bit 6.
        ;Bit 6 if R13/AfterPop the end DW to encode. Exclusive to bit 7.
       .if PLY_AKM_Rom
PLY_AKM_RegistersForRom:
               .db 8, 0, 1, 9, 2, 3, 10, 4, 5
               .if PLY_AKM_USE_NoiseRegister          ;CONFIG SPECIFIC
                       .db 6
               .endif
               .ifeq PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
                       .db 7 + 128
               .else
                       .db 7, 11, 12 + 64     ;13 is NOT declared, special case.
               .endif
       .endif

;Addresses where to put the header data.
PLY_AKM_InitVars_Start:
       .dw PLY_AKM_NoteIndexTable + PLY_AKM_Offset1b
       .dw PLY_AKM_NoteIndexTable + PLY_AKM_Offset1b + 1
       .dw PLY_AKM_TrackIndex + PLY_AKM_Offset1b
       .dw PLY_AKM_TrackIndex + PLY_AKM_Offset1b + 1
       .dw PLY_AKM_Speed + PLY_AKM_Offset1b
       .dw PLY_AKM_PrimaryInstrument + PLY_AKM_Offset1b
       .dw PLY_AKM_SecondaryInstrument + PLY_AKM_Offset1b
       .dw PLY_AKM_PrimaryWait + PLY_AKM_Offset1b
       .dw PLY_AKM_SecondaryWait + PLY_AKM_Offset1b
       .dw PLY_AKM_DefaultStartNoteInTracks + PLY_AKM_Offset1b
       .dw PLY_AKM_DefaultStartInstrumentInTracks + PLY_AKM_Offset1b
       .dw PLY_AKM_DefaultStartWaitInTracks + PLY_AKM_Offset1b
       .dw PLY_AKM_FlagNoteAndEffectInCell + PLY_AKM_Offset1b
PLY_AKM_InitVars_End:


;Cuts the channels, stopping all sounds.
       .if PLY_AKM_STOP_SOUNDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKM_stop
;;
;;    Stops playing musing and sound effects on all 3 channels.
;;
;; C Definition:
;;    void <cpct_akpAKM_stop> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKM_stop_asm
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
_cpct_akpAKM_stop::
cpct_akpAKM_stop_asm::  ;; Entry point for assembly calls  
PLY_AKM_StopDisarkGenerateExternalLabel:
PLY_AKM_Stop:
       .ifeq PLY_AKM_HARDWARE_ENTERPRISE 
        ld (PLY_AKM_SaveSP + PLY_AKM_Offset1b),sp
       .endif
        xor a
        ld (PLY_AKM_Track1_Volume),a
        ld (PLY_AKM_Track2_Volume),a
        ld (PLY_AKM_Track3_Volume),a
       .if PLY_AKM_HARDWARE_MSX
                ld a,#0b10111111          ;On MSX, bit 7 must be 1, bit 6 0.
       .else
                ld a,#0b00111111          ;On CPC, bit 6 must be 0. Other platforms don't care.
       .endif
        ld (PLY_AKM_MixerRegister),a
        jp PLY_AKM_SendPsg
       .endif ;PLY_AKM_STOP_SOUNDS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_akpAKM_musicPlay
;;
;;    Plays next music cycle of the present song with Arkos Tracker Player. Song 
;; has had to be previously established with <cpct_akp_musicInit>.
;;
;; C Definition:
;;    void <cpct_akpAKM_musicPlay> ()
;;
;; Assembly call (Input parameters on registers):
;;    > call cpct_akpAKM_musicPlay_asm
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

_cpct_akpAKM_musicPlay::
cpct_akpAKM_musicPlay_asm::   ;; Entry point for assembly calls  

;Plays one frame of the song. It MUST have been initialized before.
;The stack is saved and restored, but is diverted, so watch out for the interruptions.
PLY_AKM_PlayDisarkGenerateExternalLabel:
PLY_AKM_Play:
       .ifeq PLY_AKM_HARDWARE_ENTERPRISE 
        ld (PLY_AKM_SaveSP + PLY_AKM_Offset1b),sp
       .endif
        ;Reads a new line?
       .ifeq PLY_AKM_Rom
PLY_AKM_TickCounter: ld a,#0x00
        inc a
PLY_AKM_Speed: cp #0x01                       ;Speed (>0).
       .else
        ld a,(PLY_AKM_Speed)
        ld b,a
        ld a,(PLY_AKM_TickCounter)
        inc a
        cp b
       .endif
        jp nz,PLY_AKM_TickCounterManaged

        ;A new line must be read. But have we reached the end of the Pattern?
       .ifeq PLY_AKM_Rom
PLY_AKM_PatternRemainingHeight: ld a,#0x00              ;Height. If 0, end of the pattern.
       .else
        ld a,(PLY_AKM_PatternRemainingHeight)
       .endif
        sub #0x1
        jr c,PLY_AKM_Linker
        ;Pattern not ended. No need to read the Linker.
        ld (PLY_AKM_PatternRemainingHeight + PLY_AKM_Offset1b),a
        jr PLY_AKM_ReadLine

        ;New pattern. Reads the Linker.
PLY_AKM_Linker:
       .ifeq PLY_AKM_Rom
PLY_AKM_TrackIndex: ld de,#0x0000              ;DE' points on the Track Index. Useful when new Tracks are found.
       .else
        ld de,(PLY_AKM_TrackIndex)
       .endif
        exx
       .ifeq PLY_AKM_Rom
PLY_AKM_PtLinker: ld hl,#0x0000
       .else
        ld hl,(PLY_AKM_PtLinker)
       .endif
PLY_AKM_LinkerPostPt:
        ;Resets the possible empty cell counter of each Track.
        xor a
        ld (PLY_AKM_Track1_WaitEmptyCell),a
        ld (PLY_AKM_Track2_WaitEmptyCell),a
        ld (PLY_AKM_Track3_WaitEmptyCell),a
        ;On new pattern, the escape note/instrument/wait values are set for each Tracks.
       .ifeq PLY_AKM_Rom
PLY_AKM_DefaultStartNoteInTracks: ld a,#0x00
       .else
        ld a,(PLY_AKM_DefaultStartNoteInTracks)
       .endif
        ld (PLY_AKM_Track1_EscapeNote),a
        ld (PLY_AKM_Track2_EscapeNote),a
        ld (PLY_AKM_Track3_EscapeNote),a
       .ifeq PLY_AKM_Rom
PLY_AKM_DefaultStartInstrumentInTracks: ld a,#0x00
       .else
        ld a,(PLY_AKM_DefaultStartInstrumentInTracks)
       .endif
        ld (PLY_AKM_Track1_EscapeInstrument),a
        ld (PLY_AKM_Track2_EscapeInstrument),a
        ld (PLY_AKM_Track3_EscapeInstrument),a
       .ifeq PLY_AKM_Rom
PLY_AKM_DefaultStartWaitInTracks: ld a,#0x00
       .else
        ld a,(PLY_AKM_DefaultStartWaitInTracks)
       .endif
        ld (PLY_AKM_Track1_EscapeWait),a
        ld (PLY_AKM_Track2_EscapeWait),a
        ld (PLY_AKM_Track3_EscapeWait),a

        ;Reads the state byte of the pattern.
        ld b,(hl)
        inc hl
        rr b             ;Speed change or end of song?
        jr nc,PLY_AKM_LinkerAfterSpeedChange
        ;Next byte is either the speed (>0) or an end of song marker.
        ld a,(hl)
        inc hl
                        ;If no speed used, it means "end of song" every time.
                       .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC        
        or a            ;0 if end of song,.else speed.
        jr nz,PLY_AKM_LinkerSpeedChange
                       .endif ;PLY_CFG_UseSpeedTracks
        ;End of song.
        ld a,(hl)       ;Reads where to loop in the Linker.
        inc hl
        ld h,(hl)
        ld l,a
        jr PLY_AKM_LinkerPostPt
                       .if PLY_CFG_UseSpeedTracks            ;CONFIG SPECIFIC        
PLY_AKM_LinkerSpeedChange:
        ;Speed change.
        ld (PLY_AKM_Speed + PLY_AKM_Offset1b),a
                       .endif ;PLY_CFG_UseSpeedTracks
PLY_AKM_LinkerAfterSpeedChange:

        ;New height?
        rr b
        jr nc,PLY_AKM_LinkerUsePreviousHeight
        ld a,(hl)
        inc hl
        ld (PLY_AKM_LinkerPreviousRemainingHeight + PLY_AKM_Offset1b),a
        jr PLY_AKM_LinkerSetRemainingHeight
        ;The same height is used. It was stored before.
PLY_AKM_LinkerUsePreviousHeight:
       .ifeq PLY_AKM_Rom
PLY_AKM_LinkerPreviousRemainingHeight: ld a,#0x00
       .else
        ld a,(PLY_AKM_LinkerPreviousRemainingHeight)
       .endif
PLY_AKM_LinkerSetRemainingHeight:
        ld (PLY_AKM_PatternRemainingHeight + PLY_AKM_Offset1b),a

        ;New Transposition and Track for channel 1?
        ld ix,#PLY_AKM_Track1_Data
        call PLY_AKM_CheckTranspositionAndTrack
        ;New Transposition and Track for channel 2?
        ld ix,#PLY_AKM_Track2_Data
        call PLY_AKM_CheckTranspositionAndTrack
        ;New Transposition and Track for channel 3?
        ld ix,#PLY_AKM_Track3_Data
        call PLY_AKM_CheckTranspositionAndTrack
        
        ld (PLY_AKM_PtLinker + PLY_AKM_Offset1b),hl


;Reads the Tracks.
;---------------------------------
PLY_AKM_ReadLine:
       .ifeq PLY_AKM_Rom
PLY_AKM_PtInstruments: ld de,#0x0000
PLY_AKM_NoteIndexTable: ld bc,#0x0000
       .else
        ld de,(PLY_AKM_PtInstruments)
        ld bc,(PLY_AKM_NoteIndexTable)
       .endif
        exx
                ld ix,#PLY_AKM_Track1_Data
                call PLY_AKM_ReadTrack
                ld ix,#PLY_AKM_Track2_Data
                call PLY_AKM_ReadTrack
                ld ix,#PLY_AKM_Track3_Data
                call PLY_AKM_ReadTrack

                xor a
PLY_AKM_TickCounterManaged:
                ld (PLY_AKM_TickCounter + PLY_AKM_Offset1b),a



;Plays the sound stream.
;---------------------------------
                ld de,#PLY_AKM_PeriodTable
        exx

        ld c,#0b11100000          ;Register 7, shifted of 2 to the left. Bits 2 and 5 will be possibly changed by each iteration.

        ld ix,#PLY_AKM_Track1_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_AKM_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_AKM_Track1_Registers
        call PLY_AKM_PlaySoundStream

        srl c                   ;Not RR, because we have to make sure the b6 is 0,.else no more keyboard (on CPC)!
                                ;Also, on MSX, bit 6 must be 0.
        ld ix,#PLY_AKM_Track2_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_AKM_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_AKM_Track2_Registers
        call PLY_AKM_PlaySoundStream

       .if PLY_AKM_HARDWARE_MSX
                scf             ;On MSX, bit 7 must be 1.
                rr c
       .else
                rr c            ;On other platforms, we don't care about b7.
       .endif
        ld ix,#PLY_AKM_Track3_Data
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        call PLY_AKM_ManageEffects
                       .endif ;PLY_CFG_UseEffects
        ld iy,#PLY_AKM_Track3_Registers
        call PLY_AKM_PlaySoundStream

        ld a,c

;Plays the sound effects, if desired.
;-------------------------------------------
       .if PLY_AKM_MANAGE_SOUND_EFFECTS
                        call PLY_AKM_PlaySoundEffectsStream
       .else
                        ld (PLY_AKM_MixerRegister),a
       .endif ;PLY_AKM_MANAGE_SOUND_EFFECTS



;Sends the values to the PSG.
;---------------------------------
PLY_AKM_SendPsg:
      .if PLY_AKM_HARDWARE_ENTERPRISE

        ld      de,#PLY_AKM_Registers_RetTable
        call    ayRegisterWrite_DE  ;reg 8
        call    ayRegisterWrite_DE  ;reg 0
        call    ayRegisterWrite_DE  ;reg 1
        call    ayRegisterWrite_DE  ;reg 9
        call    ayRegisterWrite_DE  ;reg 2
        call    ayRegisterWrite_DE  ;reg 3
        call    ayRegisterWrite_DE  ;reg 10
        call    ayRegisterWrite_DE  ;reg 4
        call    ayRegisterWrite_DE  ;reg 5
       .if PLY_AKM_USE_NoiseRegister        ;CONFIG SPECIFIC
        call    ayRegisterWrite_DE  ;reg 6
       .endif
       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        call    ayRegisterWrite_DE  ;reg 7
        call    ayRegisterWrite_DE  ;reg 11
        call    ayRegisterWrite_DE  ;reg 12
PLY_AKM_SendPsgRegisterR13:
PLY_AKM_SetReg13: 
        ld      a,#0x00
PLY_AKM_SetReg13Old: 
        cp      #0x00
        ret     z
        ;Different. R13 must be played. Updates the old R13 value.
        ld      (PLY_AKM_SetReg13Old + 1),a
        ld      c,#0x0d
        jp      ayRegisterWrite     ;reg 13
       .else
;        jp      ayRegisterWrite_DE  ;reg 7
       .endif
ayRegisterWrite_DE:
        ld      a,(de)
        ld      c,a
        inc     de
        ld      a,(de)
        inc     de
        inc     de
        inc     de
        jp      ayRegisterWrite

    .include "AYemul_EP.src"

PLY_AKM_SendPsgRegister:
PLY_AKM_SendPsgRegisterAfterPop:
PLY_AKM_SendPsgRegisterEnd: 
      .else
        ld sp,#PLY_AKM_Registers_RetTable

       .if PLY_AKM_HARDWARE_CPC
        ld bc,#0xf680
        ld a,#0xc0
        ld de,#0xf4f6
        out (c),a	;#f6c0          ;Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
       .endif

       .if PLY_AKM_HARDWARE_SPECTRUM + PLY_AKM_HARDWARE_PENTAGON
        ld de,#0xbfff
        ld c,#0xfd
       .endif

PLY_AKM_SendPsgRegister:
        pop hl          ;H = value, L = register.
PLY_AKM_SendPsgRegisterAfterPop:
       .if PLY_AKM_HARDWARE_CPC
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

       .if PLY_AKM_HARDWARE_SPECTRUM + PLY_AKM_HARDWARE_PENTAGON
        ld b,e
        out (c),l       ;#fffd + register.
        ld b,d
        out (c),h       ;#bffd + value
       .endif

       .if PLY_AKM_HARDWARE_MSX
        ld a,l          ;Register.
        out (#0xa0),a
        ld a,h          ;Value.
        out (#0xa1),a
       .endif
        ret

                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
PLY_AKM_SendPsgRegisterR13:

        ;Should the R13 be played? Yes only if different. No "force retrig" is managed by this player.
       .ifeq PLY_AKM_Rom
PLY_AKM_SetReg13: ld a,#0x00
PLY_AKM_SetReg13Old: cp #0x00
       .else
        ld a,(PLY_AKM_SetReg13Old)
        ld b,a
        ld a,(PLY_AKM_SetReg13)
        cp b
       .endif
        jr z,PLY_AKM_SendPsgRegisterEnd
        ;Different. R13 must be played. Updates the old R13 value.
        ld (PLY_AKM_SetReg13Old + PLY_AKM_Offset1b),a

        ld h,a
        ld l,#0x0d

       .if PLY_AKM_HARDWARE_CPC
                ld a,#0xc0
       .endif

        ret                     ;Sends the 13th registers.
                       .endif ;PLY_CFG_UseHardwareSounds
PLY_AKM_SendPsgRegisterEnd:

       .ifeq PLY_AKM_Rom
PLY_AKM_SaveSP: ld sp,#0x0000
       .else
        ld sp,(PLY_AKM_SaveSP)
       .endif
        ret
      .endif




;Shifts B to the right, if carry, a transposition is read.
;Shifts B to the right once again, if carry, a new Track is read (may be an index or a track offset).
;IN:    HL = where to read the data.
;       IX = points on the track data buffer.
;       DE'= Track index table
;       B  = flags.
;OUT:   B  = shifted of two.
;       HL = increased according to read data.
PLY_AKM_CheckTranspositionAndTrack:
        ;New transposition?
        rr b
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        jr nc,PLY_AKM_CheckTranspositionAndTrack_AfterTransposition
        ;Transposition.
        ld a,(hl)
        ld PLY_AKM_Data_OffsetTransposition (ix),a
        inc hl
PLY_AKM_CheckTranspositionAndTrack_AfterTransposition:
                       .endif ;PLY_CFG_UseTranspositions
        ;New Track?
        rr b
        jr nc,PLY_AKM_CheckTranspositionAndTrack_NoNewTrack
        ;New Track.
        ld a,(hl)
        inc hl
        ;Is it a reference?
        sla a
        jr nc,PLY_AKM_CheckTranspositionAndTrack_TrackOffset
        ;Reference.
        exx
                ld l,a          ;A is the track index * 2.
                ld h,#0x00
                add hl,de       ;HL points on the track address.
                ld a,(hl)
                ld PLY_AKM_Data_OffsetPtStartTrack + 0 (ix),a
                ld PLY_AKM_Data_OffsetPtTrack + 0 (ix),a
                inc hl
                ld a,(hl)
                ld PLY_AKM_Data_OffsetPtStartTrack + 1 (ix),a
                ld PLY_AKM_Data_OffsetPtTrack + 1 (ix),a
        exx
        ret
PLY_AKM_CheckTranspositionAndTrack_TrackOffset:
        ;The Track is an offset. Counter the previous shift.
        rra             ;Carry was 0, so bit 7 is 0.
        ld d,a          ;D is the MSB of the offset.
        ld e,(hl)       ;Reads the LSB of the offset.
        inc hl
        
        ld c,l          ;Saves HL.
        ld a,h
        
        add hl,de       ;HL is now the Track (offset + $ (past offset));
        ld PLY_AKM_Data_OffsetPtStartTrack + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtStartTrack + 1 (ix),h
        ld PLY_AKM_Data_OffsetPtTrack + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtTrack + 1 (ix),h
        
        ld l,c          ;Retrieves HL.
        ld h,a
        ret
PLY_AKM_CheckTranspositionAndTrack_NoNewTrack:
        ;Copies the old Track inside the new Track pointer, as it evolves.
        ld a,PLY_AKM_Data_OffsetPtStartTrack + 0 (ix)
        ld PLY_AKM_Data_OffsetPtTrack + 0 (ix),a
        ld a,PLY_AKM_Data_OffsetPtStartTrack + 1 (ix)
        ld PLY_AKM_Data_OffsetPtTrack + 1 (ix),a
        ret





;Reads a Track.
;IN:    IX = Data block of the Track.
;       DE'= Instrument table. Do not modify!
;       BC'= Note index table. Do not modify!
PLY_AKM_ReadTrack:
        ;Are there any empty lines to wait?
        ld a,PLY_AKM_Data_OffsetWaitEmptyCell (ix)
        sub #0x01
        jr c,PLY_AKM_RT_NoEmptyCell
        ;Wait!
        ld PLY_AKM_Data_OffsetWaitEmptyCell (ix),a
        ret

PLY_AKM_RT_NoEmptyCell:
        ;Reads the Track pointer.
        ld l,PLY_AKM_Data_OffsetPtTrack + 0 (ix)
        ld h,PLY_AKM_Data_OffsetPtTrack + 1 (ix)
PLY_AKM_RT_GetDataByte:
        ld b,(hl)
        inc hl
        ;First, reads the note/effect flag.
       .if PLY_AKM_Rom
        ld a,(PLY_AKM_FlagNoteAndEffectInCell)
        ld c,a
       .endif
        ld a,b
        and #0b1111       ;Keeps only the note/data.
       .ifeq PLY_AKM_Rom
PLY_AKM_FlagNoteAndEffectInCell: cp #0x0c          ;0-12 = note reference if no effects in the song, or 0-11 if there are effects in the song.
       .else
        cp c
       .endif
        jr c,PLY_AKM_RT_NoteReference
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
        sub #0x0c                                  ;Can not be optimized with the code above, its value is automodified.
        jr z,PLY_AKM_RT_NoteAndEffects
        dec a
        jr z,PLY_AKM_RT_NoNoteMaybeEffects
                       .else
        sub #0x0d
        jr z,PLY_AKM_RT_ReadWaitFlags          ;If no effects, directly check the wait flag.
                       .endif ;PLY_CFG_UseEffects
        dec a
        jr z,PLY_AKM_RT_NewEscapeNote
        ;15. Same escape note.
        ld a,PLY_AKM_Data_OffsetEscapeNote (ix)
        jr PLY_AKM_RT_AfterNoteRead
        
PLY_AKM_RT_NewEscapeNote:
        ;Reads the escape note, and stores it, it may be reused by other cells.
        ld a,(hl)
        ld PLY_AKM_Data_OffsetEscapeNote (ix),a
        inc hl
        jr PLY_AKM_RT_AfterNoteRead

                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
PLY_AKM_RT_NoteAndEffects:
        ;There is a "note and effects". This is a special case. A new data byte must be read, with the note and the normal flags.
        ;However, we use a "force effects" to mark the presence of effects.
        dec a     ;A is 0, give it any other value.
        ld (PLY_AKM_RT_ReadEffectsFlag + PLY_AKM_Offset1b),a
        jr PLY_AKM_RT_GetDataByte
        
PLY_AKM_RT_NoNoteMaybeEffects:
        ;Reads flag "instrument" to know what to do. The flags are diverted to indicate whether there are effects.
        bit 4,b     ;Effects?
        jr z,PLY_AKM_RT_ReadWaitFlags  ;No effects. As there is no note, logically, there are no instrument to read, so simply reads the Wait value.
        ld a,b          ;B is not 0, so it works.
        ld (PLY_AKM_RT_ReadEffectsFlag + PLY_AKM_Offset1b),a
        jr PLY_AKM_RT_ReadWaitFlags
                       .endif ;PLY_CFG_UseEffects        
        
PLY_AKM_RT_NoteReference:
        ;A is the index of the note.
        exx
                ld l,a
                ld h,#0x00
                add hl,bc
                ld a,(hl)
        exx

        ;A is the right note (0-127).
PLY_AKM_RT_AfterNoteRead:
        ;Adds the transposition.
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
        add a,PLY_AKM_Data_OffsetTransposition (ix)
                       .endif ;PLY_CFG_UseTranspositions
        ld PLY_AKM_Data_OffsetBaseNote (ix) , a

        ;Reads the instruments flags.
        ;------------------
        ld a,b
        and #0b110000
        jr z,PLY_AKM_RT_SameEscapeInstrument
        cp #0b010000
        jr z,PLY_AKM_RT_PrimaryInstrument
        cp #0b100000
        jr z,PLY_AKM_RT_SecondaryInstrument
        ;New escape instrument. Reads and stores it, it may be reused by other cells.
        ld a,(hl)
        inc hl
        ld PLY_AKM_Data_OffsetEscapeInstrument (ix),a
        jr PLY_AKM_RT_StoreCurrentInstrument

PLY_AKM_RT_SameEscapeInstrument:
        ;Use the latest escape instrument.
        ld a,PLY_AKM_Data_OffsetEscapeInstrument (ix)
        jr PLY_AKM_RT_StoreCurrentInstrument

PLY_AKM_RT_SecondaryInstrument:
        ;Use the secondary instrument.
       .ifeq PLY_AKM_Rom
PLY_AKM_SecondaryInstrument: ld a,#0x00
       .else
        ld a,(PLY_AKM_SecondaryInstrument)
       .endif
        jr PLY_AKM_RT_StoreCurrentInstrument
        
PLY_AKM_RT_PrimaryInstrument:
        ;Use the primary instrument.
       .ifeq PLY_AKM_Rom
PLY_AKM_PrimaryInstrument: ld a,#0x00
       .else
        ld a,(PLY_AKM_PrimaryInstrument)
       .endif
        
PLY_AKM_RT_StoreCurrentInstrument:
        ;A is the instrument to play.
        exx
                ;Gets the address of the Instrument.
                add a,a         ;Only 127 instruments max.
                ld l,a
                ld h,#0x00
                add hl,de       ;Adds to the Instrument Table.
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                ;Reads the header of the Instrument.
                ld a,(hl)       ;Speed.
                inc hl
                ld PLY_AKM_Data_OffsetInstrumentSpeed (ix),a
                ;Stores the pointer on the data of the Instrument.
                ld PLY_AKM_Data_OffsetPtInstrument + 0 (ix),l
                ld PLY_AKM_Data_OffsetPtInstrument + 1 (ix),h
        exx
        xor a
        ;Resets the step on the Instrument.
        ld PLY_AKM_Data_OffsetInstrumentCurrentStep (ix),a
        ;Resets the Track pitch.
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetIsPitchUpDownUsed (ix),a
        ld PLY_AKM_Data_OffsetTrackPitchInteger + 0 (ix),a
        ld PLY_AKM_Data_OffsetTrackPitchInteger + 1 (ix),a
        ;ld PLY_AKM_Data_OffsetTrackPitchDecimal (ix),a               ;Shouldn't be needed, the difference shouldn't be noticeable.
                       .endif ;PLY_AKM_USE_EffectPitchUpDown

        ;Resets the offset on Arpeggio and Pitch tables.
                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetPtArpeggioOffset (ix),a
        ld PLY_AKM_Data_OffsetArpeggioCurrentStep (ix),a
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
        ld a,PLY_AKM_Data_OffsetArpeggioOriginalSpeed (ix)            ;The arpeggio speed must be reset.
        ld PLY_AKM_Data_OffsetArpeggioCurrentSpeed (ix),a
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable

                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetPtPitchOffset (ix),a
        ld PLY_AKM_Data_OffsetPitchCurrentStep (ix),a        
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
        ld a,PLY_AKM_Data_OffsetPitchOriginalSpeed (ix)               ;The pitch speed must be reset.
        ld PLY_AKM_Data_OffsetPitchCurrentSpeed (ix),a
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
                       .endif ;PLY_CFG_UseEffect_PitchTable

        
        ;Reads the wait flags.
        ;----------------------
PLY_AKM_RT_ReadWaitFlags:
        ld a,b
        and #0b11000000
        jr z,PLY_AKM_RT_SameEscapeWait
        cp #0b01000000
        jr z,PLY_AKM_RT_PrimaryWait
        cp #0b10000000
        jr z,PLY_AKM_RT_SecondaryWait
        ;New escape wait. Reads and stores it, it may be reused by other cells.
        ld a,(hl)
        inc hl
        ld PLY_AKM_Data_OffsetEscapeWait (ix),a
        jr PLY_AKM_RT_StoreCurrentWait
                
PLY_AKM_RT_SameEscapeWait:
        ;Use the latest escape wait.
        ld a,PLY_AKM_Data_OffsetEscapeWait (ix)
        jr PLY_AKM_RT_StoreCurrentWait
        
PLY_AKM_RT_PrimaryWait:
        ;Use the primary wait.
       .ifeq PLY_AKM_Rom
PLY_AKM_PrimaryWait: ld a,#0x00
       .else
        ld a,(PLY_AKM_PrimaryWait)
       .endif
        jr PLY_AKM_RT_StoreCurrentWait

PLY_AKM_RT_SecondaryWait:
        ;Use the secondary wait.
       .ifeq PLY_AKM_Rom
PLY_AKM_SecondaryWait: ld a,#0x00
       .else
        ld a,(PLY_AKM_SecondaryWait)
       .endif

PLY_AKM_RT_StoreCurrentWait:
        ;A is the wait to store.
        ld PLY_AKM_Data_OffsetWaitEmptyCell (ix),a

        ;--------------------
        ;Are there effects to read?
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
       .ifeq PLY_AKM_Rom
PLY_AKM_RT_ReadEffectsFlag: ld a,#0x00
       .else
        ld a,(PLY_AKM_RT_ReadEffectsFlag)
       .endif
        or a
        jr nz,PLY_AKM_RT_ReadEffects
PLY_AKM_RT_AfterEffects:
                       .endif ;PLY_CFG_UseEffects
        ;No effects, or after they have been managed.
        ;Saves the new pointer on the Track.
        ld PLY_AKM_Data_OffsetPtTrack + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtTrack + 1 (ix),h
        ret
                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
PLY_AKM_RT_ReadEffects:
        ;Resets the effect presence flag.
        xor a
        ld (PLY_AKM_RT_ReadEffectsFlag + PLY_AKM_Offset1b),a
        
PLY_AKM_RT_ReadEffect:
        ld iy,#PLY_AKM_EffectTable
        ;Reads effect number and possible data. All effect must jump to PLY_AKM_RT_ReadEffect_Return when finished.
        ld b,(hl)
        ld a,b
        inc hl
        
        and #0b1110
        ld e,a
        ld d,#0x00
        add iy,de
        
        ;As a convenience, puts the effect nibble "to the right", for direct use.
        ld a,b
        rra
        rra
        rra
        rra
        and #0b1111               ;This sets the carry flag, useful for the effects code.
        ;Executes the effect code.
        jp (iy)
PLY_AKM_RT_ReadEffect_Return:
        ;More effects?
        bit 0,b
        jr nz,PLY_AKM_RT_ReadEffect
        jr PLY_AKM_RT_AfterEffects

PLY_AKM_RT_WaitLong:
        ;A 8-bit byte is encoded just after.
        ld a,(hl)
        inc hl
        ld PLY_AKM_Data_OffsetWaitEmptyCell (ix),a
        jr PLY_AKM_RT_CellRead
PLY_AKM_RT_WaitShort:
        ;Only a 2-bit value is encoded.
        ld a,b
        rlca                     ;Transfers the bit 7/6 to 1/0. Thanks Hicks for the RCLA trick!
        rlca
        and #0b11
        ld PLY_AKM_Data_OffsetWaitEmptyCell (ix),a
        ;jr PLY_AKM_RT_CellRead
;Jumped to after the Cell has been read.
;IN:    HL = new value of the Track pointer. Must point after the read Cell.
PLY_AKM_RT_CellRead:
        ld PLY_AKM_Data_OffsetPtTrack + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtTrack + 1 (ix),h
        ret


;Manages the effects, if any. For the activated effects, modifies the internal data for the Track which data block is given.
;IN:    IX = data block of the Track.
;OUT:   IX, IY = unmodified.
;       C must NOT be modified!
;       DE' must NOT be modified!
PLY_AKM_ManageEffects:
                               .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
        ;Pitch up/down used?
        ld a,PLY_AKM_Data_OffsetIsPitchUpDownUsed (ix)
        or a
        jr z,PLY_AKM_ME_PitchUpDownFinished

        ;Adds the LSB of integer part and decimal part, using one 16 bits operation.
        ld l,PLY_AKM_Data_OffsetTrackPitchDecimal (ix)
        ld h,PLY_AKM_Data_OffsetTrackPitchInteger + 0 (ix)

        ld e,PLY_AKM_Data_OffsetTrackPitchSpeed + 0 (ix)
        ld d,PLY_AKM_Data_OffsetTrackPitchSpeed + 1 (ix)

        ld a,PLY_AKM_Data_OffsetTrackPitchInteger + 1 (ix)

        ;Negative pitch?
        bit 7,d
        jr nz,PLY_AKM_ME_PitchUpDown_NegativeSpeed

PLY_AKM_ME_PitchUpDown_PositiveSpeed:
        ;Positive speed. Adds it to the LSB of the integer part, and decimal part.
        add hl,de

        ;Carry? Transmits it to the MSB of the integer part.
        adc #0x00
        jr PLY_AKM_ME_PitchUpDown_Save
PLY_AKM_ME_PitchUpDown_NegativeSpeed:
        ;Negative speed. Resets the sign bit. The encoded pitch IS positive.
        ;Subtracts it to the LSB of the integer part, and decimal part.
        res 7,d

        or a
        sbc hl,de

        ;Carry? Transmits it to the MSB of the integer part.
        sbc #0x00

PLY_AKM_ME_PitchUpDown_Save:
        ld PLY_AKM_Data_OffsetTrackPitchInteger + 1 (ix),a

        ld PLY_AKM_Data_OffsetTrackPitchDecimal (ix),l
        ld PLY_AKM_Data_OffsetTrackPitchInteger + 0 (ix),h

PLY_AKM_ME_PitchUpDownFinished:
                               .endif ;PLY_AKM_USE_EffectPitchUpDown



        ;Manages the Arpeggio Table effect, if any.
        ;------------------------------------------
                               .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
        ld a,PLY_AKM_Data_OffsetIsArpeggioTableUsed (ix)
        or a
        jr z,PLY_AKM_ME_ArpeggioTableFinished

        ;Plays the arpeggio current note. It is suppose to be correct (not a loop).
        ;Plays it in any case, in order to manage some corner case with Force Arpeggio Speed.
        ld e,PLY_AKM_Data_OffsetPtArpeggioTable + 0 (ix)
        ld d,PLY_AKM_Data_OffsetPtArpeggioTable + 1 (ix)
        ld l,PLY_AKM_Data_OffsetPtArpeggioOffset (ix)
        ld h,#0x00
        add hl,de
        ld a,(hl)       ;Gets the Arpeggio value (b1-b7).
        sra a           ;Carry is 0, because the ADD above surely didn't overflow.
        ld PLY_AKM_Data_OffsetCurrentArpeggioValue (ix),a

        ;Moves forward, if the speed has been reached.
        ;Has the speed been reached?
        ld a,PLY_AKM_Data_OffsetArpeggioCurrentStep (ix)
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
        cp PLY_AKM_Data_OffsetArpeggioCurrentSpeed (ix)
                               .else
        cp PLY_AKM_Data_OffsetArpeggioOriginalSpeed (ix)
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
        jr c,PLY_AKM_ME_ArpeggioTable_SpeedNotReached
        ;Resets the speed. Reads the next Arpeggio value.
        ld PLY_AKM_Data_OffsetArpeggioCurrentStep (ix),#0x00
        
        ;Advances in the Arpeggio.
        inc PLY_AKM_Data_OffsetPtArpeggioOffset (ix)
        inc hl          ;HL points on the next value. No need to add to the base offset like before, we have it.
        ld a,(hl)
        ;End of the Arpeggio?
        rra             ;Carry is 0.
        jr nc,PLY_AKM_ME_ArpeggioTableFinished
        ;End of the Arpeggio. The loop offset is now in A.
        ld l,a
        ld PLY_AKM_Data_OffsetPtArpeggioOffset (ix),a
        jr PLY_AKM_ME_ArpeggioTableFinished
        
PLY_AKM_ME_ArpeggioTable_SpeedNotReached:
        inc a
        ld PLY_AKM_Data_OffsetArpeggioCurrentStep (ix),a

PLY_AKM_ME_ArpeggioTableFinished:
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable



        ;Manages the Pitch Table effect, if any.
        ;------------------------------------------
                               .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld a,PLY_AKM_Data_OffsetIsPitchTableUsed (ix)
        or a
        ret z

        ;Plays the Pitch Table current note. It is suppose to be correct (not a loop).
        ;Plays it in any case, in order to manage some corner case with Force Pitch Speed.
        ;Reads the Pitch Table. Adds the Pitch base address to an offset.
        ld l,PLY_AKM_Data_OffsetPtPitchTable + 0 (ix)
        ld h,PLY_AKM_Data_OffsetPtPitchTable + 1 (ix)
        ld e,PLY_AKM_Data_OffsetPtPitchOffset (ix)
        ld d,#0x00
        add hl,de
        ld a,(hl)       ;Gets the Pitch value (b1-b7).
        sra a
        ;A = pitch note. It is converted to 16 bits.
        ;D is already 0.
        jp p,PLY_AKM_ME_PitchTableEndNotReached_Positive
        dec d
PLY_AKM_ME_PitchTableEndNotReached_Positive:
        ld PLY_AKM_Data_OffsetCurrentPitchTableValue + 0 (ix),a
        ld PLY_AKM_Data_OffsetCurrentPitchTableValue + 1 (ix),d
        
        ;Moves forward, if the speed has been reached.
        ;Has the speed been reached?
        ld a,PLY_AKM_Data_OffsetPitchCurrentStep (ix)
                       .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
        cp PLY_AKM_Data_OffsetPitchCurrentSpeed (ix)
                       .else
        cp PLY_AKM_Data_OffsetPitchOriginalSpeed (ix)
                       .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
        jr c,PLY_AKM_ME_PitchTable_SpeedNotReached
        ;Resets the speed, then reads the next Pitch value.
        ld PLY_AKM_Data_OffsetPitchCurrentStep (ix),#0x00
        
        ;Advances in the Pitch.
        inc PLY_AKM_Data_OffsetPtPitchOffset (ix)
        inc hl          ;HL points on the next value. No need to add to the base offset like before, we have it.
        ld a,(hl)
        ;End of the Pitch?
        rra             ;Carry is 0.
        ret nc
        ;End of the Pitch. The loop offset is now in A.
        ld l,a
        ld PLY_AKM_Data_OffsetPtPitchOffset (ix),a
        ret

PLY_AKM_ME_PitchTable_SpeedNotReached:
        inc a
        ld PLY_AKM_Data_OffsetPitchCurrentStep (ix),a
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
PLY_AKM_PlaySoundStream:
        ;Gets the pointer on the Instrument, from its base address and the offset.
        ld l,PLY_AKM_Data_OffsetPtInstrument + 0 (ix)
        ld h,PLY_AKM_Data_OffsetPtInstrument + 1 (ix)

        ;Reads the first byte of the cell of the Instrument. What type?
PLY_AKM_PSS_ReadFirstByte:
        ld a,(hl)
        ld b,a
        inc hl
        rra
        jr c,PLY_AKM_PSS_SoftOrSoftAndHard

        ;NoSoftNoHard or SoftwareToHardware
        rra
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        jr c,PLY_AKM_PSS_SoftwareToHardware
                       .endif ;PLY_CFG_UseHardwareSounds

        ;No software no hardware, or end of sound (loop)!
        ;End of sound?
        rra
        jr nc,PLY_AKM_PSS_NSNH_NotEndOfSound
   ;; Increment song loop times
   ld    a, (_cpct_akpAKM_songLoopTimes)
   inc   a
   ld (_cpct_akpAKM_songLoopTimes), a 
        ;The sound loops/ends. Where?
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ;As a sound always has at least one cell, we should safely be able to read its bytes without storing the instrument pointer.
        ;However, we do it anyway to remove the overhead of the Speed management: if looping, the same last line will be read,
        ;if several channels do so, it will be costly. So...
        ld PLY_AKM_Data_OffsetPtInstrument + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtInstrument + 1 (ix),h
        jr PLY_AKM_PSS_ReadFirstByte
;; Loop times
;;    Read here to know the number of times a song has looped
_cpct_akpAKM_songLoopTimes:: .db 0 

PLY_AKM_PSS_NSNH_NotEndOfSound:
        ;No software, no hardware.
        ;-------------------------
        ;Stops the sound.
        set 2,c

        ;Volume. A now contains the volume on b0-3.
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
        call PLY_AKM_PSS_Shared_AdjustVolume
                       .else
        and #0b1111
                       .endif ;PLY_CFG_UseEffect_SetVolume
        ld PLY_AKM_Registers_OffsetVolume (iy),a

        ;Read noise?
        rl b
                       .if PLY_CFG_NoSoftNoHard_Noise        ;CONFIG SPECIFIC
        call c,PLY_AKM_PSS_ReadNoise
                       .endif ;PLY_CFG_NoSoftNoHard_Noise
        jr PLY_AKM_PSS_Shared_StoreInstrumentPointer

        ;Software sound, or Software and Hardware?
PLY_AKM_PSS_SoftOrSoftAndHard:
        rra
                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
        jr c,PLY_AKM_PSS_SoftAndHard
                       .endif ;PLY_CFG_UseHardwareSounds

        ;Software sound.
        ;-----------------
        ;A is the volume. Already shifted twice, so it can be used directly.
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
        call PLY_AKM_PSS_Shared_AdjustVolume
                       .else
        and #0b1111
                       .endif ;PLY_CFG_UseEffect_SetVolume
        ld PLY_AKM_Registers_OffsetVolume (iy),a

        ;Arp and/or noise?
        ld d,#0x00          ;Default arpeggio.
        rl b
        jr nc,PLY_AKM_PSS_S_AfterArpAndOrNoise
        ld a,(hl)
        inc hl
        ;Noise?
        sra a
        ;A is now the signed Arpeggio. It must be kept.
        ld d,a
        ;Now takes care of the noise, if there is a Carry.
                       .if PLY_CFG_SoftOnly_Noise          ;CONFIG SPECIFIC
        call c,PLY_AKM_PSS_ReadNoise
                       .endif ;PLY_CFG_SoftOnly_Noise
PLY_AKM_PSS_S_AfterArpAndOrNoise:

        ld a,d          ;Gets the instrument arpeggio, if any.
        call PLY_AKM_CalculatePeriodForBaseNote

        ;Read pitch?
        rl b
                       .if PLY_CFG_SoftOnly_SoftwarePitch    ;CONFIG SPECIFIC
        call c,PLY_AKM_ReadPitchAndAddToPeriod
                       .endif ;PLY_CFG_SoftOnly_SoftwarePitch

        ;Stores the new period of this channel.
        exx
                ld PLY_AKM_Registers_OffsetSoftwarePeriodLSB (iy),l
                ld PLY_AKM_Registers_OffsetSoftwarePeriodMSB (iy),h
        exx

        ;The code below is shared!
        ;Stores the new instrument pointer, if Speed allows it.
        ;--------------------------------------------------
PLY_AKM_PSS_Shared_StoreInstrumentPointer:
        ;Checks the Instrument speed, and only stores the Instrument new pointer if the speed is reached.
        ld a,PLY_AKM_Data_OffsetInstrumentCurrentStep (ix)
        cp PLY_AKM_Data_OffsetInstrumentSpeed (ix)
        jr nc,PLY_AKM_PSS_S_SpeedReached
        ;Increases the current step.
        inc PLY_AKM_Data_OffsetInstrumentCurrentStep (ix)
        ret
PLY_AKM_PSS_S_SpeedReached:
        ;Stores the Instrument new pointer, resets the speed counter.
        ld PLY_AKM_Data_OffsetPtInstrument + 0 (ix),l
        ld PLY_AKM_Data_OffsetPtInstrument + 1 (ix),h
        ld PLY_AKM_Data_OffsetInstrumentCurrentStep (ix),#0x00
        ret


                       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC

        ;Software and Hardware.
        ;----------------------------
PLY_AKM_PSS_SoftAndHard:
        ;Reads the envelope bit, the possible pitch, and sets the software period accordingly.
        call PLY_AKM_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv
        ;Reads the hardware period.
        ld a,(hl)
        ld (PLY_AKM_Reg11),a
        inc hl
        ld a,(hl)
        ld (PLY_AKM_Reg12),a
        inc hl

        jr PLY_AKM_PSS_Shared_StoreInstrumentPointer


        ;Software to Hardware.
        ;-------------------------
PLY_AKM_PSS_SoftwareToHardware:
        call PLY_AKM_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv

        ;Now we can calculate the hardware period thanks to the ratio (contray to LW, it is NOT inverted, we can use it as-is).
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and #0b111
        exx
                jr z,PLY_AKM_PSS_STH_RatioEnd
PLY_AKM_PSS_STH_RatioLoop:
                srl h
                rr l
                dec a 
                jr nz,PLY_AKM_PSS_STH_RatioLoop
                ;If carry, rounds the period.
                jr nc,PLY_AKM_PSS_STH_RatioEnd
                inc hl
PLY_AKM_PSS_STH_RatioEnd:
                ld a,l
                ld (PLY_AKM_Reg11),a
                ld a,h
                ld (PLY_AKM_Reg12),a
        exx

        jr PLY_AKM_PSS_Shared_StoreInstrumentPointer

;A shared code for hardware sound.
;Reads the envelope bit in bit 1, arpeggio in bit 7 pitch in bit 2 from A. If pitch present, adds it to BC'.
;Converts the note to period, adds the instrument pitch, sets the software period of the channel.
;Also sets the hardware volume, and sets the hardware curve.
PLY_AKM_PSS_Shared_ReadEnvBitPitchArp_SoftPeriod_HardVol_HardEnv:
        ;Envelope bit? R13 = 8 + 2 * (envelope bit?). Allows to have hardware envelope to 8 or 0xa.
        ;Shifted by 2 to the right, bit 1 is now envelope bit, which is perfect for us.
        and #0b10
        add a,#0x08
        ld (PLY_AKM_SetReg13 + PLY_AKM_Offset1b),a

        ;Volume to 16 to trigger the hardware envelope.
        ld PLY_AKM_Registers_OffsetVolume (iy),#0x10

        ;Arpeggio?
        xor a                   ;Default arpeggio.
                       .if PLY_AKM_ArpeggioInHardwareInstrument  ;CONFIG SPECIFIC
        bit 7,b                 ;Not shifted yet.
        jr z,PLY_AKM_PSS_Shared_REnvBAP_AfterArpeggio
        ;Reads the Arpeggio.
        ld a,(hl)
        inc hl
PLY_AKM_PSS_Shared_REnvBAP_AfterArpeggio:
                       .endif ;PLY_AKM_ArpeggioInHardwareInstrument
        ;Calculates the software period.
        call PLY_AKM_CalculatePeriodForBaseNote

        ;Pitch?
                       .if PLY_AKM_PitchInHardwareInstrument  ;CONFIG SPECIFIC
        bit 2,b         ;Not shifted yet.
        call nz,PLY_AKM_ReadPitchAndAddToPeriod
                       .endif ;PLY_AKM_PitchInHardwareInstrument

        ;Stores the new period of this channel.
        exx
                ld PLY_AKM_Registers_OffsetSoftwarePeriodLSB (iy),l
                ld PLY_AKM_Registers_OffsetSoftwarePeriodMSB (iy),h
        exx
        ret

                       .endif ;PLY_CFG_UseHardwareSounds

                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
;Decreases the given volume (encoded in possibly more then 4 bits). If <0, forced to 0.
;IN:    A = volume, not ANDed.
;OUT:   A = new volume.
PLY_AKM_PSS_Shared_AdjustVolume:
        and #0b1111
        sub PLY_AKM_Data_OffsetTrackInvertedVolume (ix)
        ret nc
        xor a
        ret
                       .endif ;PLY_CFG_UseEffect_SetVolume

;Reads and stores the noise pointed by HL, opens the noise channel.
;IN:    HL = instrument data where the noise is.
;OUT:   HL = HL++.
;MOD:   A.
               .if PLY_AKM_USE_Noise          ;CONFIG SPECIFIC
PLY_AKM_PSS_ReadNoise:
        ld a,(hl)
        inc hl
        ld (PLY_AKM_NoiseRegister),a
        res 5,c                 ;Opens the noise channel.
        ret
               .endif ;PLY_AKM_USE_Noise
                
;Calculates the period according to the base note and put it in BC'. Used by both software and hardware codes.
;IN:    DE' = period table.
;       A = instrument arpeggio (0 if not used).
;OUT:   HL' = period.
;MOD:   A
PLY_AKM_CalculatePeriodForBaseNote:
        ;Gets the period from the current note.
        exx
                ld h,#0x00
                add a,PLY_AKM_Data_OffsetBaseNote (ix)                         ;Adds the instrument Arp to the base note (including the transposition).
                               .if PLY_CFG_UseEffect_ArpeggioTable            ;CONFIG SPECIFIC
                add PLY_AKM_Data_OffsetCurrentArpeggioValue (ix)               ;Adds the Arpeggio Table effect.
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable

                ;Finds the period from a single line of octave look-up table. This is slow...
                ;IN:    DE = PeriodTable.
                ;       A = note (>=0).
                ;OUT:   HL = period.
                ;       DE unmodified.
                ;       BC modified.

                ;Finds the octave.
                ld bc,#255 * 256 + 12            ;B = Octave (>=0). Will be increased just below.
PLY_AKM_FindOctave_Loop:
                inc b           ;Next octave.
                sub c
                jr nc,PLY_AKM_FindOctave_Loop
                add a,c         ;Compensates the first iteration that may not have been useful.
        
                ;A = note inside the octave. Gets the period for the note, for the lowest octave.
                add a,a
                ld l,a
                ld h,#0x00
                add hl,de       ;Points on the period on the lowest octave.
                ld a,(hl)
                inc hl
                ld h,(hl)       ;HL is the period on the lowest octave.
                ld l,a
                ;Divides the period as long as we haven't reached the octave.
                ld a,b
                or a
                jr z,PLY_AKM_FindOctave_OctaveShiftLoop_Finished
PLY_AKM_FindOctave_OctaveShiftLoop:
                srl h
                rr l
                djnz PLY_AKM_FindOctave_OctaveShiftLoop          ;Fortunately, does not modify the carry, used below.
PLY_AKM_FindOctave_OctaveShiftLoop_Finished:
                ;Rounds the period at the last iteration.
                jr nc,PLY_AKM_FindOctave_Finished
                inc hl
PLY_AKM_FindOctave_Finished:

                ;Adds the Pitch Table value, if used.
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
                ld a,PLY_AKM_Data_OffsetIsPitchTableUsed (ix)
                or a
                jr z,PLY_AKM_CalculatePeriodForBaseNote_NoPitchTable
                ld c,PLY_AKM_Data_OffsetCurrentPitchTableValue + 0 (ix)
                ld b,PLY_AKM_Data_OffsetCurrentPitchTableValue + 1 (ix)
                add hl,bc
PLY_AKM_CalculatePeriodForBaseNote_NoPitchTable:
                       .endif ;PLY_CFG_UseEffect_PitchTable
                ;Adds the Track Pitch.
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
                ld c,PLY_AKM_Data_OffsetTrackPitchInteger + 0 (ix)
                ld b,PLY_AKM_Data_OffsetTrackPitchInteger + 1 (ix)
                add hl,bc
                       .endif ;PLY_AKM_USE_EffectPitchUpDown
        exx
        ret

                       .if PLY_AKM_PitchInInstrument  ;CONFIG SPECIFIC
;Reads the pitch in the Instruments (16 bits) and adds it to HL', which should contain the software period.
;IN:    HL = points on the pitch value.
;OUT:   HL = points after the pitch.
;MOD:   A, BC', HL' updated.
PLY_AKM_ReadPitchAndAddToPeriod:
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
                       .endif ;PLY_AKM_PitchInInstrument







;---------------------------------------------------------------------
;Effect management.
;---------------------------------------------------------------------

                       .if PLY_CFG_UseEffects        ;CONFIG SPECIFIC
                        
;IN:    HL = points after the first byte.
;       A = data of the first byte on bits 0-3, the other bits are 0.
;       Carry = 0.
;       Z flag = 1 if the data is 0.
;       DE'= Instrument Table (not useful here). Do not modify!
;       IX = data block of the Track.
;       B = Do not modify!
;OUT:   HL = points after the data of the effect (maybe nothing to do).
;       Each effect must jump to PLY_AKM_RT_ReadEffect_Return.

                               .if PLY_CFG_UseEffect_Reset           ;CONFIG SPECIFIC.
;Clears all the effects (volume, pitch table, arpeggio table).
PLY_AKM_EffectResetWithVolume:
        ;Inverted volume.
                                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetTrackInvertedVolume (ix),a
                                       .endif ;PLY_CFG_UseEffect_SetVolume
        xor a
        ;The inverted volume is managed above, so don't change it.
                                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetIsPitchUpDownUsed (ix),a
                                       .endif ;PLY_AKM_USE_EffectPitchUpDown
                                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetIsArpeggioTableUsed (ix),a
        ld PLY_AKM_Data_OffsetCurrentArpeggioValue (ix),a      ;Contrary to the Pitch, the value must be reset.
                                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        ld PLY_AKM_Data_OffsetIsPitchTableUsed (ix),a
                                       .endif ;PLY_CFG_UseEffect_PitchTable
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_Reset


;Changes the volume.
                               .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
PLY_AKM_EffectVolume:
        ld PLY_AKM_Data_OffsetTrackInvertedVolume (ix),a
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_SetVolume

                               .if PLY_CFG_UseEffect_ForceInstrumentSpeed        ;CONFIG SPECIFIC
;Forces the speed of the Instrument. The current step is NOT changed.
PLY_AKM_EffectForceInstrumentSpeed:
        call PLY_AKM_EffectReadIfEscape         ;Makes sure the data is 0-14,.else 15 means: read the next escape value.
        ld PLY_AKM_Data_OffsetInstrumentSpeed (ix),a
        
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed

                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
;Forces the speed of the Pitch. The current step is NOT changed.
PLY_AKM_EffectForcePitchSpeed:
        call PLY_AKM_EffectReadIfEscape         ;Makes sure the data is 0-14,.else 15 means: read the next escape value.
        ld PLY_AKM_Data_OffsetPitchCurrentSpeed (ix),a
        ;ld PLY_AKM_Data_OffsetPitchCurrentStep (ix),a                ;No need to force next note of the Arpeggio. Faster, and more compliant with the C++ player.
        
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
        
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
;Forces the speed of the Arpeggio. The current step is NOT changed.
PLY_AKM_EffectForceArpeggioSpeed:
        call PLY_AKM_EffectReadIfEscape         ;Makes sure the data is 0-14,.else 15 means: read the next escape value.
        ld PLY_AKM_Data_OffsetArpeggioCurrentSpeed (ix),a
        ;ld PLY_AKM_Data_OffsetArpeggioCurrentStep (ix),a             ;No need to force next note of the Arpeggio. Faster, and more compliant with the C++ player.
        
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed


;Effect table. Each entry jumps to an effect management code.
;Put after the code above so that the JR are within bound.
PLY_AKM_EffectTable:
                               .if PLY_CFG_UseEffect_Reset           ;CONFIG SPECIFIC.
        jr PLY_AKM_EffectResetWithVolume                         ;000
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_Reset
                                
                               .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectVolume                                  ;001
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_SetVolume
        
                               .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectPitchUpDown                             ;010
                               .else
                                jr $
                               .endif ;PLY_AKM_USE_EffectPitchUpDown

                               .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectArpeggioTable                           ;011
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable
                               
                               .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectPitchTable                              ;100
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_PitchTable
        
                               .if PLY_CFG_UseEffect_ForceInstrumentSpeed        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectForceInstrumentSpeed                    ;101
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_ForceInstrumentSpeed
        
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectForceArpeggioSpeed                      ;110
                               .else
                                jr $
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
                   
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
        jr PLY_AKM_EffectForcePitchSpeed                         ;111
                               .else
                                ;jr $   ;Last one. No need to encode it.
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed             


                               .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
;Pitch up/down effect, activation or stop.
PLY_AKM_EffectPitchUpDown:
        rra     ;Pitch present or pitch stop?
        jr nc,PLY_AKM_EffectPitchUpDown_Deactivated
        ;Activates the effect.
        ld PLY_AKM_Data_OffsetIsPitchUpDownUsed (ix),#0xff
        ld a,(hl)
        inc hl
        ld PLY_AKM_Data_OffsetTrackPitchSpeed + 0 (ix),a
        ld a,(hl)
        inc hl
        ld PLY_AKM_Data_OffsetTrackPitchSpeed + 1 (ix),a
        jp PLY_AKM_RT_ReadEffect_Return
PLY_AKM_EffectPitchUpDown_Deactivated:
        ;Pitch stop.
        ld PLY_AKM_Data_OffsetIsPitchUpDownUsed (ix),#0x00
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_AKM_USE_EffectPitchUpDown
                        

                               .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
;Arpeggio table effect, activation or stop.
PLY_AKM_EffectArpeggioTable:
        call PLY_AKM_EffectReadIfEscape         ;Makes sure the data is 0-14,.else 15 means: read the next escape value.
        ld PLY_AKM_Data_OffsetIsArpeggioTableUsed (ix),a       ;Sets to 0 if the Arpeggio is stopped, or any other value if it starts.
        jr z,PLY_AKM_EffectArpeggioTable_Stop

        ;Gets the Arpeggio address.
        add a,a
        exx
                ld l,a
                ld h,#0x00
        ;BC is modified, will be restored below.
       .ifeq PLY_AKM_Rom
PLY_AKM_PtArpeggios: ld bc,#0x0000            ;Arpeggio table does not encode entry 0, but the pointer points two bytes earlier to compensate.
       .else
        ld bc,(PLY_AKM_PtArpeggios)
       .endif
                add hl,bc
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                ld a,(hl)               ;Reads the speed.
                inc hl
                ld PLY_AKM_Data_OffsetArpeggioOriginalSpeed (ix),a
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
                ld PLY_AKM_Data_OffsetArpeggioCurrentSpeed (ix),a
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
                ld PLY_AKM_Data_OffsetPtArpeggioTable + 0 (ix),l
                ld PLY_AKM_Data_OffsetPtArpeggioTable + 1 (ix),h
                
                ld bc,(PLY_AKM_NoteIndexTable + PLY_AKM_Offset1b)
        exx

        ;Resets the offset of the Arpeggio to restart the Arpeggio, and forces a step to read immediately.
        xor a
        ld PLY_AKM_Data_OffsetPtArpeggioOffset (ix),a
        ld PLY_AKM_Data_OffsetArpeggioCurrentStep (ix),a
        jp PLY_AKM_RT_ReadEffect_Return
PLY_AKM_EffectArpeggioTable_Stop:
        ;Contrary to the Pitch, the Arpeggio must also be set to 0 when stopped.
        ld PLY_AKM_Data_OffsetCurrentArpeggioValue (ix),a
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_ArpeggioTable

                               .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
;Pitch table effect, activation or stop.
;This is almost exactly the same code as for the Arpeggio, but I can't find a way to share it...
PLY_AKM_EffectPitchTable:
        call PLY_AKM_EffectReadIfEscape         ;Makes sure the data is 0-14,.else 15 means: read the next escape value.
        ld PLY_AKM_Data_OffsetIsPitchTableUsed (ix),a  ;Sets to 0 if the Pitch is stopped, or any other value if it starts.
        jp z,PLY_AKM_RT_ReadEffect_Return
        
        ;Gets the Pitch address.
        add a,a
        exx
                ld l,a
                ld h,#0x00
        ;BC is modified, will be restored below.
       .ifeq PLY_AKM_Rom
PLY_AKM_PtPitches: ld bc,#0x0000            ;Pitch table does not encode entry 0, but the pointer points two bytes earlier to compensate.
       .else
        ld bc,(PLY_AKM_PtPitches)
       .endif
                add hl,bc
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                ld a,(hl)               ;Reads the speed.
                inc hl
                ld PLY_AKM_Data_OffsetPitchOriginalSpeed (ix),a
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
                ld PLY_AKM_Data_OffsetPitchCurrentSpeed (ix),a
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
                ld PLY_AKM_Data_OffsetPtPitchTable + 0 (ix),l
                ld PLY_AKM_Data_OffsetPtPitchTable + 1 (ix),h
                
                ld bc,(PLY_AKM_NoteIndexTable + PLY_AKM_Offset1b)
        exx

        ;Resets the offset of the Pitch to restart the Pitch, and forces a step to read immediately.
        xor a
        ld PLY_AKM_Data_OffsetPtPitchOffset (ix),a
        ld PLY_AKM_Data_OffsetPitchCurrentStep (ix),a
        jp PLY_AKM_RT_ReadEffect_Return
                               .endif ;PLY_CFG_UseEffect_PitchTable





        
;Reads the next escape byte if A is 15,.else returns A (0-14).
;IN:    HL= data in the effect
;       A = 0-15. bit 7-4 must be 0.
;OUT:   HL= may be increased if an escape value is read.
;       A = the 8-bit value.
PLY_AKM_EffectReadIfEscape:
        cp #0x0f
        ret c
        ;Reads the escape value.
        ld a,(hl)
        inc hl
        ret

                       .endif ;PLY_CFG_UseEffects
                        
                        
;---------------------------------------------------------------------
;Data blocks for the three channels. Make sure NOTHING is added between, as the init clears everything!
;---------------------------------------------------------------------

        ;Specific generic data for ROM (non-related to channels).
        ;Important: must be declared BEFORE the channel-specific data.
       .if PLY_AKM_Rom
PLY_AKM_PtInstruments  .dw      #0x0000
PLY_AKM_PtArpeggios    .dw      #0x0000
PLY_AKM_PtPitches      .dw      #0x0000
PLY_AKM_PtLinker       .dw      #0x0000
PLY_AKM_NoteIndexTable .dw      #0x0000
PLY_AKM_TrackIndex     .dw      #0x0000
PLY_AKM_SaveSP         .dw      #0x0000
        
PLY_AKM_DefaultStartNoteInTracks       .db      #0x00
PLY_AKM_DefaultStartInstrumentInTracks .db      #0x00
PLY_AKM_DefaultStartWaitInTracks       .db      #0x00
PLY_AKM_PrimaryInstrument              .db      #0x00
PLY_AKM_SecondaryInstrument            .db      #0x00
PLY_AKM_PrimaryWait                    .db      #0x00
PLY_AKM_SecondaryWait                  .db      #0x00
PLY_AKM_FlagNoteAndEffectInCell        .db      #0x00
                                       .db      #0x00
PLY_AKM_PatternRemainingHeight         .db      #0x00
PLY_AKM_LinkerPreviousRemainingHeight  .db      #0x00
PLY_AKM_Speed                          .db      #0x00
PLY_AKM_TickCounter                    .db      #0x00
PLY_AKM_SetReg13Old                    .db      #0x00
PLY_AKM_SetReg13                       .db      #0x00
PLY_AKM_RT_ReadEffectsFlag             .db      #0x00
        
        ;RET table: db register, db value, dw code to jump to once the value is read.
        ;MUST be consistent with the RAM buffer!
.equ PLY_AKM_Registers_RetTable , PLY_AKM_ROM_Buffer + counter
        ;Reg 8.
PLY_AKM_Track1_Registers                   .db      #0x00
PLY_AKM_Track1_Volume                      .db      #0x00
PLY_AKM_Track1_VolumeRet                   .dw      #0x0000
        ;Reg 0.
PLY_AKM_Track1_SoftwarePeriodLSBRegister   .db      #0x00
PLY_AKM_Track1_SoftwarePeriodLSB           .db      #0x00
PLY_AKM_Track1_SoftwarePeriodLSBRet        .dw      #0x0000
        ;Reg 1.
PLY_AKM_Track1_SoftwarePeriodMSBRegister   .db      #0x00
PLY_AKM_Track1_SoftwarePeriodMSB           .db      #0x00
PLY_AKM_Track1_SoftwarePeriodMSBRet        .dw      #0x0000
        
        ;Reg 9.
PLY_AKM_Track2_Registers                   .db      #0x00
PLY_AKM_Track2_Volume                      .db      #0x00
PLY_AKM_Track2_VolumeRet                   .dw      #0x0000
        ;Reg 2.
PLY_AKM_Track2_SoftwarePeriodLSBRegister   .db      #0x00
PLY_AKM_Track2_SoftwarePeriodLSB           .db      #0x00
PLY_AKM_Track2_SoftwarePeriodLSBRet        .dw      #0x0000
        ;Reg 3.
PLY_AKM_Track2_SoftwarePeriodMSBRegister   .db      #0x00
PLY_AKM_Track2_SoftwarePeriodMSB           .db      #0x00
PLY_AKM_Track2_SoftwarePeriodMSBRet        .dw      #0x0000
        
        ;Reg 10.
PLY_AKM_Track3_Registers                   .db      #0x00
PLY_AKM_Track3_Volume                      .db      #0x00
PLY_AKM_Track3_VolumeRet                   .dw      #0x0000
        ;Reg 4.
PLY_AKM_Track3_SoftwarePeriodLSBRegister   .db      #0x00
PLY_AKM_Track3_SoftwarePeriodLSB           .db      #0x00
PLY_AKM_Track3_SoftwarePeriodLSBRet        .dw      #0x0000
        ;Reg 5.
PLY_AKM_Track3_SoftwarePeriodMSBRegister   .db      #0x00
PLY_AKM_Track3_SoftwarePeriodMSB           .db      #0x00
PLY_AKM_Track3_SoftwarePeriodMSBRet        .dw      #0x0000
        
       .if PLY_AKM_USE_NoiseRegister          ;CONFIG SPECIFIC
                ;Reg 6.
PLY_AKM_NoiseRegisterPlaceholder           .db      #0x00
PLY_AKM_NoiseRegister                      .db      #0x00     ;Misnomer: this is the value.
PLY_AKM_NoiseRegisterRet                   .dw      #0x0000
       .endif
        
        ;Reg 7.
PLY_AKM_MixerRegisterPlaceholder           .db      #0x00
PLY_AKM_MixerRegister                      .db      #0x00     ;Misnomer: this is the value.
       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
PLY_AKM_MixerRegisterRet                   .dw      #0x0000
                ;Reg 11.
PLY_AKM_Reg11Register                      .db      #0x00
PLY_AKM_Reg11                              .db      #0x00
PLY_AKM_Reg11Ret                           .dw      #0x0000
                ;Reg 12.
PLY_AKM_Reg12Register                      .db      #0x00
PLY_AKM_Reg12                              .db      #0x00
PLY_AKM_Reg12Ret                           .dw      #0x0000
                ;This one is a trick to send the register after R13 is managed.
PLY_AKM_Reg12Ret2                          .dw      #0x0000
       .endif
        
PLY_AKM_RegsFinalRet                       .dw      #0x0000
        
        
        ;The buffers for sound effects (if any), for each channel. They are treated apart, because they must be consecutive.
               .if PLY_AKM_MANAGE_SOUND_EFFECTS
PLY_AKM_PtSoundEffectTable                 .dw      #0x0000

PLY_AKM_Channel1_SoundEffectData           .dw      #0x0000
PLY_AKM_Channel1_SoundEffectInvertedVolume .db      #0x00
PLY_AKM_Channel1_SoundEffectCurrentStep    .db      #0x00
PLY_AKM_Channel1_SoundEffectSpeed          .db      #0x00
PLY_AKM_Channel2_SoundEffectData           .dw      #0x0000
PLY_AKM_Channel2_SoundEffectInvertedVolume .db      #0x00
PLY_AKM_Channel2_SoundEffectCurrentStep    .db      #0x00
PLY_AKM_Channel2_SoundEffectSpeed          .db      #0x00
PLY_AKM_Channel3_SoundEffectData           .dw      #0x0000
PLY_AKM_Channel3_SoundEffectInvertedVolume .db      #0x00
PLY_AKM_Channel3_SoundEffectCurrentStep    .db      #0x00
PLY_AKM_Channel3_SoundEffectSpeed          .db      #0x00
               .endif ;PLY_AKM_MANAGE_SOUND_EFFECTS
        
        
       .endif ;PLY_AKM_Rom
        
;Data block for channel 1.
       .ifeq PLY_AKM_Rom
PLY_AKM_Track1_Data:
       .else
                counterStartInTrackData = counter                    ;Duplicates the counter value to determine later the size of the track buffer.
       .endif
PLY_AKM_Track1_WaitEmptyCell:              .db      #0x00            ;How many empty cells have to be waited. 0 = none.
       .if PLY_AKM_Rom
.equ PLY_AKM_Track1_Data , PLY_AKM_Track1_WaitEmptyCell
       .endif
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
PLY_AKM_Track1_Transposition:              .db      #0x00
                       .endif ;PLY_CFG_UseTranspositions
PLY_AKM_Track1_PtStartTrack:               .dw      #0x0000            ;Points at the start of the Track to read. Does not change, unless the Track changes.
PLY_AKM_Track1_PtTrack:                    .dw      #0x0000            ;Points on the next Cell of the Track to read. Evolves.
PLY_AKM_Track1_BaseNote:                   .db      #0x00              ;Base note, such as the note played. The transposition IS included.
PLY_AKM_Track1_EscapeNote:                 .db      #0x00              ;The escape note. The transposition is NOT included.
PLY_AKM_Track1_EscapeInstrument:           .db      #0x00              ;The escape instrument.
PLY_AKM_Track1_EscapeWait:                 .db      #0x00              ;The escape wait.
PLY_AKM_Track1_PtInstrument:               .dw      #0x0000            ;Points on the Instrument, evolves.
PLY_AKM_Track1_InstrumentCurrentStep:      .db      #0x00              ;The current step on the Instrument (>=0, till it reaches the Speed).
PLY_AKM_Track1_InstrumentSpeed:            .db      #0x00              ;The Instrument speed (>=0).
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
PLY_AKM_Track1_TrackInvertedVolume:        .db      #0x00
                       .endif ;PLY_CFG_UseEffect_SetVolume
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
PLY_AKM_Track1_IsPitchUpDownUsed:          .db      #0x00               ;>0 if a Pitch Up/Down is currently in use.
PLY_AKM_Track1_TrackPitchInteger:          .dw      #0x0000             ;The integer part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track1_TrackPitchDecimal:          .db      #0x00               ;The decimal part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track1_TrackPitchSpeed:            .dw      #0x0000             ;The integer and decimal part of the Track pitch speed. Is added to the Track Pitch every frame.
                       .endif ;PLY_AKM_USE_EffectPitchUpDown
                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
PLY_AKM_Track1_IsArpeggioTableUsed:        .db      #0x00               ;>0 if an Arpeggio Table is currently in use.
PLY_AKM_Track1_PtArpeggioTable:            .dw      #0x0000             ;Point on the base of the Arpeggio table, does not evolve.
PLY_AKM_Track1_PtArpeggioOffset:           .db      #0x00               ;Increases over the Arpeggio.
PLY_AKM_Track1_ArpeggioCurrentStep:        .db      #0x00               ;The arpeggio current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track1_ArpeggioCurrentSpeed:       .db      #0x00               ;The arpeggio speed (>=0, may be changed by the Force Arpeggio Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
PLY_AKM_Track1_ArpeggioOriginalSpeed:      .db      #0x00               ;The arpeggio original speed (>=0, NEVER changes for this arpeggio).
PLY_AKM_Track1_CurrentArpeggioValue:       .db      #0x00               ;Value from the Arpeggio to add to the base note. Read even if the Arpeggio effect is deactivated.
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
PLY_AKM_Track1_IsPitchTableUsed:           .db      #0x00               ;>0 if a Pitch Table is currently in use.
PLY_AKM_Track1_PtPitchTable:               .dw      #0x0000             ;Points on the base of the Pitch table, does not evolve.
PLY_AKM_Track1_PtPitchOffset:              .db      #0x00               ;Increases over the Pitch.
PLY_AKM_Track1_PitchCurrentStep:           .db      #0x00               ;The Pitch current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track1_PitchCurrentSpeed:          .db      #0x00               ;The Pitch speed (>=0, may be changed by the Force Pitch Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
PLY_AKM_Track1_PitchOriginalSpeed:         .db      #0x00               ;The Pitch original speed (>=0, NEVER changes for this pitch).
PLY_AKM_Track1_CurrentPitchTableValue:     .dw      #0x0000             ;16 bit value from the Pitch to add to the base note. Not read if the Pitch effect is deactivated.

                       .endif ;PLY_CFG_UseEffect_PitchTable

       .ifeq PLY_AKM_Rom
PLY_AKM_Track1_Data_End:
.equ PLY_AKM_Track1_Data_Size , PLY_AKM_Track1_Data_End - PLY_AKM_Track1_Data
       .else
PLY_AKM_Track1_Data_Size = counter - counterStartInTrackData
PLY_AKM_Track1_Data_End = PLY_AKM_Track1_Data + PLY_AKM_Track1_Data_Size
       .endif

.equ PLY_AKM_Data_OffsetWaitEmptyCell                , PLY_AKM_Track1_WaitEmptyCell - PLY_AKM_Track1_Data
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetTransposition                , PLY_AKM_Track1_Transposition - PLY_AKM_Track1_Data
                       .endif ;PLY_CFG_UseTranspositions
.equ PLY_AKM_Data_OffsetPtStartTrack                  , PLY_AKM_Track1_PtStartTrack - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtTrack                       , PLY_AKM_Track1_PtTrack - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetBaseNote                      , PLY_AKM_Track1_BaseNote - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetEscapeNote                    , PLY_AKM_Track1_EscapeNote - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetEscapeInstrument              , PLY_AKM_Track1_EscapeInstrument - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetEscapeWait                    , PLY_AKM_Track1_EscapeWait - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetSecondaryInstrument           , PLY_AKM_Track1_EscapeWait - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtInstrument                  , PLY_AKM_Track1_PtInstrument - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetInstrumentCurrentStep         , PLY_AKM_Track1_InstrumentCurrentStep - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetInstrumentSpeed               , PLY_AKM_Track1_InstrumentSpeed - PLY_AKM_Track1_Data
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetTrackInvertedVolume          , PLY_AKM_Track1_TrackInvertedVolume - PLY_AKM_Track1_Data
                       .endif ;PLY_CFG_UseEffect_SetVolume
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetIsPitchUpDownUsed             , PLY_AKM_Track1_IsPitchUpDownUsed - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetTrackPitchInteger             , PLY_AKM_Track1_TrackPitchInteger - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetTrackPitchDecimal             , PLY_AKM_Track1_TrackPitchDecimal - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetTrackPitchSpeed               , PLY_AKM_Track1_TrackPitchSpeed - PLY_AKM_Track1_Data
                       .endif ;PLY_AKM_USE_EffectPitchUpDown
                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetIsArpeggioTableUsed           , PLY_AKM_Track1_IsArpeggioTableUsed - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtArpeggioTable               , PLY_AKM_Track1_PtArpeggioTable - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtArpeggioOffset              , PLY_AKM_Track1_PtArpeggioOffset - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetArpeggioCurrentStep           , PLY_AKM_Track1_ArpeggioCurrentStep - PLY_AKM_Track1_Data
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetArpeggioCurrentSpeed          , PLY_AKM_Track1_ArpeggioCurrentSpeed - PLY_AKM_Track1_Data
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
.equ PLY_AKM_Data_OffsetArpeggioOriginalSpeed         , PLY_AKM_Track1_ArpeggioOriginalSpeed - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetCurrentArpeggioValue          , PLY_AKM_Track1_CurrentArpeggioValue - PLY_AKM_Track1_Data
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetIsPitchTableUsed              , PLY_AKM_Track1_IsPitchTableUsed - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtPitchTable                  , PLY_AKM_Track1_PtPitchTable - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPtPitchOffset                 , PLY_AKM_Track1_PtPitchOffset - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetPitchCurrentStep              , PLY_AKM_Track1_PitchCurrentStep - PLY_AKM_Track1_Data
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
.equ PLY_AKM_Data_OffsetPitchCurrentSpeed             , PLY_AKM_Track1_PitchCurrentSpeed - PLY_AKM_Track1_Data
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
.equ PLY_AKM_Data_OffsetPitchOriginalSpeed            , PLY_AKM_Track1_PitchOriginalSpeed - PLY_AKM_Track1_Data
.equ PLY_AKM_Data_OffsetCurrentPitchTableValue        , PLY_AKM_Track1_CurrentPitchTableValue - PLY_AKM_Track1_Data
                       .endif ;PLY_CFG_UseEffect_PitchTable

;Data block for channel 2.
;Data block for channel 2.
       .ifeq PLY_AKM_Rom
PLY_AKM_Track2_Data:
       .else
                counterStartInTrackData = counter                    ;Duplicates the counter value to determine later the size of the track buffer.
       .endif
PLY_AKM_Track2_WaitEmptyCell:              .db      #0x00              ;How many empty cells have to be waited. 0 = none.
       .if PLY_AKM_Rom
.equ PLY_AKM_Track2_Data , PLY_AKM_Track2_WaitEmptyCell
       .endif
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
PLY_AKM_Track2_Transposition:              .db      #0x00
                       .endif ;PLY_CFG_UseTranspositions
PLY_AKM_Track2_PtStartTrack:               .dw      #0x0000            ;Points at the start of the Track to read. Does not change, unless the Track changes.
PLY_AKM_Track2_PtTrack:                    .dw      #0x0000            ;Points on the next Cell of the Track to read. Evolves.
PLY_AKM_Track2_BaseNote:                   .db      #0x00              ;Base note, such as the note played. The transposition IS included.
PLY_AKM_Track2_EscapeNote:                 .db      #0x00              ;The escape note. The transposition is NOT included.
PLY_AKM_Track2_EscapeInstrument:           .db      #0x00              ;The escape instrument.
PLY_AKM_Track2_EscapeWait:                 .db      #0x00              ;The escape wait.
PLY_AKM_Track2_PtInstrument:               .dw      #0x0000            ;Points on the Instrument, evolves.
PLY_AKM_Track2_InstrumentCurrentStep:      .db      #0x00              ;The current step on the Instrument (>=0, till it reaches the Speed).
PLY_AKM_Track2_InstrumentSpeed:            .db      #0x00              ;The Instrument speed (>=0).
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
PLY_AKM_Track2_TrackInvertedVolume:        .db      #0x00
                       .endif ;PLY_CFG_UseEffect_SetVolume
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
PLY_AKM_Track2_IsPitchUpDownUsed:          .db      #0x00               ;>0 if a Pitch Up/Down is currently in use.
PLY_AKM_Track2_TrackPitchInteger:          .dw      #0x0000             ;The integer part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track2_TrackPitchDecimal:          .db      #0x00               ;The decimal part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track2_TrackPitchSpeed:            .dw      #0x0000             ;The integer and decimal part of the Track pitch speed. Is added to the Track Pitch every frame.
                       .endif ;PLY_AKM_USE_EffectPitchUpDown
                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
PLY_AKM_Track2_IsArpeggioTableUsed:        .db      #0x00               ;>0 if an Arpeggio Table is currently in use.
PLY_AKM_Track2_PtArpeggioTable:            .dw      #0x0000             ;Point on the base of the Arpeggio table, does not evolve.
PLY_AKM_Track2_PtArpeggioOffset:           .db      #0x00               ;Increases over the Arpeggio.
PLY_AKM_Track2_ArpeggioCurrentStep:        .db      #0x00               ;The arpeggio current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track2_ArpeggioCurrentSpeed:       .db      #0x00               ;The arpeggio speed (>=0, may be changed by the Force Arpeggio Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
PLY_AKM_Track2_ArpeggioOriginalSpeed:      .db      #0x00               ;The arpeggio original speed (>=0, NEVER changes for this arpeggio).
PLY_AKM_Track2_CurrentArpeggioValue:       .db      #0x00               ;Value from the Arpeggio to add to the base note. Read even if the Arpeggio effect is deactivated.
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
PLY_AKM_Track2_IsPitchTableUsed:           .db      #0x00               ;>0 if a Pitch Table is currently in use.
PLY_AKM_Track2_PtPitchTable:               .dw      #0x0000             ;Points on the base of the Pitch table, does not evolve.
PLY_AKM_Track2_PtPitchOffset:              .db      #0x00               ;Increases over the Pitch.
PLY_AKM_Track2_PitchCurrentStep:           .db      #0x00               ;The Pitch current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track2_PitchCurrentSpeed:          .db      #0x00               ;The Pitch speed (>=0, may be changed by the Force Pitch Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
PLY_AKM_Track2_PitchOriginalSpeed:         .db      #0x00               ;The Pitch original speed (>=0, NEVER changes for this pitch).
PLY_AKM_Track2_CurrentPitchTableValue:     .dw      #0x0000             ;16 bit value from the Pitch to add to the base note. Not read if the Pitch effect is deactivated.

                       .endif ;PLY_CFG_UseEffect_PitchTable

       .ifeq PLY_AKM_Rom
PLY_AKM_Track2_Data_End:
.equ PLY_AKM_Track2_Data_Size , PLY_AKM_Track2_Data_End - PLY_AKM_Track2_Data
       .else
PLY_AKM_Track2_Data_Size = counter - counterStartInTrackData
PLY_AKM_Track2_Data_End = PLY_AKM_Track2_Data + PLY_AKM_Track2_Data_Size
       .endif

.equ PLY_AKM_Track2_WaitEmptyCell       , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetWaitEmptyCell
.equ PLY_AKM_Track2_PtTrack             , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetPtTrack
.equ PLY_AKM_Track2_PtInstrument        , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetPtInstrument
.equ PLY_AKM_Track2_EscapeNote          , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetEscapeNote
.equ PLY_AKM_Track2_EscapeInstrument    , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetEscapeInstrument
.equ PLY_AKM_Track2_EscapeWait          , PLY_AKM_Track2_Data + PLY_AKM_Data_OffsetEscapeWait

;Data block for channel 3.
       .ifeq PLY_AKM_Rom
PLY_AKM_Track3_Data:
       .else
                counterStartInTrackData = counter                    ;Duplicates the counter value to determine later the size of the track buffer.
       .endif
PLY_AKM_Track3_WaitEmptyCell:              .db      #0x00              ;How many empty cells have to be waited. 0 = none.
       .if PLY_AKM_Rom
.equ PLY_AKM_Track3_Data , PLY_AKM_Track3_WaitEmptyCell
       .endif
                       .if PLY_CFG_UseTranspositions         ;CONFIG SPECIFIC
PLY_AKM_Track3_Transposition:              .db      #0x00
                       .endif ;PLY_CFG_UseTranspositions
PLY_AKM_Track3_PtStartTrack:               .dw      #0x0000            ;Points at the start of the Track to read. Does not change, unless the Track changes.
PLY_AKM_Track3_PtTrack:                    .dw      #0x0000            ;Points on the next Cell of the Track to read. Evolves.
PLY_AKM_Track3_BaseNote:                   .db      #0x00              ;Base note, such as the note played. The transposition IS included.
PLY_AKM_Track3_EscapeNote:                 .db      #0x00              ;The escape note. The transposition is NOT included.
PLY_AKM_Track3_EscapeInstrument:           .db      #0x00              ;The escape instrument.
PLY_AKM_Track3_EscapeWait:                 .db      #0x00              ;The escape wait.
PLY_AKM_Track3_PtInstrument:               .dw      #0x0000            ;Points on the Instrument, evolves.
PLY_AKM_Track3_InstrumentCurrentStep:      .db      #0x00              ;The current step on the Instrument (>=0, till it reaches the Speed).
PLY_AKM_Track3_InstrumentSpeed:            .db      #0x00              ;The Instrument speed (>=0).
                       .if PLY_CFG_UseEffect_SetVolume        ;CONFIG SPECIFIC
PLY_AKM_Track3_TrackInvertedVolume:        .db      #0x00
                       .endif ;PLY_CFG_UseEffect_SetVolume
                       .if PLY_AKM_USE_EffectPitchUpDown        ;CONFIG SPECIFIC
PLY_AKM_Track3_IsPitchUpDownUsed:          .db      #0x00               ;>0 if a Pitch Up/Down is currently in use.
PLY_AKM_Track3_TrackPitchInteger:          .dw      #0x0000             ;The integer part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track3_TrackPitchDecimal:          .db      #0x00               ;The decimal part of the Track pitch. Evolves as the pitch goes up/down.
PLY_AKM_Track3_TrackPitchSpeed:            .dw      #0x0000             ;The integer and decimal part of the Track pitch speed. Is added to the Track Pitch every frame.
                       .endif ;PLY_AKM_USE_EffectPitchUpDown
                       .if PLY_CFG_UseEffect_ArpeggioTable        ;CONFIG SPECIFIC
PLY_AKM_Track3_IsArpeggioTableUsed:        .db      #0x00               ;>0 if an Arpeggio Table is currently in use.
PLY_AKM_Track3_PtArpeggioTable:            .dw      #0x0000             ;Point on the base of the Arpeggio table, does not evolve.
PLY_AKM_Track3_PtArpeggioOffset:           .db      #0x00               ;Increases over the Arpeggio.
PLY_AKM_Track3_ArpeggioCurrentStep:        .db      #0x00               ;The arpeggio current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForceArpeggioSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track3_ArpeggioCurrentSpeed:       .db      #0x00               ;The arpeggio speed (>=0, may be changed by the Force Arpeggio Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForceArpeggioSpeed
PLY_AKM_Track3_ArpeggioOriginalSpeed:      .db      #0x00               ;The arpeggio original speed (>=0, NEVER changes for this arpeggio).
PLY_AKM_Track3_CurrentArpeggioValue:       .db      #0x00               ;Value from the Arpeggio to add to the base note. Read even if the Arpeggio effect is deactivated.
                       .endif ;PLY_CFG_UseEffect_ArpeggioTable
                       .if PLY_CFG_UseEffect_PitchTable        ;CONFIG SPECIFIC
PLY_AKM_Track3_IsPitchTableUsed:           .db      #0x00               ;>0 if a Pitch Table is currently in use.
PLY_AKM_Track3_PtPitchTable:               .dw      #0x0000             ;Points on the base of the Pitch table, does not evolve.
PLY_AKM_Track3_PtPitchOffset:              .db      #0x00               ;Increases over the Pitch.
PLY_AKM_Track3_PitchCurrentStep:           .db      #0x00               ;The Pitch current step (>=0, increases).
                               .if PLY_CFG_UseEffect_ForcePitchTableSpeed        ;CONFIG SPECIFIC
PLY_AKM_Track3_PitchCurrentSpeed:          .db      #0x00               ;The Pitch speed (>=0, may be changed by the Force Pitch Speed effect).
                               .endif ;PLY_CFG_UseEffect_ForcePitchTableSpeed
PLY_AKM_Track3_PitchOriginalSpeed:         .db      #0x00               ;The Pitch original speed (>=0, NEVER changes for this pitch).
PLY_AKM_Track3_CurrentPitchTableValue:     .dw      #0x0000             ;16 bit value from the Pitch to add to the base note. Not read if the Pitch effect is deactivated.

                       .endif ;PLY_CFG_UseEffect_PitchTable

       .ifeq PLY_AKM_Rom
PLY_AKM_Track3_Data_End:
.equ PLY_AKM_Track3_Data_Size , PLY_AKM_Track3_Data_End - PLY_AKM_Track3_Data
       .else
PLY_AKM_Track3_Data_Size = counter - counterStartInTrackData
PLY_AKM_Track3_Data_End = PLY_AKM_Track3_Data + PLY_AKM_Track3_Data_Size
       .endif
        
        

.equ PLY_AKM_Track3_WaitEmptyCell       , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetWaitEmptyCell
.equ PLY_AKM_Track3_PtTrack             , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetPtTrack
.equ PLY_AKM_Track3_PtInstrument        , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetPtInstrument
.equ PLY_AKM_Track3_EscapeNote          , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetEscapeNote
.equ PLY_AKM_Track3_EscapeInstrument    , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetEscapeInstrument
.equ PLY_AKM_Track3_EscapeWait          , PLY_AKM_Track3_Data + PLY_AKM_Data_OffsetEscapeWait

;---------------------------------------------------------------------
;Register block for all the channels. They are "polluted" with pointers to code because all this
;is actually a RET table!
;---------------------------------------------------------------------
;DB register, DB value then DW code to jump to once the value is read.
       .ifeq PLY_AKM_Rom              ;For ROM, a table is generated.
PLY_AKM_Registers_RetTable:
PLY_AKM_Track1_Registers:
       .db 8
PLY_AKM_Track1_Volume: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 0
PLY_AKM_Track1_SoftwarePeriodLSB: .db 0
       .dw PLY_AKM_SendPsgRegister


       .db 1
PLY_AKM_Track1_SoftwarePeriodMSB: .db 0
       .dw PLY_AKM_SendPsgRegister


PLY_AKM_Track2_Registers:
       .db 9
PLY_AKM_Track2_Volume: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 2
PLY_AKM_Track2_SoftwarePeriodLSB: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 3
PLY_AKM_Track2_SoftwarePeriodMSB: .db 0
       .dw PLY_AKM_SendPsgRegister


PLY_AKM_Track3_Registers:
       .db 10
PLY_AKM_Track3_Volume: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 4
PLY_AKM_Track3_SoftwarePeriodLSB: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 5
PLY_AKM_Track3_SoftwarePeriodMSB: .db 0
       .dw PLY_AKM_SendPsgRegister

;Generic registers.
                       .if PLY_AKM_USE_NoiseRegister          ;CONFIG SPECIFIC
       .db 6
PLY_AKM_NoiseRegister: .db 0
       .dw PLY_AKM_SendPsgRegister
                       .endif ;PLY_AKM_USE_NoiseRegister

       .db 7
PLY_AKM_MixerRegister: .db 0
       .if PLY_CFG_UseHardwareSounds         ;CONFIG SPECIFIC
       .dw PLY_AKM_SendPsgRegister
        
       .db 11
PLY_AKM_Reg11: .db 0
       .dw PLY_AKM_SendPsgRegister

       .db 12
PLY_AKM_Reg12: .db 0
       .dw PLY_AKM_SendPsgRegisterR13
                ;This one is a trick to send the register after R13 is managed.
               .dw PLY_AKM_SendPsgRegisterAfterPop
       .endif ;PLY_CFG_UseHardwareSounds
       .dw PLY_AKM_SendPsgRegisterEnd

       .endif ;PLY_AKM_Rom


.equ PLY_AKM_Registers_OffsetVolume  , PLY_AKM_Track1_Volume - PLY_AKM_Track1_Registers
.equ PLY_AKM_Registers_OffsetSoftwarePeriodLSB  , PLY_AKM_Track1_SoftwarePeriodLSB - PLY_AKM_Track1_Registers
.equ PLY_AKM_Registers_OffsetSoftwarePeriodMSB  , PLY_AKM_Track1_SoftwarePeriodMSB - PLY_AKM_Track1_Registers

;The period table for the first octave only.
PLY_AKM_PeriodTable:
       .if PLY_AKM_HARDWARE_CPC + PLY_AKM_HARDWARE_ENTERPRISE
        ;PSG running to 1000000 Hz.
        .dw 3822,3608,3405,3214,3034,2863,2703,2551,2408,2273,2145,2025          ; Octave 0.
        ;dw 1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073,1012          ;12
        ;dw  956, 902, 851, 804, 758, 716, 676, 638, 602, 568, 536, 506          ;24
        ;dw  478, 451, 426, 402, 379, 358, 338, 319, 301, 284, 268, 253          ;36
        ;dw  239, 225, 213, 201, 190, 179, 169, 159, 150, 142, 134, 127          ;48
        ;dw  119, 113, 106, 100,  95,  89,  84,  80,  75,  71,  67,  63          ;60
        ;dw   60,  56,  53,  50,  47,  45,  42,  40,  38,  36,  34,  32          ;72
        ;dw   30,  28,  27,  25,  24,  22,  21,  20,  19,  18,  17,  16          ;84
        ;dw   15,  14,  13,  13,  12,  11,  11,  10,   9,   9,   8,   8          ;96
        ;dw    7,   7,   7,   6,   6,   6,   5,   5,   5,   4,   4,   4          ;108
        ;dw    4,   4,   3,   3,   3,   3,   3,   2  ;,2,   2,   2,   2          ;120 -> 127
       .endif

       .if PLY_AKM_HARDWARE_SPECTRUM + PLY_AKM_HARDWARE_MSX
        ;PSG running to 1773400 Hz.
       .dw 6778, 6398, 6039, 5700, 5380, 5078, 4793, 4524, 4270, 4030, 3804, 3591	; Octave 0.
       .endif

       .if PLY_AKM_HARDWARE_PENTAGON
        ;PSG running to 1750000 Hz.
       .dw 6689, 6314, 5959, 5625, 5309, 5011, 4730, 4464, 4214, 3977, 3754, 3543	; Octave 0.
       .endif
PLY_AKM_End:

   ;PLY_UseEnterprise_End  