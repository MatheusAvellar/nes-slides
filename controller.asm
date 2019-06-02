LatchAndPollController:
  LDA #$01
  STA JOYSTICK1
  LDA #$00
  STA JOYSTICK1    ; tell both the controllers to latch buttons

  ldx #$00            ; for(x = 0; x < 8; x++)
  PollControllerLoop:
    lda JOYSTICK1     ; load joystick 1
    LSR A             ; shift right
    ROL controller    ; rotate left button vector in mem location $0003
    inx
    cpx #$08          ; if x==8, break (8 buttons total)
    bne PollControllerLoop
  rts

ReadLeft:
  lda controller
  and #%00000010       ; only look at bit 1
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq LeftNotPressed   ; branch to ReadLeftDone if button is NOT pressed (0)

  lda leftdown
  cmp #01
  beq ReadLeftDone
  lda #01
  sta leftdown

  sec
  ldy slide
  dey
  sty slide            ; slide--

  ;; Disable rendering
  lda #%00000000   ; hide sprites, hide background
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  jsr UpdateSprites
  jsr DrawSprites

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  ; handling this button is done
  ReadLeftDone:
    rts

  LeftNotPressed:
    lda #00
    sta leftdown
    rts

ReadRight:
  lda controller
  and #%00000001       ; only look at bit 0
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq RightNotPressed  ; branch to RightNotPressed if button is NOT pressed (0)

  lda rightdown
  cmp #01
  beq ReadRightDone
  lda #01
  sta rightdown

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
    sta rightdown
    rts