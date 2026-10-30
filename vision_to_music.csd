;==========================================================
; Vision-to-Music System
;
; This Csound program receives object data from a Python
; computer vision application through Open Sound Control (OSC)
; and maps the incoming visual information to five synthesis
; instruments in real time.
;
; Start this file first, then run vision_to_music.py.
;==========================================================

<CsoundSynthesizer>
<CsOptions>
-odac -d
</CsOptions>

<CsInstruments>

; Audio engine configuration
sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

; Receive OSC messages from Python on port 7770
giHandle OSCinit 7770

; Current musical mode selected from the detected dominant color
gkMode init -1

; Lookup tables for the default scale and eight color-mapped musical modes
giFallback ftgen 0, 0, 8, -2, 0, 2, 3, 5, 7, 9, 10, 12

giMixolydian ftgen 0, 0, 8, -2, 0, 2, 4, 5, 7, 9, 10, 12
giIonian ftgen 0, 0, 8, -2, 0, 2, 4, 5, 7, 9, 11, 12
giLydian ftgen 0, 0, 8, -2, 0, 2, 4, 6, 7, 9, 11, 12
giDorian ftgen 0, 0, 8, -2, 0, 2, 3, 5, 7, 9, 10, 12
giAeolian ftgen 0, 0, 8, -2, 0, 2, 3, 5, 7, 8, 10, 12
giPhrygian ftgen 0, 0, 8, -2, 0, 1, 3, 5, 7, 8, 10, 12
giMajorPent ftgen 0, 0, 8, -2, 0, 2, 4, 7, 9, 12, 14, 16
giLocrian ftgen 0, 0, 8, -2, 0, 1, 3, 5, 6, 8, 10, 12

; Chord progression tables for the default scale
; and each color-mapped musical mode
giProg ftgen 0, 0, 4, -2, 0, 5, 3, 4

giProgMixolydian ftgen 0, 0, 4, -2, 0, 0, 6, 3
giProgIonian ftgen 0, 0, 4, -2, 0, 4, 5, 3
giProgLydian ftgen 0, 0, 4, -2, 0, 0, 1, 4
giProgDorian ftgen 0, 0, 4, -2, 0, 3, 0, 6
giProgAeolian ftgen 0, 0, 4, -2, 0, 0, 5, 2
giProgPhrygian ftgen 0, 0, 4, -2, 0, 1, 0, 6
giProgMajorPent ftgen 0, 0, 4, -2, 0, 3, 0, 4
giProgLocrian ftgen 0, 0, 4, -2, 0, 1, 0, 6

; Global effect buses
gaRevL init 0
gaRevR init 0
gaDelL init 0
gaDelR init 0

; Global variables for up to five tracked objects
; X = horizontal position
; Y = vertical position
; S = relative size
; C = dominant color
; A = object activity
gkX0 init 0.5
gkY0 init 0.5
gkS0 init 0
gkC0 init 0
gkA0 init 0

gkX1 init 0.5
gkY1 init 0.5
gkS1 init 0
gkC1 init 0
gkA1 init 0

gkX2 init 0.5
gkY2 init 0.5
gkS2 init 0
gkC2 init 0
gkA2 init 0

gkX3 init 0.5
gkY3 init 0.5
gkS3 init 0
gkC3 init 0
gkA3 init 0

gkX4 init 0.5
gkY4 init 0.5
gkS4 init 0
gkC4 init 0
gkA4 init 0

; Convert normalized Y position into pitch using the active musical mode
opcode QuantFreq, k, kk

    kY, kOct xin

    kDegree = int((1 - kY) * 7)
    kDegree limit kDegree, 0, 7

    if gkMode == 0 then
        kScale table kDegree, giMixolydian

    elseif gkMode == 1 then
        kScale table kDegree, giIonian

    elseif gkMode == 2 then
        kScale table kDegree, giLydian

    elseif gkMode == 3 then
        kScale table kDegree, giDorian

    elseif gkMode == 4 then
        kScale table kDegree, giAeolian

    elseif gkMode == 5 then
        kScale table kDegree, giPhrygian

    elseif gkMode == 6 then
        kScale table kDegree, giMajorPent

    elseif gkMode == 7 then
        kScale table kDegree, giLocrian

    else
        kScale table kDegree, giMajorPent
    endif

    kMidi = 48 + (kOct * 12) + kScale
    kFreq = cpsmidinn(kMidi)

    xout kFreq

