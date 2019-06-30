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

DrawSprites:
;  bit PPUSTATUS         ; read PPU status to reset the high/low latch
vwait:
  ; http://nesdev.com/NESprgmn.txt recommends waiting for VBlank to end
  ; before writing a lot of data to 
  lda PPUSTATUS
  bpl vwait

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
  rts