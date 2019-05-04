;;;;;;;;;;;;;;;;;;;;;;;;
;;;;   Constants    ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;
                    ;;;;
PPUCTRL   = $2000   ;;;; PPU Control Register 1
PPUMASK   = $2001   ;;;; PPU Control Register 2
PPUSTATUS = $2002   ;;;; PPU Status Register
OAMADDR   = $2003   ;;;; Sprite Memory Address
;         = $2004   ;;;; Sprite Memory Data
PPUSCROLL = $2005   ;;;; Background Scroll
PPUADDR   = $2006   ;;;; PPU Memory Address
PPUDATA   = $2007   ;;;; PPU Memory Data
;         = $4000   ;;;; APU Square Wave 1 Register 1
;         = $4001   ;;;; APU Square Wave 1 Register 2
;         = $4002   ;;;; APU Square Wave 1 Register 3
;         = $4003   ;;;; APU Square Wave 1 Register 4
;         = $4004   ;;;; APU Square Wave 2 Register 1
;         = $4005   ;;;; APU Square Wave 2 Register 2
;         = $4006   ;;;; APU Square Wave 2 Register 3
;         = $4007   ;;;; APU Square Wave 2 Register 4
;         = $4008   ;;;; APU Triangle Wave Register 1
;         = $4009   ;;;; APU Triangle Wave Register 2
;         = $400A   ;;;; APU Triangle Wave Register 3
;         = $400B   ;;;; APU Triangle Wave Register 4
;         = $400C   ;;;; APU Noise Register 1
;         = $400D   ;;;; APU Noise Register 2
;         = $400E   ;;;; APU Noise Register 3
;         = $400F   ;;;; APU Noise Register 4
;         = $4010   ;;;; DMC Register 1
;         = $4011   ;;;; DMC Register 2
;         = $4012   ;;;; DMC Register 3
;         = $4013   ;;;; DMC Register 4
OAMDMA    = $4014   ;;;; DMA Access to Sprite Memory
;         = $4015   ;;;; Enable/Disable Individual Sound Channels
JOYSTICK1 = $4016   ;;;; Joystick 1
JOYSTICK2 = $4017   ;;;; Joystick 2
                    ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

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

drawing       .rs 1  ; for-loop

;-----------------------------------------------------------;
;                          Bank 0                           ;
;-----------------------------------------------------------;

  .bank 0
  .org $C000

RESET:
  sei          ; ignore IRQs
  cld          ; disable decimal mode
  ldx #$40     ; loads value 0x40 on X
  stx $4017    ; disable APU frame IRQ
  ldx #$ff     ; loads value 0xFF on X
  txs          ; Set up stack             (puts 0xFF on Stack pointer)
  inx          ; now X = 0                (x++ -> 0xFF + 1)
  stx PPUCTRL  ; disable NMI
  stx PPUMASK  ; PPUMASK - disable rendering
  stx $4010    ; disable DMC IRQs         (puts 0x00 on $4010 [part of controller/audio access ports])

  ; If the user presses Reset during vblank, the PPU may reset
  ; with the vblank flag still true.  This has about a 1 in 13
  ; chance of happening on NTSC or 2 in 9 on PAL.  Clear the
  ; flag now so the vblankwait1 loop sees an actual vblank.
  bit PPUSTATUS

  ; First of two waits for vertical blank to make sure that the
  ; PPU has stabilized
vblankwait1:
  bit PPUSTATUS     ; (gets first 2 bits of value on $2002 - PPUSTATUS)
  bpl vblankwait1   ; (branches if Negative flag is clear)

  ; We now have about 30,000 cycles to burn before the PPU stabilizes.
  ; One thing we can do with this time is put RAM in a known state.
  ; Here we fill it with $00, which matches what (say) a C compiler
  ; expects for BSS. Conveniently, X is still 0.
  txa           ; A = X, sets Z(ero) flag