endop

; Convert a scale degree into a semitone offset for the active mode
opcode ModeDegree, k, k

    kDegree xin

    if gkMode == 6 || gkMode == -1 then

        kIndex = kDegree % 5
        kOctave = int(kDegree / 5)

        kSemi table kIndex, giMajorPent
        kSemi = kSemi + (kOctave * 12)

    else

        kIndex = kDegree % 7
        kOctave = int(kDegree / 7)

        if gkMode == 0 then
            kSemi table kIndex, giMixolydian

        elseif gkMode == 1 then
            kSemi table kIndex, giIonian

        elseif gkMode == 2 then
            kSemi table kIndex, giLydian

        elseif gkMode == 3 then
            kSemi table kIndex, giDorian

        elseif gkMode == 4 then
            kSemi table kIndex, giAeolian

        elseif gkMode == 5 then
            kSemi table kIndex, giPhrygian

        elseif gkMode == 7 then
            kSemi table kIndex, giLocrian

        endif

        kSemi = kSemi + (kOctave * 12)

    endif

    xout kSemi

endop

; Select the chord-progression degree for the active mode and section
opcode ModeChordDegree, k, k

    kSection xin

    if gkMode == 0 then
        kDegree table kSection, giProgMixolydian

    elseif gkMode == 1 then
        kDegree table kSection, giProgIonian

    elseif gkMode == 2 then
        kDegree table kSection, giProgLydian

    elseif gkMode == 3 then
        kDegree table kSection, giProgDorian

    elseif gkMode == 4 then
        kDegree table kSection, giProgAeolian

    elseif gkMode == 5 then
        kDegree table kSection, giProgPhrygian

    elseif gkMode == 6 then
        kDegree table kSection, giProgMajorPent

    elseif gkMode == 7 then
        kDegree table kSection, giProgLocrian

    else
        kDegree table kSection, giProgMajorPent
    endif

    xout kDegree

endop

; Map object relative size to reverb and delay amount
opcode SizeFX, k, k

    kSize xin

    kSize limit kSize, 0, 1

    kMapped = limit((kSize - 0.25) / 0.50, 0, 1)

    kFXAmount = 1 - kMapped

    xout kFXAmount

endop

; Instrument 1
; Receives OSC object data and mode changes from Python
; and updates the shared global control variables.
instr 1

    kID init 0
    kX init 0.5
    kY init 0.5
    kSize init 0
    kColor init 0
    kMode init -1
    kGoneID init 0

    kTrig OSClisten giHandle, "/object", "fffff", kID, kX, kY, kSize, kColor

    kModeTrig OSClisten giHandle, "/mode", "i", kMode

    ; Release a voice when its tracked object leaves the frame
    kGoneTrig OSClisten giHandle, "/gone", "f", kGoneID

    if kModeTrig == 1 then

        gkMode = kMode

        printf "Mode received: %d\n", kModeTrig, kMode

    endif

    if kGoneTrig == 1 then

        kGoneObj = int(kGoneID)

        if kGoneObj == 0 then
            gkA0 = 0

        elseif kGoneObj == 1 then
            gkA1 = 0

        elseif kGoneObj == 2 then
            gkA2 = 0

        elseif kGoneObj == 3 then
            gkA3 = 0

        elseif kGoneObj == 4 then
            gkA4 = 0

        endif

    endif

    if kTrig == 1 then

        kObj = int(kID)

        if kObj == 0 then

            gkX0 = kX
            gkY0 = kY
            gkS0 = kSize
            gkC0 = kColor
            gkA0 = 1

        elseif kObj == 1 then

            gkX1 = kX
            gkY1 = kY
            gkS1 = kSize
            gkC1 = kColor
            gkA1 = 1

        elseif kObj == 2 then

            gkX2 = kX
            gkY2 = kY
            gkS2 = kSize
            gkC2 = kColor
            gkA2 = 1

        elseif kObj == 3 then

            gkX3 = kX
            gkY3 = kY
            gkS3 = kSize
            gkC3 = kColor
            gkA3 = 1

        elseif kObj == 4 then

            gkX4 = kX
            gkY4 = kY
            gkS4 = kSize
            gkC4 = kColor
            gkA4 = 1

        endif

    endif

endin

