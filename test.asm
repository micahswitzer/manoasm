org 100
start: ; initialization
    lda ads
    sta ptr
    lda nbr
    sta ctr
    cla
lop: ; main loop
    add [ptr]
    isz ptr
    isz ctr
    bun lop
    sta sum
    hlt
ads: dw ops
ptr: dw 0
nbr: dw -0xa
ctr: dw 0
sum: dw 0
ops:
    dw 0
    dw 1
    dw 2
    dw 3
    dw 4
    dw 5
    dw 6
    dw 7
    dw 8
    dw 9

end ; is this necessary?

; identifiers
; instructions/directives (keywords)
; label
; left and right brackets
; number