clrmem:             ; Here we set everything to 0x00
  lda #$00          ; Load 0x00 on A
  sta $0000, x      ; Set $0000 + X = 0
  sta $0100, x      ; Set $0100 + X = 0
  ; We skip $0200,x on purpose. Usually, RAM page 2 is used for the
  ; display list to be copied to OAM. OAM needs to be initialized to
  ; $EF-$FF, not 0, or you'll get a bunch of garbage sprites at (0, 0).
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  lda #$FE
  sta $0200, x

  inx              ; x is now 0x01
  bne clrmem

  ; Other things you can do between vblank waits are set up audio
  ; or set up other mapper registers.

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  bit PPUSTATUS   ; Poke PPUSTATUS a bit
  bpl vblankwait2 ; Branch on result PLus (Z and N flags are 0)

  lda #%00000000  ; Reset PPU Mask
  sta PPUMASK

;;;;;;;;;;;;;;;;;;;;
; Initialize game variables
InitializeState:
  lda #$00
  sta controller   ; controller = 0
  lda #$01
  sta slide        ; slide = 2

;;;;;;;;;;;;;;;;;;;;;;
; Load game palletes
LoadPalettes:
  lda PPUSTATUS         ; read PPU status to reset the high/low latch

  ; Tell CPU where $2007 should be stored, that is, where is VRAM.
  ; VRAM is what the CPU uses to store stuff being drawn, I think.
  ; This address can go from $0000 to $3FFF.
  ; The palette for the background runs from VRAM $3F00 to $3F0F
  ; The palette for the sprites runs from $3F10 to $3F1F
  lda #$3F              ; = 0x0011 1111
  sta PPUADDR           ; write the high byte of $3F00 address
  lda #$00              ; = 0x0000 0000
  sta PPUADDR           ; write the low byte of $3F00 address

  ldx #$00              ; start loop counter at 0
  LoadPalettesLoop:
    lda palette, x        ; load data from address (palette + x)
    sta PPUDATA             ; write to PPU (tinyurl.com/NES-PPUDATA)
    inx                   ; X = X + 1
    cpx #$20              ; Compare X to hex $20, decimal 32 - copying 32 bytes
                            ; 16 bytes for background palette
                            ; 16 bytes for foreground palette
  bne LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero

HelloWorld:
  ;; Disable rendering of any kind
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

  bit PPUSTATUS         ; read PPU status to reset the high/low latch

  ; Tell CPU where $2007 should be stored, that is, where is VRAM.
  ; VRAM is what the CPU uses to store stuff being drawn, I think.
  ; This address can go from $0000 to $3FFF. Setting here to $2000
  ; for unknown reasons.
  lda #$20              ; = 0x0010 0000
  sta PPUADDR           ; write the high byte of $2000 address
  lda #$00              ; = 0x0000 0000
  sta PPUADDR           ; write the low byte of $2000 address

  lda #$20        ; Character to be used (space)
  ldx #$00        ; Start index variable at 0
  ScreenPaddingTop:
    sta PPUDATA   ; Write character to screen
    inx           ; X++
    cpx #$40      ; There are 32 sprites per row on screen
                  ; So #$20 = 1 row
                  ;    #$30 = 1½ row
                  ;    #$40 = 2 rows
    ; NOTE: On NTSC it seems to eat up the first line for some reason
  bne ScreenPaddingTop

  jsr UpdateSprites

  ; Each slide has 27 rows, 32 columns
  ; (28 * 32) = 896 bytes = 0x0380
  lda #$80
  sta counterLo
  lda #$03
  sta counterHi

  ldy #$00             ; Y will always be 0, we just need it to be initialized
                       ; to 0; so indirect index mode works in the square
                       ; bracket. That is, "lda [backgroundLo], y" works, but
                       ; simply "lda [backgroundLo]" doesn't.

  jsr PrintSlideLoop   ; Jump to subroutine PrintSlideLoop, then return here
  ;jmp InitializeState  ; Go to InitializeState
  jmp Loop

