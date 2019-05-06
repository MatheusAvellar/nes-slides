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

  clc
  ldy slide
  iny
  sty slide            ; slide++

  ;; Disable rendering
  lda #%00000000   ; hide sprites, hide background
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  jsr UpdateSprites
  jsr DrawSprites

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  ; handling this button is done
  ReadRightDone:
    rts

  RightNotPressed:
    lda #00
    sta drawing
    rts