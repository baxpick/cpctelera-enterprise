Change HW setting, by set the required HW to 1 in file: 
cpctelera/CPCteleraHW.src
and set the appropriate #define statement in file:
cpctelera/src/keyboard/keyboard.h 

using different Arkos players in main.c: 
#include <cpctelera.h>          for Arkos 1 player
#include <cpcteleraAkg.h>       for Arkos 2 Akg player
#include <cpcteleraAkm.h>       for Arkos 2 Akm player
#include <cpcteleraAky.h>       for Arkos 2 Aky player
#include <cpcteleraLW.h>        for Arkos 2 LW player
labels are the same, just player name should be inserted after cpct_akp for example music init for 
- Arkos1: cpct_akp_musicInit(0x6000)
- Arkos2 Akg: cpct_akpAKG_musicInit(0x6000, 0)

Player settings can be set in the following files:
cpctelera/src/audio/arkostracker*_var.src

If you use Enterprise hardware then AY emulation parameters can set in file:
cpctelera/CPCteleraHW.src

if you do not use hw envelopes then set         NO_ENVELOPE_IRQ to 1, saves CPU, and memory
if you use low frequency hw envelopes then set  NO_ENVELOPE_IRQ to 0, and do not set any    ENABLE_xxxHZ_IRQ (ENABLE_300HZ_IRQ is not implemented yet in the loader)
if you use high frequency hw envelopes then set NO_ENVELOPE_IRQ to 0, and set               ENABLE_1000HZ_IRQ , the usage of 1KHz envelope emulation is a bit tricky, 
because you have to set up a counter 20 for your code which should run in video interrupt, and has to be called in every 20th interrupt, but the music player should 
be called in each interrupt, timing is solved in the music player routine.

the following parameters are for behaviour if there is noise and tone on a AY channel in the same time:
toneAndNoiseModeAtnns   set 1 if you want to get tone frequency as noise on channel A
toneAndNoiseModeAtone   set 1 if you want to get noise frequency on channel A
toneAndNoiseModeAtoise  set 1 if you want to get tone frequency on channel A

EP file loader is start.src it can be translated by sjasm 0.39.
it is prepared for loading 3 files, 1 screen, 1 binary which is called, and after finish returns to loader, and for the final binary file.
Screen file and 1st binary can be omitted if any of them does not exist by specifying load address 0 to the file which is going to be omitted.
Load address, load length, start address, and file name has to be updated in start.src
EP version of CPCtelera is prepared to use maximum 2 video page in same time, video ram configuration can be set in the loader with appropriate vidpage variable.