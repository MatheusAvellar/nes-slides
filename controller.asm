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

ReadRight:
  lda controller
  and #%00000001       ; only look at bit 0
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq ReadRightDone    ; branch to ReadRightDone if button is NOT pressed (0)
  clc                  ; make sure the carry flag is clear

  inc slide            ; slide++

  ReadRightDone:       ; handling this button is done
    rts

ReadLeft:
  lda controller
  and #%00000010       ; only look at bit 1
; bit:     7   6   5   4   3   2   1   0
; button:  A   B  Sel Sta Up Down Left Right
  beq ReadLeftDone     ; branch to ReadLeftDone if button is NOT pressed (0)
  clc                  ; make sure the carry flag is clear

  dec slide            ; slide--

  ReadLeftDone:        ; handling this button is done
    rts