PrintSlideLoop:
  ;lda slide
  lda [slideLo], y     ; get current character (sprite)
  ;cmp #$FD             ; Compare with 0xFD (red modifier)

  sta PPUDATA          ; draw to screen (tinyurl.com/NES-PPUDATA)

  clc                  ; clear the carry bit
  lda slideLo          ;
  adc #$01             ; slideLo++
  sta slideLo          ;

  lda slideHi          ; if there is a carry (overflow)
  adc #$00             ; from the previous  slideLo++
  sta slideHi          ; then add 1 to slideHi

  ;; This basically functions as 2 nested FOR loops
  ;; for(slideHi = 0; ; slideHi++)
  ;;   for(slideLo = 0; ; slideLo++)
  lda counterLo        ; load the counter low byte
  sec                  ; set carry flag
  sbc #$01             ; subtract (with borrow) by 1
  STA counterLo        ; store the low byte of the counter
  LDA counterHi        ; load the high byte
  SBC #$00             ; sub 0, but there is a carry
  STA counterHi        ; decrement the loop counter

  LDA counterLo        ; load the low byte
  CMP #$00             ; see if it is zero, if not loop
  BNE PrintSlideLoop
  LDA counterHi
  CMP #$00             ; see if the high byte is zero, if not loop
  BNE PrintSlideLoop   ; if the loop counter isn't 0, keep copying

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
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
  rts

Loop:
  ; infinite loop to keep the game from exiting
  ; NMI will interrupt this loop to run the game
  jsr Update
  jmp Loop

;;;;;;;;;;;;;;;;;;;;;;
; Main game loop
NMI: ; Non-Maskable Interrupt (draws screen)
  pha         ; Push A to the stack
  txa
  pha         ; Push X to the stack
  tya
  pha         ; Push Y to the stack

  ;; Load graphics into PPU from the memory
  lda #$00
  sta OAMADDR   ; set the low byte $02(00) of the RAM address (tinyurl.com/NES-OAMADDR)
  lda #$02
  sta OAMDMA    ; set the high byte $(02)00 of the RAM address, start the transfer (tinyurl.com/NES-OAMDMA)

  jsr Update    ; Jump to subroutine Update (and then return here)
  ;jsr Draw      ; Jump to subroutine Draw (and then return here)

  ;; Scroll stuff
  ;; Music stuff

  pla        ; Pull Y from the stack
  tay
  pla        ; Pull X from the stack
  tax
  pla        ; Pull A from the stack
  rti        ; Return from interrupt

Draw:
  ;jsr HelloWorld   ; Jump to subroutine PrintSlideLoop (and then return here)

  ; This is the PPU clean up section, so rendering the next frame starts properly.
  lda #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ;     VPHBSINN
  ;     ||||||||
  ;     ||||||++-- Base nametable address
  ;     ||||||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
  ;     |||||+---- VRAM address increment per CPU read/write of $2007
  ;     |||||     (0: add 1, going across; 1: add 32, going down)
  ;     ||||+----- Sprite pattern table address for 8x8 sprites
  ;     ||||      (0: $0000; 1: $1000; ignored in 8x16 mode)
  ;     |||+------ Background pattern table address (0: $0000; 1: $1000)
  ;     ||+------- Sprite size (0: 8x8; 1: 8x16)
  ;     |+-------- PPU master/slave select
  ;     |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
  ;     +--------- Generate an NMI at the start of the
  ;                vertical blanking interval (0: off; 1: on)
  sta PPUCTRL      ; tinyurl.com/NES-PPUCTRL

  lda #%00011110   ; enable sprites, enable background, no clipping on left side
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
  ; * NTSC colors. PAL and Dendy swap green and red
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  bit PPUSTATUS      ; tinyurl.com/NES-PPUSTATUS
  lda #$00           ; Scroll X
  sta PPUSCROLL
  lda #$00           ; Scroll Y
  sta PPUSCROLL      ; tinyurl.com/NES-PPUSCROLL

  rts                ; Return from subroutine

UpdateSprites:
  lda #$01           ; Check if selected slide is 1
  cmp slide          ;
  beq LoadSlide1     ; If so, load slide 1

  lda #$02           ; Otherwise, check if selected slide is 2
  cmp slide          ;
  beq LoadSlide2     ; If so, load slide 2

  LoadSlide1:
    lda #01
    sta slide
    ; We need to copy more that 256 (0xFF)
    lda #LOW(slide1)     ; Get low byte of <slide1>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide1)    ; Get high byte of <slide1>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide2:
    lda #LOW(slide2)     ; Get low byte of <slide1>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide2)    ; Get high byte of <slide1>
    sta slideHi          ; Store it in <slideHi>
    rts


Update:
  jsr LatchController
  jsr PollController
  jsr ReadLeft
  jsr ReadRight
  rts

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
  ;;  Character Palletes (4-7)
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