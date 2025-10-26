ScriptName Codex:Lib_Season Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Season — Pure helpers for season progress, boundaries, naming and tags
;  Notes:
;   • Four-season model: 0=Winter, 1=Spring, 2=Summer, 3=Fall.
;   • Functions are stateless, Global, and safe to call from anywhere.
;   • Day-of-year is 1..365/366; holiday mask uses bits (0..30).
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ══════[ Progress & Counts ]════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 0.0..1.0 progress through the current season
Float Function Season_Progress01(Int aiDayOfSeason, Int aiDaysInSeason) Global
    ; • Guard invalid season lengths
    If aiDaysInSeason <= 1
        Return 0.0                                       ; · Degenerate season → 0 progress
    EndIf

    ; • Conform day within 1..DaysInSeason
    Int d = Codex:Lib_Math.Math_ClampInt(aiDayOfSeason, 1, aiDaysInSeason) ; · Valid day

    ; • Map 1..N to 0..1 (inclusive ends)
    Float t = (d - 1) / (aiDaysInSeason - 1.0)           ; · Normalize range
    Return Codex:Lib_Math.Math_Saturate01(t)             ; · Clamp to 0..1
EndFunction

; ============================================================================================================================

; ● Days left in the current season
Int Function Season_DaysRemaining(Int aiDayOfSeason, Int aiDaysInSeason) Global
    ; • Conform inputs
    Int d  = Codex:Lib_Math.Math_ClampInt(aiDayOfSeason, 0, aiDaysInSeason) ; · 0..N
    Int dn = aiDaysInSeason                                               ; · Alias

    ; • Compute remainder and clamp at zero
    Int r = dn - d                                       ; · Raw remaining
    If r < 0
        r = 0                                            ; · No negatives
    EndIf
    Return r
EndFunction

; ============================================================================================================================

; ● Next season index in the cycle (0..3)
Int Function Season_NextSeasonIndex(Int aiSeasonIndex) Global
    ; • Wrap to 0..3 then advance by one and wrap again
    Int s = Codex:Lib_Math.Math_WrapInt(aiSeasonIndex, 4) ; · 0..3
    Return Codex:Lib_Math.Math_WrapInt(s + 1, 4)          ; · Next season
EndFunction

; ============================================================================================================================

; ● Days until the next season begins
Int Function Season_DaysUntilChange(Int aiDayOfSeason, Int aiDaysInSeason) Global
    ; • Reuse remaining days calculation
    Return Season_DaysRemaining(aiDayOfSeason, aiDaysInSeason) ; · 0..N
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Boundaries & Calendar ]════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● True if the season changes today
Bool Function Season_IsBoundaryToday(Int aiDaysUntilChange) Global
    ; • Boundary when no days remain
    Return (aiDaysUntilChange <= 0)                      ; · Today or overdue
EndFunction

; ============================================================================================================================

; ● True if today matches a solstice date (simple placeholder table)
Bool Function Season_IsSolsticeToday(Int aiDayOfYear) Global
    ; • Conform to plausible day-of-year bounds
    Int doy = Codex:Lib_Math.Math_ClampInt(aiDayOfYear, 1, 366) ; · 1..366

    ; • June (~172) and December (~355) solstices (adjust if your calendar differs)
    If (doy == 172) || (doy == 355)
        Return True                                      ; · Solstice hit
    EndIf
    Return False                                         ; · Not a solstice day
EndFunction

; ============================================================================================================================

; ● True if today matches an equinox date (simple placeholder table)
Bool Function Season_IsEquinoxToday(Int aiDayOfYear) Global
    ; • Conform to plausible day-of-year bounds
    Int doy = Codex:Lib_Math.Math_ClampInt(aiDayOfYear, 1, 366) ; · 1..366

    ; • March (~79) and September (~266) equinoxes (adjust if your calendar differs)
    If (doy == 79) || (doy == 266)
        Return True                                      ; · Equinox hit
    EndIf
    Return False                                         ; · Not an equinox day
