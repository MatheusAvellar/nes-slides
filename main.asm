  .include "const.asm"

;-----------------------------------------------------------;
;                       iNES Header                         ;
;-----------------------------------------------------------;
; The 16 byte iNES header gives the emulator all
; the information about the game including mapper,
; graphics mirroring, and PRG/CHR sizes.

  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;; Variables go here
  .rsset $0000 ; start variables at ram location 0 in zero page memory

controller    .rs 1  ; Controller 1 button vector
slide         .rs 1  ; Slide number

slideLo       .rs 1  ; Low byte of slide address
slideHi       .rs 1  ; High byte of slide address
counterLo     .rs 1  ; Helper variables for double
counterHi     .rs 1  ; for-loop

leftdown      .rs 1
rightdown     .rs 1

patterntable  .rs 1

;-----------------------------------------------------------;
;                          Bank 0                           ;
;-----------------------------------------------------------;

  .bank 0
  .org $C000

  .include "init.asm"

Main:
  ;; Disable rendering
  lda #%00000000   ; hide sprites, hide background
  ;     BGRsbMmG
  ;     ||||||||
  ;     |||||||+-- Greyscale (0: normal color, 1: produce a greyscale display)
  ;     ||||||+--- 1: Show background in leftmost 8 pixels of screen, 0: Hide
  ;     |||||+---- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
  ;     ||||+----- 1: Show background
  ;     |||+------ 1: Show sprites
  ;     ||+------- Emphasize red*
  ;     |+-------- Emphasize green*
  ;     +--------- Emphasize blue*
  ; * NTSC colors. PAL and Dendy swaps green and red
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  jsr UpdateSprites
  jsr DrawSprites

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  jsr LoadPatternTable0

Loop:
  ; Infinite loop to keep the game from exiting. The NMI
  ; will *interrupt* this loop and then return here
  jmp Loop

NMI:
  ; NMI stands for Non-Maskable Interrupt: The NES will
  ; trigger this function on every frame so we can (and
  ; should) update things here
  jsr LatchAndPollController
  jsr ReadLeft
  jsr ReadRight

  rti        ; Return from interrupt

  .include "spriteutils.asm"
  .include "controller.asm"

;-----------------------------------------------------------;
;                          Bank 1                           ;
;-----------------------------------------------------------;

; ".org $E000" means starting at $E000
  .bank 1
  .org $E000

palette:
  ;; Background Palletes (0-3)
  .db $30,$3F,$38,$16,  $30,$3F,$38,$16,  $30,$3F,$38,$16,  $30,$3F,$38,$16
  ;; Character Palletes (4-7)
  .db $30,$3F,$38,$16,  $30,$3F,$38,$16,  $30,$3F,$38,$16,  $30,$3F,$38,$16

  .include "slides.asm"

  .org $FFFA     ; first of the three vectors starts here
nescallback:
; ".dw" means "dataword", meaning 16 bits, or 2 bytes
; Stored in little-endian order, i.e. least significant byte first
  ; After this $FFFA + 2 = $FFFC
  .dw NMI        ; when an NMI happens (once per frame if enabled) the
                 ; processor will jump to the label NMI:
  ; After this $FFFC + 2 = $FFFE
  .dw RESET      ; when the processor first turns on or is reset, it will jump
                 ; to the label RESET:
  ; After this $FFFE + 1 = $FFFF
  .dw 0          ; external interrupt IRQ is not used


;-----------------------------------------------------------;
;                          Bank 2                           ;
;-----------------------------------------------------------;

  .bank 2
  .org $0000
  .incbin "sprite.chr"