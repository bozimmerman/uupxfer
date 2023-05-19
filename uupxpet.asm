* = $1000
        ;.O
        ;.D UUPXPET.BIN
        JMP DOLOAD
        JMP DOSAVE
        JMP XFERO
        JMP XFERI
SADDR   byte $00,$60
EADDR   byte $00,$61
STATE   byte $00
NFLAG   byte $00
CHKIN = $FFC6
CHKOUT = $FFC9
CHRIN = $FFCF
CHROUT = $FFD2
STOP = $FFE1
CLRCHN = $FFCC
LERR = $96
DATADIR = $E843
DATAREG = $E841
DATAIRQ = $E84D
DATAIRS = $E84E
DATAACK = $E84C
NMIVEC = $0090
; --- DOLOAD
DOLOAD
        LDX #$08
        JSR CHKIN
        LDA SADDR
        STA _LOADAD+1
        LDA SADDR+1
        STA _LOADAD+2
_LOADLP
        JSR CHRIN
_LOADAD
        STA $6000
        LDX LERR
        BEQ _LOADCT
_LOADXT
        STX STATE
        LDA _LOADAD+1
        STA EADDR
        LDA _LOADAD+2
        STA EADDR+1
        JMP CLRCHN
_LOADCT
        INC _LOADAD+1
        BNE _LOADLP
        INC _LOADAD+2
        JMP _LOADLP
; --- DOSAVE
DOSAVE
        LDX #$08
        JSR CHKOUT
        LDA SADDR
        STA _SAVELP+1
        JSR CHROUT
        LDA SADDR+1
        STA _SAVELP+2
        JSR CHROUT
_SAVELP
        LDA $6000
        JSR CHROUT
        LDX LERR
        BEQ _SAVEC1
        JMP _LOADXT
_SAVEC1
        LDA _SAVELP+2
        CMP EADDR+1
        BCC _SAVEC2
        LDA _SAVELP+1
        CMP EADDR
        BNE _SAVEC2
        LDX #$00
        JMP _LOADXT
_SAVEC2
        INC _SAVELP+1
        BNE _SAVELP
        INC _SAVELP+2
        JMP _SAVELP
; SAVE NMI VECTOR
NMISAV
        LDA NMIVEC
        STA _NMIR1+1
        STA NNMID+1
        LDA NMIVEC+1
        STA _NMIR2+1
        STA NNMID+2
        RTS
; RESTORE SAVED NMI VECTOR
NMIRES
        SEI
_NMIR1
        LDA #$47
        STA NMIVEC
_NMIR2
        LDA #$FE
        STA NMIVEC+1
        CLI
        RTS
; SEND / CLEAR ACK OR DAT SIGNAL TO OTHER SIDE
ACKDAT
        LDA #192
        STA DATAACK
        RTS
CLRACT
        LDA #224
        STA DATAACK
        RTS
; SET UP THE LOCAL NMI
SETNMI
        SEI
        LDA #<XFNMI
        STA NMIVEC
        LDA #>XFNMI
        STA NMIVEC+1
        CLI
        RTS
XFNMI
        PHP
        PHA
        LDA DATAIRQ
        INC $8001; ******DELME
        AND #$02
        BEQ _NNMIC
        INC $8002; ******DELME
        STA DATAIRQ
        STA DATAIRS
        INC NFLAG
_NNMIC
        PLA
        PLP
NNMID
        JMP $E455
DELAY
        LDX #$00
_DELP
        NOP
        NOP
        DEX
        BNE _DELP
        RTS
; SEND THE NEXT BYTE OUT, AND SET UP IRQ FOR ACK
XOOUT
        JSR CLRACT; FIRST, CLEAR THE RETURN SIGNAL
XOADDR
        LDA $6000
        STA DATAREG; STAGE THE BYTE
        STA $8000; **** DELME
        JSR DELAY
        JSR XODUN; SEE IF THIS IS LAST BYTE
        BNE _XOOU1; IF ITS NOT, PREPARE TO RECEIVE ACK
        JSR ACKDAT; SIGNAL THE BYTE IS SENT
        JMP CLRACT