; Harmonic Pad
instr 10

    kX portk gkX0, 0.12
    kY portk gkY0, 0.25
    kSize portk gkS0, 0.15
    kA portk gkA0, 0.40

    kLastMode init -999
    kModeStart init 0

    kTime timeinsts

    if gkMode != kLastMode then

        kLastMode = gkMode
        kModeStart = kTime

    endif

    kModeTime = kTime - kModeStart
    kSection = int(kModeTime / 5) % 4
    kChordDegree ModeChordDegree kSection

    kBase = cpsmidinn(48)

    kRootSemi ModeDegree kChordDegree
    kThirdSemi ModeDegree kChordDegree + 2
    kFifthSemi ModeDegree kChordDegree + 4
    kSeventhSemi ModeDegree kChordDegree + 6
    kNinthSemi ModeDegree kChordDegree + 8

    kRoot = kBase * semitone(kRootSemi)
    kThird = kBase * semitone(kThirdSemi)
    kFifth = kBase * semitone(kFifthSemi)
    kSeventh = kBase * semitone(kSeventhSemi)
    kNinth = kBase * semitone(kNinthSemi)

    kVoicing = int(kY * 8)
    kVoicing limit kVoicing, 0, 7

    if kVoicing == 0 then

        kVoice1 = kRoot
        kVoice2 = kThird
        kVoice3 = kFifth
        kVoice4 = kSeventh

    elseif kVoicing == 1 then

        kVoice1 = kRoot
        kVoice2 = kFifth
        kVoice3 = kThird * 2
        kVoice4 = kSeventh

    elseif kVoicing == 2 then

        kVoice1 = kRoot
        kVoice2 = kThird
        kVoice3 = kFifth
        kVoice4 = kNinth

    elseif kVoicing == 3 then

        kVoice1 = kThird
        kVoice2 = kFifth
        kVoice3 = kSeventh
        kVoice4 = kRoot * 2

    elseif kVoicing == 4 then

        kVoice1 = kFifth
        kVoice2 = kSeventh
        kVoice3 = kRoot * 2
        kVoice4 = kThird * 2

    elseif kVoicing == 5 then

        kVoice1 = kRoot * 0.5
        kVoice2 = kFifth
        kVoice3 = kThird * 2
        kVoice4 = kSeventh * 2

    elseif kVoicing == 6 then

        kVoice1 = kRoot * 0.5
        kVoice2 = kThird
        kVoice3 = kSeventh
        kVoice4 = kNinth

    else

        kVoice1 = kRoot * 0.5
        kVoice2 = kFifth
        kVoice3 = kNinth
        kVoice4 = kThird * 2

    endif

    kAmp = kA * (0.022 + kSize * 0.10)

    kWobble oscili 0.10, 0.16
    kAmp = kAmp * (1 + kWobble)

    kDet1 oscili 0.006, 0.07
    kDet2 oscili 0.008, 0.05
    kDet3 oscili 0.005, 0.09
    kDet4 oscili 0.004, 0.035

    aVoice1 oscili kAmp, \
            kVoice1 * (1 + kDet1)

    aVoice2 oscili kAmp * 0.78, \
            kVoice2 * (1 + kDet2)

    aVoice3 oscili kAmp * 0.64, \
            kVoice3 * (1 - kDet3)

    aVoice4 oscili kAmp * 0.50, \
            kVoice4 * (1 + kDet4)

    aLowRoot oscili kAmp * 0.32, \
             kRoot * 0.5

    aOut = (aLowRoot + aVoice1 + aVoice2 + \
            aVoice3 + aVoice4) * 0.46

    kCutoff = 650 + (kSize * 3000)
    aOut moogladder aOut, kCutoff, 0.18

    kPanMove oscili 0.035, 0.06

    kPanL = limit(kX - 0.16 + kPanMove, 0, 1)
    kPanR = limit(kX + 0.16 - kPanMove, 0, 1)

    aL1, aR1 pan2 aOut * 0.65, kPanL
    aL2, aR2 pan2 aOut * 0.65, kPanR

    aL = aL1 + aL2
    aR = aR1 + aR2

    kFX SizeFX kSize

    kRevSend = 0.65 + (kFX * 0.75)

    gaRevL += aL * kRevSend
    gaRevR += aR * kRevSend

    gaDelL += aL * kFX * 0.25
    gaDelR += aR * kFX * 0.25

    outs aL * 1.0, aR * 1.0

endin

