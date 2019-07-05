LatchAndPollController:
  ; "Strobe" the joypad before read to reset it
  lda #$01
  sta JOYSTICK1
  lda #$00
  sta JOYSTICK1

  ldx #$00            ; for(x = 0; x < 8; x++)
  PollControllerLoop:
    ; Load all pressed states to the 'controller'
    ; variable by using 8 consecutive reads to $4016
    lda JOYSTICK1
    lsr A              ; shift right
    rol controller     ; 
    inx
    cpx #$08          ; if x==8, break
    bne PollControllerLoop
  rts

ReadUp:
  lda controller
  and #%00001000       ; only look at bit 1
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq UpNotPressed   ; branch to ReadLeftDone if button is NOT pressed (0)

  lda updown
  cmp #01
  beq ReadUpDone
  lda #01
  sta updown

  jsr UpdateSprites
  jsr DrawSprites

  ; handling this button is done
  ReadUpDone:
    rts

  UpNotPressed:
    lda #00
    sta updown
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

  jsr UpdateSprites
  jsr DrawSprites

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

  jsr UpdateSprites
  jsr DrawSprites

  ; handling this button is done
  ReadRightDone:
    rts

  RightNotPressed:
    lda #00
    sta rightdown
    rts