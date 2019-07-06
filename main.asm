  .include "const.asm"

;-----------------------------------------------------------;
;                       iNES Header                         ;
;-----------------------------------------------------------;
; The 16 byte iNES header gives the emulator all
; the information about the game including mapper,
; graphics mirroring, and program/CHR sizes.

  .inesprg 1   ; 1x 16KB program code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;; Variables go here
  .rsset $0000 ; start variables at ram location 0 in zero page memory

controller    .rs 1  ; Controller 1 button vector
slide         .rs 1  ; Slide number

slideLo       .rs 1  ; Low byte of slide address
slideHi       .rs 1  ; High byte of slide address
counterLo     .rs 1  ;; Helper variables for the
counterHi     .rs 1  ;; double for-loop

leftdown      .rs 1
rightdown     .rs 1
updown        .rs 1

finishedSlide .rs 1

;-----------------------------------------------------------;
;                          Bank 0                           ;
;-----------------------------------------------------------;

  .bank 0
  .org $C000

  .include "init.asm"

Main:
  ;; Generate NMI, pattern table 1
  lda #%10010000
  ;     VPHBSINN
  ;     ||||||||
  ;     ||||||++-- Base nametable address
  ;     ||||||     (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
  ;     |||||+---- VRAM address increment per CPU read/write of PPUDATA
  ;     |||||      (0: add 1, going across; 1: add 32, going down)
  ;     ||||+----- Sprite pattern table address for 8x8 sprites
  ;     ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
  ;     |||+------ Background pattern table address (0: $0000; 1: $1000)
  ;     ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels)
  ;     |+-------- PPU master/slave select
  ;     |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
  ;     +--------- Generate an NMI at the start of the
  ;                vertical blanking interval (0: off; 1: on)
  sta PPUCTRL

  jsr UpdateSprites
  jsr DrawSprites

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
  jsr ReadUp

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
  .db $30,$3F,$21,$16,  $30,$19,$21,$16,  $30,$14,$21,$16,  $30,$21,$3F,$16
  ;; Character Palletes (4-7)
  .db $30,$3F,$21,$16,  $30,$19,$21,$16,  $30,$14,$21,$16,  $30,$21,$3F,$16
  ;$30,$3F,$21,$16

attribute:
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %10101010, %10101010, %10101010, %10101010, %10101010, %10101010, %00000000
  .db %00000000, %11111111, %11111111, %01110111, %01010101, %01010101, %01010101, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00001100, %00001111, %00001111

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