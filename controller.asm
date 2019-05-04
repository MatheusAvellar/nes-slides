LatchController:
  LDA #$01
  STA JOYSTICK1
  LDA #$00
  STA JOYSTICK1    ; tell both the controllers to latch buttons
  rts

PollController:
  ldx #$00          ; 8 buttons total
PollControllerLoop:
  lda JOYSTICK1     ; load joystick 1
  lsr A             ; shift right
  ROL controller    ; rotate left button vector in mem location $0003
  inx
  cpx #$08
  bne PollControllerLoop
  rts

ReadLeft:
  lda controller
  and #%00000010       ; only look at bit 1
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq ReadLeftDone     ; branch to ReadLeftDone if button is NOT pressed (0)

  ; ldy #$01
  ; sty slide            ; slide = 2

  ReadLeftDone:        ; handling this button is done
    rts

ReadRight:
  lda controller
  and #%00000001       ; only look at bit 0
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq RightNotPressed  ; branch to ReadRightDone if button is NOT pressed (0)

  lda drawing
  cmp #01
  beq ReadRightDone
  lda #01
  sta drawing

  ldy slide
  iny
  sty slide            ; slide++

  jsr SpriteThing

  ; handling this button is done
  ReadRightDone:
    rts

  RightNotPressed:
    lda #00
    sta drawing
    rts

SpriteThing:
  jsr UpdateSprites

  lda #%00000000   ; hide sprites, hide background
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  bit PPUSTATUS         ; read PPU status to reset the high/low latch

  lda #$20              ; = 0x0010 0000
  sta PPUADDR           ; write the high byte of $2000 address
  lda #$00              ; = 0x0000 0000
  sta PPUADDR           ; write the low byte of $2000 address

  lda #$20        ; Character to be used (space)
  ldx #$00        ; Start index variable at 0
  ScreenPaddingTop__:
    sta PPUDATA   ; Write character to screen
    inx           ; X++
    cpx #$40      ; There are 32 sprites per row on screen
  bne ScreenPaddingTop__

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

PrintSlideLoop__:
  lda [slideLo], y     ; get current character (sprite)

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
  BNE PrintSlideLoop__
  LDA counterHi
  CMP #$00             ; see if the high byte is zero, if not loop
  BNE PrintSlideLoop__   ; if the loop counter isn't 0, keep copying

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK
  rts