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
ads: dat ops
ptr: dat 0
nbr: dat -0xa
ctr: dat 0
sum: dat 0
ops:
    dat 0
    dat 1
    dat 2
    dat 3
    dat 4
    dat 5
    dat 6
    dat 7
    dat 8
    dat 9

end ; is this necessary?

; identifiers
; instructions/directives (keywords)
; label
; left and right brackets
; number