EndFunction

; ============================================================================================================================

; ● True if a particular holiday bit is set
Bool Function Season_IsHolidayActive(Int aiHolidayMask, Int aiBitIndex) Global
    ; • Defer to Lib_Math’s tested bit check (no bitwise ops required)
    Return Codex:Lib_Math.Math_BitIsSet(aiHolidayMask, aiBitIndex) ; · 0..30 bits
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Classification & Names ]═══════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● “Winter”, “Spring”, “Summer”, or “Fall”
String Function Season_Name(Int aiSeasonIndex) Global
    ; • Normalize to 0..3
    Int s = Codex:Lib_Math.Math_WrapInt(aiSeasonIndex, 4)          ; · 0..3

    ; • Map index to name
    If s == 0
        Return "Winter"                                ; · 0
    ElseIf s == 1
        Return "Spring"                                ; · 1
    ElseIf s == 2
        Return "Summer"                                ; · 2
    EndIf
    Return "Fall"                                      ; · 3
EndFunction

; ============================================================================================================================

; ● True for colder seasons (Winter and Fall)
Bool Function Season_IsColdSeason(Int aiSeasonIndex) Global
    ; • Normalize then test membership
    Int s = Codex:Lib_Math.Math_WrapInt(aiSeasonIndex, 4)          ; · 0..3
    Return (s == 0) || (s == 3)                                    ; · Winter or Fall
EndFunction

; ============================================================================================================================

; ● True for warmer seasons (Spring and Summer)
Bool Function Season_IsWarmSeason(Int aiSeasonIndex) Global
    ; • Normalize then test membership
    Int s = Codex:Lib_Math.Math_WrapInt(aiSeasonIndex, 4)          ; · 0..3
    Return (s == 1) || (s == 2)                                    ; · Spring or Summer
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Additional Helpers ]═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Normalize a day-of-year to 1..DaysInYear (wrap-safe, supports 0/negatives)
Int Function Season_NormalizeDoY(Int aiDayOfYear, Int aiDaysInYear = 365) Global
    If aiDaysInYear < 1
        aiDaysInYear = 365
    EndIf
    ; Convert to 0..N-1 ring, then shift to 1..N
    Int ring = Codex:Lib_Math.Math_WrapInt(aiDayOfYear - 1, aiDaysInYear) ; · 0..N-1
    Return ring + 1
EndFunction

; ============================================================================================================================

; ● DoY window membership with wrap (inclusive start, exclusive end) on a 1..N calendar
Bool Function Season_IsWithinDoY(Int aiDoY, Int aiStartDoY, Int aiEndDoY, Int aiDaysInYear = 365) Global
    If aiDaysInYear < 1
        aiDaysInYear = 365
    EndIf
    ; Map to 0..N-1 then reuse wrap helper
    Int v = Codex:Lib_Math.Math_WrapInt(aiDoY       - 1, aiDaysInYear)
    Int s = Codex:Lib_Math.Math_WrapInt(aiStartDoY  - 1, aiDaysInYear)
    Int e = Codex:Lib_Math.Math_WrapInt(aiEndDoY    - 1, aiDaysInYear)
    ; Lib_Math interval is inclusive on both ends; emulate [start, end) by shifting end back one step.
    Int eInc = Codex:Lib_Math.Math_AddWrapInt(e, -1, aiDaysInYear)
    Return Codex:Lib_Math.Math_IsWithinWrap(v, s, eInc, aiDaysInYear)
EndFunction

; ============================================================================================================================

