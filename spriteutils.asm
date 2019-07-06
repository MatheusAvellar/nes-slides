UpdateSprites:

  ldx slide          ; Load current slide number to X
  dex                ;
  beq LoadSlide1     ; if X - 1 == 0, load slide 1
  dex                ;
  beq LoadSlide2     ; if X - 2 == 0, load slide 2
  dex                ;
  beq LoadSlide3     ; if X - 3 == 0, load slide 3
  dex                ;
  beq LoadSlide4     ; if X - 4 == 0, load slide 4
  dex                ;
  beq LoadSlide5     ; if X - 5 == 0, load slide 5

  lda #01
  sta slide

  ; We need to copy more than 256 (0xFF), so we save both
  ; the low and the high byte of the address
  LoadSlide1:
    ;; Change to pattern table 1
    lda #%10010000
    lda #LOW(slide1)     ; Get low byte of <slide1>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide1)    ; Get high byte of <slide1>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide2:
    ;; Change to pattern table 0
    lda #%10000000
    lda #LOW(slide2)     ; Get low byte of <slide2>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide2)    ; Get high byte of <slide2>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide3:
    lda #LOW(slide3)     ; Get low byte of <slide3>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide3)    ; Get high byte of <slide3>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide4:
    ;; Change to pattern table 0
    lda #%10000000
    sta PPUCTRL
    _LoadSlide4:
    lda #LOW(slide4)     ; Get low byte of <slide4>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide4)    ; Get high byte of <slide4>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide5:
    ;; Change to pattern table 1
    lda #%10010000
    sta PPUCTRL
    jmp _LoadSlide4

  ; LoadSlide6:
  ;   ;; Generate NMI, pattern table 0
  ;   lda #%10000000
  ;   sta PPUCTRL
  ;   lda #LOW(slide6)     ; Get low byte of <slide1>
  ;   sta slideLo          ; Store it in <slideLo>
  ;   lda #HIGH(slide6)    ; Get high byte of <slide1>
  ;   sta slideHi          ; Store it in <slideHi>
  ;   rts


DrawSprites:
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

SpriteVBlankWait:
  ; nesdev.com/NESprgmn.txt recommends waiting for VBlank to end
  ; before writing a lot of data to the PPU
  lda PPUSTATUS
  bpl SpriteVBlankWait


  ; Load attributes (i.e. palettes) for the background
  ;; THANK YOU @taywee
  ;; taywee.github.io/NerdyNights/nerdynights/backgrounds.html
  lda #$23
  sta PPUADDR           ; write the high byte of $23C0 address
  lda #$C0
  sta PPUADDR           ; write the low byte of $23C0 address

  ldx #$00              ; start X at 0
LoadAttributeLoop:
  lda attribute, x      ; load data from address (attribute + the value in x)
  sta PPUDATA           ; write to PPU
  inx                   ; X++
  cpx #$40              ; if X == 8, break - copying 8 bytes
  bne LoadAttributeLoop

  lda PPUSTATUS  ; Poke PPUSTATUS again (which seems to diminish visual glitches)


  ; In theory, if the slide couldn't finish updating on the previous
  ; NMI, then we would finish updating it on this NMI
  lda #$00
  cmp finishedSlide
  beq DrawSlide
  ; If it did finish, then we set the flag to 0 again (unfinished)
  ; and start the next update
  sta finishedSlide
  ;; In retrospect, this doesn't make much sense; we only call
  ;; DrawSprites when there's user input (theoretically), so
  ;; this check should impair the updating of slides, instead of
  ;; help. HOWEVER! it does seem to help diminish visual glitches,
  ;; god knows why. So I'll leave it here for now ¯\_(ツ)_/¯


  lda #$20              ; = 0x0010 0000
  sta PPUADDR           ; write the high byte of $2000 address
  lda #$00              ; = 0x0000 0000
  sta PPUADDR           ; write the low byte of $2000 address

  lda #$20        ; Character to be used (space)
  ldx #$00        ; Start index variable at 0
  DrawScreenPaddingTop:
    sta PPUDATA   ; Write character to screen
    inx           ; X++
    cpx #$40      ; There are 32 sprites per row on screen
  bne DrawScreenPaddingTop

  ; Each slide has 27 rows, 32 columns
  ; (28 * 32) = 896 bytes = 0x0380
  lda #$80
  sta counterLo
  lda #$03
  sta counterHi

  ldy #$00             ; Y will always be 0, we just need it to be initialized
                       ; to 0; so indirect index mode works in the square
                       ; bracket. That is, "lda [slideLo], y" works, but
                       ; simply "lda [slideLo]" doesn't.
  DrawSlide:
    lda [slideLo], y     ; get current character (sprite)
    sta PPUDATA          ; draw to screen (tinyurl.com/NES-PPUDATA)

    clc                  ; clear the carry bit
    lda slideLo          ;
    adc #$01             ; slideLo++
    sta slideLo          ;

    lda slideHi          ; if there is a carry (overflow)
    adc #$00             ; from the previous op (slideLo++)
    sta slideHi          ; then add 1 to slideHi

    ;; while(<counterHi:counterLo>-- != 0)
    ;;     DrawSlide()
    ; This is decrementing from a value stored in 2 variables
    ; When the low byte requires a borrow, the high byte is decreased
    lda counterLo
    sec
    sbc #$01
    sta counterLo
    lda counterHi
    sbc #$00
    sta counterHi
    ; If both variables are 0 now, the loop is over
    lda counterLo
    cmp #$00
    bne DrawSlide
    lda counterHi
    cmp #$00
  bne DrawSlide

  ;; This wraps up that whole nonsensical slide update fallback
  lda #$01
  sta finishedSlide

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  rts