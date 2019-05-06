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
  ; with the vblank flag still true. This has about a 1 in 13
  ; chance of happening on NTSC or 2 in 9 on PAL. Clear the
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

  lda #%00000000  ; Reset PPU Mask (and disable rendering)
  sta PPUMASK

;;;;;;;;;;;;;;;;;;;;
; Initialize game variables
InitializeState:
  lda #$00
  sta controller   ; controller = 0
  lda #$01
  sta slide        ; slide = 1

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
  ; Everything from $3F00-$3F1F should be loaded by now