; Reverse FX
instr 11

    kX portk gkX1, 0.06
    kY portk gkY1, 0.20
    kSize portk gkS1, 0.08
    kA portk gkA1, 0.25

    kLastMode init -999
    kModeStart init 0

    kTime timeinsts

    if gkMode != kLastMode then

        kLastMode = gkMode
        kModeStart = kTime

    endif

    kModeTime = kTime - kModeStart
    kSection = int(kModeTime / 5) % 4
    kChordDegree ModeChordDegree kSection

    kBase = cpsmidinn(72)

    kRootSemi ModeDegree kChordDegree
    kThirdSemi ModeDegree kChordDegree + 2
    kFifthSemi ModeDegree kChordDegree + 4
    kSeventhSemi ModeDegree kChordDegree + 6
    kNinthSemi ModeDegree kChordDegree + 8

    kRoot = kBase * semitone(kRootSemi)
    kThird = kBase * semitone(kThirdSemi)
    kFifth = kBase * semitone(kFifthSemi)
    kSeventh = kBase * semitone(kSeventhSemi)
    kNinth = kBase * semitone(kNinthSemi)

    kAmp = kA * (0.014 + kSize * 0.072)
    kRate = 1.0 + (kSize * 2.8)

    kTrig metro kRate
    kStep init 0

    if kTrig == 1 then
        kStep = (kStep + 1) % 8
    endif

    kPattern = int(kY * 4)
    kPattern limit kPattern, 0, 3

    kPlay = 0
    kNote = kRoot
    kAccent = 0.70

    if kPattern == 0 then

        if kStep == 0 then
            kPlay = kTrig
            kNote = kRoot
            kAccent = 1.00

        elseif kStep == 1 then
            kPlay = 0

        elseif kStep == 2 then
            kPlay = kTrig
            kNote = kThird
            kAccent = 0.72

        elseif kStep == 3 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.82

        elseif kStep == 4 then
            kPlay = 0

        elseif kStep == 5 then
            kPlay = kTrig
            kNote = kSeventh
            kAccent = 0.62

        elseif kStep == 6 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.74

        elseif kStep == 7 then
            kPlay = kTrig
            kNote = kNinth
            kAccent = 0.52
        endif

    elseif kPattern == 1 then

        if kStep == 0 then
            kPlay = kTrig
            kNote = kRoot
            kAccent = 1.00

        elseif kStep == 1 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.72

        elseif kStep == 2 then
            kPlay = 0

        elseif kStep == 3 then
            kPlay = kTrig
            kNote = kThird
            kAccent = 0.84

        elseif kStep == 4 then
            kPlay = kTrig
            kNote = kNinth
            kAccent = 0.58

        elseif kStep == 5 then
            kPlay = 0

        elseif kStep == 6 then
            kPlay = kTrig
            kNote = kSeventh
            kAccent = 0.68

        elseif kStep == 7 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.52
        endif

    elseif kPattern == 2 then

        if kStep == 0 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.90

        elseif kStep == 1 then
            kPlay = 0

        elseif kStep == 2 then
            kPlay = kTrig
            kNote = kSeventh
            kAccent = 0.68

        elseif kStep == 3 then
            kPlay = kTrig
            kNote = kRoot * 2
            kAccent = 1.00

        elseif kStep == 4 then
            kPlay = 0

        elseif kStep == 5 then
            kPlay = kTrig
            kNote = kThird * 2
            kAccent = 0.72

        elseif kStep == 6 then
            kPlay = kTrig
            kNote = kNinth
            kAccent = 0.62

        elseif kStep == 7 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.48
        endif

    else

        if kStep == 0 then
            kPlay = kTrig
            kNote = kRoot
            kAccent = 1.00

        elseif kStep == 1 then
            kPlay = kTrig
            kNote = kNinth
            kAccent = 0.62

        elseif kStep == 2 then
            kPlay = 0

        elseif kStep == 3 then
            kPlay = kTrig
            kNote = kFifth
            kAccent = 0.78

        elseif kStep == 4 then
            kPlay = kTrig
            kNote = kSeventh
            kAccent = 0.66

        elseif kStep == 5 then
            kPlay = 0

        elseif kStep == 6 then
            kPlay = kTrig
            kNote = kThird * 2
            kAccent = 0.72

        elseif kStep == 7 then
            kPlay = kTrig
            kNote = kRoot * 2
            kAccent = 0.52
        endif

    endif

    kSwell triglinseg kPlay, 0, 0.42, 1, 0.09, 0
    kShimmer triglinseg kPlay, 0, 0.34, 0, 0.08, 1, 0.10, 0

    kDet1 oscili 0.0018, 0.11
    kDet2 oscili 0.0025, 0.07
    kDet3 oscili 0.0012, 0.17

    aBell1 poscil kAmp * kAccent * kSwell, \
        kNote * (1 + kDet1)

    aBell2 poscil kAmp * 0.52 * kAccent * kSwell, \
        kNote * semitone(7) * (1 - kDet2)

    aBell3 poscil kAmp * 0.34 * kAccent * kSwell, \
        kNote * semitone(12) * (1 + kDet3)

    aBell4 poscil kAmp * 0.20 * kAccent * kSwell, \
        kNote * semitone(19)

    aAir rand kAmp * 0.12 * kAccent * kShimmer
    aAir buthp aAir, 3500
    aAir butlp aAir, 9000

    aOut = aBell1 + aBell2 + aBell3 + aBell4 + aAir

    kFilterAmount = limit((kSize - 0.10) / 0.45, 0, 1)
    kFilterAmount = pow(kFilterAmount, 1.3)

    kCutoff = 1100 + (kFilterAmount * 5200)
    aOut tone aOut, kCutoff

    kPanMove1 oscili 0.08, 0.11
    kPanMove2 oscili 0.05, 0.07

    kPan1 = limit(kX + kPanMove1, 0, 1)
    kPan2 = limit(kX - kPanMove2, 0, 1)

    aL1, aR1 pan2 aOut * 0.65, kPan1
    aL2, aR2 pan2 aOut * 0.45, kPan2

    aL = aL1 + aL2
    aR = aR1 + aR2

    kFX SizeFX kSize

    kRevSend = 0.45 + (kFX * 0.90)
    kDelSend = 0.25 + (kFX * 0.50)

    gaRevL += aL * kRevSend
    gaRevR += aR * kRevSend

    gaDelL += aL * kDelSend
    gaDelR += aR * kDelSend

    outs aL * 2.3, aR * 2.3