_XOOU1
        INC XOADDR+1
        BNE _XOOU2
        INC XOADDR+2; INCREASE THE POINTER
_XOOU2
        LDA #130; TURN ON FLAG IRQ
        STA DATAIRS
        JSR ACKDAT; SIGNAL THE BYTE IS SENT
        JMP CLRACT
; XFER OUT TO ANOTHER COMPUTER
XFERO
        LDA SADDR; SET UP THE ADDRESS
        STA XOADDR+1
        LDA SADDR+1
        STA XOADDR+2
        JSR NMISAV
        JSR CLRACT
        LDA #$FF; SET TO OUTPUT MODE
        STA DATADIR
        LDA #2
        STA DATAIRQ
        LDA #1
        STA STATE
        JSR SETNMI
_XFOT
        LDA #0
        STA NFLAG
        JSR CLRACT
        JSR XOOUT; SEND THE FIRST BYTES
_XFND
        LDA NFLAG
        BNE _XFOT
        LDA STATE
        BEQ _XFDUN
        JSR STOP
        BNE _XFND
_XFDUN
        JMP NMIRES
; CHECK IF END OF OUTPUT HAS BEEN REACHED
XODUN
        LDA XOADDR+2
        CMP EADDR+1
        BCC _XODUN1
        LDA XOADDR+1
        CMP EADDR
        BNE _XODUN1
        LDA #0
        STA STATE
        RTS
_XODUN1
        LDA #1
        STA STATE
        RTS
; XFER IN FROM ANOTHER COMPUTER
XFERI
        JSR NMISAV
        JSR CLRACT
        LDA #$00; SET TO INPUT MODE
        STA DATADIR
        LDA #2
        STA STATE
        LDA #2
        STA DATAIRS
        STA DATAIRQ
        JSR SETNMI
        LDA #130; DISABLEIRQ
        STA DATAIRS
        LDA #0
        STA NFLAG
        JSR DELAY
        STA DATAIRQ
        LDA #130
        STA DATAIRS
_XFILP
        LDA NFLAG
        BEQ _XFIL2
        LDA #0
        STA NFLAG
        JSR CLRACT
        JSR DELAY
        JSR XFINPUT
_XFIL2
        JSR STOP
        BNE _XFILP
_XFIDUN
        JMP NMIRES
; INPUT/RECEIVE HANDLER -- DOES EVERYTHING -- ALL IN ONE!
XFINPUT
        NOP
        JSR CLRACT; CLEAR THE RESPONSE FLAG
        LDA STATE; SEE WHAT OUR INPUT STATE IS
        BEQ _XINMI5
        DEC STATE
        BNE _XINMI3
        LDA DATAREG; INPUT STATE 1 MEAN 2ND ADDR BYTE
        BNE _XINMI4
        INC STATE
        JMP _XINMI6
_XINMI4
        STA XIADDR+2
        STA SADDR+1
        JMP _XINMI6
_XINMI3
        LDA DATAREG; INPUT STATE 2 MEAN 1ST ADDR BYTE
        STA XIADDR+1
        STA SADDR
        JMP _XINMI6
_XINMI5
        LDA DATAREG; INPUT STATE 0 - RECEIVE NORMAL DATA BYTE
XIADDR
        STA $6000
        INC XIADDR+1; INCREMENT THE ADDRESS POINTER FOR NEXT
        BNE _XINMI6
        INC XIADDR+2
_XINMI6
        LDA #130; TURN ON FLAG IRQ
        STA DATAIRQ
        JSR ACKDAT; SIGNAL THE BYTE IS RECEIVED
_XINMIO
        JMP CLRACT
PRINT
        NOP;:F$="UUPXPET.BAS":OPEN8,8,15,"S0:UUPXPET.*":SAVEF$,8:VERIFYF$,8
