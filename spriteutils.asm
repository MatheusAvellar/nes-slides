UpdateSprites:

  lda #$01           ; Check if selected slide is 1
  cmp slide          ;
  beq LoadSlide1     ; If so, load slide 1

  lda #$02           ; Otherwise, check if selected slide is 2
  cmp slide          ;
  beq LoadSlide2     ; If so, load slide 2

  lda #$03           ; Otherwise, check if selected slide is 3
  cmp slide          ;
  beq LoadSlide3     ; If so, load slide 3

  lda #$04           ; Otherwise, check if selected slide is 4
  cmp slide          ;
  beq LoadSlide4     ; If so, load slide 4

  lda #$05           ; Otherwise, check if selected slide is 5
  cmp slide          ;
  beq LoadSlide5     ; If so, load slide 5

  lda #01
  sta slide

  LoadSlide1:
    ; We need to copy more that 256 (0xFF)
    lda #LOW(slide1)     ; Get low byte of <slide1>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide1)    ; Get high byte of <slide1>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide2:
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
    ;; Generate NMI, pattern table 0
    lda #%10000000
    sta PPUCTRL
    _LoadSlide4:
    lda #LOW(slide4)     ; Get low byte of <slide4>
    sta slideLo          ; Store it in <slideLo>
    lda #HIGH(slide4)    ; Get high byte of <slide4>
    sta slideHi          ; Store it in <slideHi>
    rts

  LoadSlide5:
    ;; Generate NMI, pattern table 1
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
  ; http://nesdev.com/NESprgmn.txt recommends waiting for VBlank to end
  ; before writing a lot of data to the PPU
  lda PPUSTATUS
  bpl SpriteVBlankWait


  ;;; TEST ;;;
  lda #$00
  cmp finishedSlide
  beq DrawSlide

  sta finishedSlide


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

  ;;; TEST ;;;
  lda #$01
  sta finishedSlide

  ;; Reenable rendering
  lda #%00011110   ; enable sprites, enable background, no clipping on left side
  sta PPUMASK      ; tinyurl.com/NES-PPUMASK

  rts