endin

; Bass Drone
instr 12

    kX portk gkX2, 0.12
    kSize portk gkS2, 0.18
    kA portk gkA2, 0.35

    kLastMode init -999
    kModeStart init 0

    kTime timeinsts

    if gkMode != kLastMode then

        kLastMode = gkMode
        kModeStart = kTime

    endif

    kModeTime = kTime - kModeStart
    kSection = int(kModeTime / 5) % 4
    kChordDegree ModeChordDegree kSection

    kBase = cpsmidinn(36)

    kRootSemi ModeDegree kChordDegree
    kRoot = kBase * semitone(kRootSemi)

    kAmp = kA * (0.035 + kSize * 0.14)

    kMove1 oscili 0.004, 0.06
    kMove2 oscili 0.003, 0.04

    aDeepSub oscili kAmp * 0.55, kRoot * 0.5
    aSub oscili kAmp * 1.20, kRoot
    aRoot oscili kAmp * 0.85, kRoot * (1 + kMove1)

    aFifth oscili kAmp * 0.38, \
           kRoot * semitone(7) * (1 - kMove2)

    aOct oscili kAmp * 0.22, kRoot * 2.0
    aBright vco2 kAmp * 0.08, kRoot, 0

    aOut = aDeepSub + aSub + aRoot + \
           aFifth + aOct + aBright

    aOut = tanh(aOut * 1.5)
    aOut = aOut * 0.52

    kFilterAmount = limit((kSize - 0.10) / 0.45, 0, 1)
    kFilterAmount = pow(kFilterAmount, 1.5)

    kCutoff = 70 + (kFilterAmount * 5000)

    aOut moogladder aOut, kCutoff, 0.5

    aL, aR pan2 aOut, kX

    kFX SizeFX kSize

    gaRevL += aL * kFX * 0.45
    gaRevR += aR * kFX * 0.45

    gaDelL += aL * kFX * 0.18
    gaDelR += aR * kFX * 0.18

    outs aL * 1.2, aR * 1.2

endin