; ● Start/next/span for a given season index using boundary table; returns [startDoY, nextDoYWrapped, spanDays]
Int[] Function Season_StartNextSpan(Int aiSeasonIndex, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart, Int aiDaysInYear = 365) Global
    Int s = Codex:Lib_Math.Math_WrapInt(aiSeasonIndex, 4)   ; · 0..3 normalized
    Int s0 = aiSpringStart
    Int s1 = aiSummerStart
    Int s2 = aiFallStart
    Int s3 = aiWinterStart
    Int s4 = aiDaysInYear + s0                              ; · Sentinel next after Winter

    Int start = s3
    Int next  = s4

    If s == 0
        start = s0
        next  = s1
    ElseIf s == 1
        start = s1
        next  = s2
    ElseIf s == 2
        start = s2
        next  = s3
    Else
        start = s3
        next  = s4
    EndIf

    Int span = next - start                                 ; · Length of the season

    ; • Build return array: [start, nextWrapped, span]
    Int[] out = new Int[3]
    out[0] = start

    ; • Wrap Winter’s next boundary back into 1..DaysInYear
    If next > aiDaysInYear
        out[1] = next - aiDaysInYear
    Else
        out[1] = next
    EndIf

    out[2] = span
    Return out
EndFunction

; ============================================================================================================================

; ● Season index from DoY and boundary table (0=Spring,1=Summer,2=Fall,3=Winter)
Int Function Season_IndexFromDoY(Int aiDoY, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart) Global
    Int doy = Season_NormalizeDoY(aiDoY)
    Int s0 = aiSpringStart
    Int s1 = aiSummerStart
    Int s2 = aiFallStart
    Int s3 = aiWinterStart
    If (doy >= s0) && (doy < s1)
        Return 0
    ElseIf (doy >= s1) && (doy < s2)
        Return 1
    ElseIf (doy >= s2) && (doy < s3)
        Return 2
    EndIf
    Return 3 ; Winter (wrap segment)
EndFunction

; ============================================================================================================================

; ● Derive [seasonIndex, dayOfSeason(1..), daysInSeason] straight from DoY + boundaries
Int[] Function Season_RecomputeFromDoY(Int aiDoY, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart, Int aiDaysInYear = 365) Global
    Int doy  = Season_NormalizeDoY(aiDoY, aiDaysInYear)
    Int idx  = Season_IndexFromDoY(doy, aiSpringStart, aiSummerStart, aiFallStart, aiWinterStart)

    Int[] b  = Season_StartNextSpan(idx, aiSpringStart, aiSummerStart, aiFallStart, aiWinterStart, aiDaysInYear)
    Int start = b[0]
    Int next  = b[1]
    Int span  = b[2]

    ; dayOfSeason: if Winter and doy < start, wrap from year end
    Int dos = doy - start
    If dos < 0
        dos = doy + (aiDaysInYear - start)
    EndIf
    dos = dos + 1 ; 1-based

    Int[] out = new Int[3]
    out[0] = idx
    out[1] = dos
    out[2] = span
    Return out
EndFunction

; ============================================================================================================================

; ● Season progress 0..1 directly from DoY + boundaries (no precomputed counters needed)
Float Function Season_Progress01_FromDoY(Int aiDoY, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart, Int aiDaysInYear = 365) Global
    Int[] t = Season_RecomputeFromDoY(aiDoY, aiSpringStart, aiSummerStart, aiFallStart, aiWinterStart, aiDaysInYear)
    Return Season_Progress01(t[1], t[2])
EndFunction

; ============================================================================================================================

; ● Days until next season boundary from DoY + boundaries (wrap-safe)
Int Function Season_DaysUntilChange_FromDoY(Int aiDoY, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart, Int aiDaysInYear = 365) Global
    Int[] t = Season_RecomputeFromDoY(aiDoY, aiSpringStart, aiSummerStart, aiFallStart, aiWinterStart, aiDaysInYear)
    Return Season_DaysRemaining(t[1], t[2])
EndFunction

; ============================================================================================================================

; ● Next season index from DoY + boundaries (shortcut)
Int Function Season_NextIndex_FromDoY(Int aiDoY, Int aiSpringStart, Int aiSummerStart, Int aiFallStart, Int aiWinterStart) Global
    Int cur = Season_IndexFromDoY(aiDoY, aiSpringStart, aiSummerStart, aiFallStart, aiWinterStart)
    Return Season_NextSeasonIndex(cur)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