; FM Texture Lead
instr 13

    kX portk gkX3, 0.08
    kY portk gkY3, 0.25
    kSize portk gkS3, 0.10
    kA portk gkA3, 0.25

    kRoot QuantFreq kY, 1

    kAmp = kA * (0.024 + kSize * 0.10)

    kModDepth = 35 + (kSize * 120)

    aMod oscili kModDepth, kRoot * 0.35

    aCar poscil kAmp, kRoot + aMod
    aLayer1 poscil kAmp * 0.45, kRoot * 2
    aLayer2 poscil kAmp * 0.30, kRoot * 0.5

    aBright vco2 kAmp * 0.22, kRoot, 0

    aOut = aCar + aLayer1 + aLayer2 + aBright

    kFilterAmount = limit((kSize - 0.10) / 0.45, 0, 1)
    kFilterAmount = pow(kFilterAmount, 1.5)

    kCutoff = 120 + (kFilterAmount * 13000)

    aOut moogladder aOut, kCutoff, 0.58

    kPanMove oscili 0.08, 0.08
    kPan = limit(kX + kPanMove, 0, 1)

    aL, aR pan2 aOut, kPan

    kFX SizeFX kSize

    gaRevL += aL * kFX * 1.20
    gaRevR += aR * kFX * 1.20

    gaDelL += aL * kFX * 0.75
    gaDelR += aR * kFX * 0.75

    outs aL * 0.4, aR * 0.4

endin

; Harmonic Bell
instr 14

    kX portk gkX4, 0.08
    kY portk gkY4, 0.20
    kSize portk gkS4, 0.08
    kA portk gkA4, 0.20

    kLastMode init -999
    kModeStart init 0

    kTime timeinsts

    if gkMode != kLastMode then
        kLastMode = gkMode
        kModeStart = kTime
    endif

    kModeTime = kTime - kModeStart
    kSection = int(kModeTime / 5) % 4
    kChordDegree ModeChordDegree kSection

    kBase = cpsmidinn(72)

    kRootSemi ModeDegree kChordDegree
    kThirdSemi ModeDegree kChordDegree + 2
    kFifthSemi ModeDegree kChordDegree + 4
    kSeventhSemi ModeDegree kChordDegree + 6
    kNinthSemi ModeDegree kChordDegree + 8

    kRoot = kBase * semitone(kRootSemi)
    kThird = kBase * semitone(kThirdSemi)
    kFifth = kBase * semitone(kFifthSemi)
    kSeventh = kBase * semitone(kSeventhSemi)
    kNinth = kBase * semitone(kNinthSemi)

    kAmp = kA * (0.024 + kSize * 0.09)
    kTempo = 2.8 + (kSize * 3.2)

    kMetro metro kTempo
    kStep init 0

    if kMetro == 1 then
        kStep = (kStep + 1) % 8
    endif

    kZone = int(kY * 4)
    kZone limit kZone, 0, 3

    kPlay = 0
    kNote = kRoot
    kAccent = 0.75

    if kZone == 0 then

        if kStep == 0 then
            kPlay = kMetro
            kNote = kRoot
            kAccent = 1.00

        elseif kStep == 1 then
            kPlay = 0

        elseif kStep == 2 then
            kPlay = kMetro
            kNote = kThird
            kAccent = 0.72

        elseif kStep == 3 then
            kPlay = 0

        elseif kStep == 4 then
            kPlay = kMetro
            kNote = kRoot
            kAccent = 0.82

        elseif kStep == 5 then
            kPlay = 0

        elseif kStep == 6 then
            kPlay = kMetro
            kNote = kThird
            kAccent = 0.62

        elseif kStep == 7 then
            kPlay = 0
        endif

    elseif kZone == 1 then

        if kStep == 0 then
            kPlay = kMetro
            kNote = kRoot
            kAccent = 1.00

        elseif kStep == 1 then
            kPlay = 0

        elseif kStep == 2 then
            kPlay = kMetro
            kNote = kThird
            kAccent = 0.72

        elseif kStep == 3 then
            kPlay = kMetro
            kNote = kFifth
            kAccent = 0.82

        elseif kStep == 4 then
            kPlay = 0

        elseif kStep == 5 then
            kPlay = kMetro
            kNote = kRoot * 2
            kAccent = 0.62

        elseif kStep == 6 then
            kPlay = kMetro
            kNote = kFifth
            kAccent = 0.74

        elseif kStep == 7 then
            kPlay = 0
        endif

    elseif kZone == 2 then

        if kStep == 0 then
            kPlay = kMetro
            kNote = kThird
            kAccent = 0.88

        elseif kStep == 1 then
            kPlay = 0

        elseif kStep == 2 then
            kPlay = kMetro
            kNote = kFifth
            kAccent = 0.72

        elseif kStep == 3 then
            kPlay = kMetro
            kNote = kSeventh
            kAccent = 0.86

        elseif kStep == 4 then
            kPlay = 0

        elseif kStep == 5 then
            kPlay = kMetro
            kNote = kRoot * 2
            kAccent = 0.70

        elseif kStep == 6 then
            kPlay = kMetro
            kNote = kThird * 2
            kAccent = 0.62

        elseif kStep == 7 then
            kPlay = 0
        endif

    else

        if kStep == 0 then
            kPlay = kMetro
            kNote = kFifth
            kAccent = 0.86

        elseif kStep == 1 then
            kPlay = kMetro
            kNote = kSeventh
            kAccent = 0.72

        elseif kStep == 2 then
            kPlay = 0

        elseif kStep == 3 then
            kPlay = kMetro
            kNote = kNinth
            kAccent = 1.00

        elseif kStep == 4 then
            kPlay = kMetro
            kNote = kRoot * 2
            kAccent = 0.82

        elseif kStep == 5 then
            kPlay = 0

        elseif kStep == 6 then
            kPlay = kMetro
            kNote = kThird * 2
            kAccent = 0.70

        elseif kStep == 7 then
            kPlay = kMetro
            kNote = kNinth * 2
            kAccent = 0.55
        endif

    endif

    kAttackEnv triglinseg kPlay, 0, 0.006, 1, 0.10, 0
    kBodyEnv triglinseg kPlay, 0, 0.012, 1, 0.75, 0

    kDrift1 oscili 0.0025, 0.31
    kDrift2 oscili 0.0035, 0.23

    aFund poscil kAmp * kAccent * kBodyEnv, \
        kNote * (1 + kDrift1)

    aPartial1 poscil kAmp * 0.55 * kAccent * kBodyEnv, \
        kNote * 2.71 * (1 - kDrift2)

    aPartial2 poscil kAmp * 0.34 * kAccent * kBodyEnv, \
        kNote * 4.08

    aPartial3 poscil kAmp * 0.20 * kAccent * kBodyEnv, \
        kNote * 5.43

    aStrike rand kAmp * 0.22 * kAccent * kAttackEnv
    aStrike buthp aStrike, 3200
    aStrike butlp aStrike, 9500

    aOut = aFund + aPartial1 + aPartial2 + \
           aPartial3 + aStrike

    kFilterAmount = limit((kSize - 0.10) / 0.45, 0, 1)
    kFilterAmount = pow(kFilterAmount, 1.35)

    kCutoff = 900 + (kFilterAmount * 9000)
    aOut moogladder aOut, kCutoff, 0.28

    kDirection = 1

    if (kStep % 2) == 1 then
        kDirection = -1
    endif

    kPanMove oscili 0.10, 0.18
    kPan = limit(kX + (kPanMove * kDirection), 0, 1)

    aL, aR pan2 aOut, kPan

    kFX SizeFX kSize

    kRevSend = 0.35 + (kFX * 0.95)
    kDelSend = 0.15 + (kFX * 0.55)

    gaRevL += aL * kRevSend
    gaRevR += aR * kRevSend

    gaDelL += aL * kDelSend
    gaDelR += aR * kDelSend

    outs aL * 0.3, aR * 0.3

endin

; Global reverb and delay processing
instr 90

    aRevL, aRevR reverbsc gaRevL, gaRevR, 0.90, 10000

    aDelayL delay gaDelR, 0.32
    aDelayR delay gaDelL, 0.46

    outs (aRevL * 0.65) + (aDelayL * 0.45), \
         (aRevR * 0.65) + (aDelayR * 0.45)

    clear gaRevL, gaRevR, gaDelL, gaDelR

endin

</CsInstruments>

; Start the OSC receiver, synthesis instruments, and global effects processor.
<CsScore>

i1 0 3600

i10 0 3600   ; Harmonic Pad
i11 0 3600   ; Reverse FX
i12 0 3600   ; Bass Drone
i13 0 3600   ; FM Texture Lead
i14 0 3600   ; Harmonic Bell

i90 0 3600   ; Reverb and Delay

</CsScore>

</CsoundSynthesizer>














<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>0</width>
 <height>0</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="background">
  <r>240</r>
  <g>240</g>
  <b>240</b>
 </bgcolor>
</bsbPanel>
<bsbPresets>
</bsbPresets>
