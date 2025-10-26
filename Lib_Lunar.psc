ScriptName Codex:Lib_Lunar Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Lunar — Pure helpers for moon phase, cycle math, night visibility & light
;  Notes:
;   • Default lunar cycle length is 32 days; adjust if your model differs.
;   • Inputs are validated and wrapped; functions are stateless and Global.
;   • Uses Codex:Lib_Solar for day/night checks where needed.
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ══════[ Phase Classification ]═════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 0 = New, 1 = Waxing, 2 = FirstQ, 3 = WaxingGib, 4 = Full, 5 = WaningGib, 6 = LastQ, 7 = Waning
Int Function Lunar_PhaseCoarse(Int aiPhaseIndex) Global
    ; • Normalize fine phase to 0..31 using Lib_Math wrap
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, 32)  ; · 0..31

    ; • Map fine index to coarse bucket
    If idx == 0
        Return 0                                          ; · New
    ElseIf idx < 8
        Return 1                                          ; · Waxing Crescent
    ElseIf idx == 8
        Return 2                                          ; · First Quarter
    ElseIf idx < 16
        Return 3                                          ; · Waxing Gibbous
    ElseIf idx == 16
        Return 4                                          ; · Full
    ElseIf idx < 24
        Return 5                                          ; · Waning Gibbous
    ElseIf idx == 24
        Return 6                                          ; · Last Quarter
    EndIf
    Return 7                                              ; · Waning Crescent
EndFunction

; ============================================================================================================================

; ● True if the phase is increasing toward full
Bool Function Lunar_IsWaxing(Int aiPhaseIndex) Global
    ; • Normalize fine phase to 0..31 then test waxing window
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, 32)            ; · 0..31
    Return (idx > 0) && (idx < 16)                                     ; · Between new and full
EndFunction

; ============================================================================================================================

; ● 0.0..1.0 fraction of the moon that’s lit (simple symmetric model)
Float Function Lunar_Illumination01(Int aiPhaseIndex) Global
    ; • Normalize fine phase to 0..31
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, 32)            ; · 0..31

    ; • Triangular illumination rising to full at index 16 then falling
    Float f = idx / 16.0                                               ; · 0..2
    If f > 1.0
        f = 2.0 - f                                                    ; · Mirror after full
    EndIf

    ; • Clamp to 0..1 and return
    Return Codex:Lib_Math.Math_Saturate01(f)                           ; · 0..1
EndFunction

; ============================================================================================================================

; ● True if near first or last quarter
Bool Function Lunar_IsQuarter(Int aiPhaseIndex) Global
    ; • Normalize fine phase and test quarter indices
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, 32)            ; · 0..31
    Return (idx == 8) || (idx == 24)                                   ; · First or Last Quarter
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Cycle Math ]═══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Days until the next full moon (0 if today)
Int Function Lunar_DaysUntilFull(Int aiPhaseIndex, Int aiCycleLen = 32) Global
    ; • Guard cycle length and normalize current index
    If aiCycleLen < 1
        aiCycleLen = 1                                                 ; · Avoid zero/neg cycles
    EndIf
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, aiCycleLen)    ; · 0..cycle-1

    ; • Define full as midpoint and compute forward distance on the ring
    Int fullIdx = aiCycleLen / 2                                       ; · Midpoint
    Return Codex:Lib_Math.Math_WrapInt(fullIdx - idx, aiCycleLen)      ; · 0..cycle-1
EndFunction

; ============================================================================================================================

; ● Days until the next new moon (0 if today)
Int Function Lunar_DaysUntilNew(Int aiPhaseIndex, Int aiCycleLen = 32) Global
    ; • Guard cycle length and normalize current index
    If aiCycleLen < 1
        aiCycleLen = 1                                                 ; · Avoid zero/neg cycles
    EndIf
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, aiCycleLen)    ; · 0..cycle-1

    ; • New moon at index 0 → forward distance is simply −idx wrapped
    Return Codex:Lib_Math.Math_WrapInt(0 - idx, aiCycleLen)            ; · 0..cycle-1
EndFunction

; ============================================================================================================================

; ● Phase index after advancing days (wrap-safe, supports negatives)
Int Function Lunar_NextPhaseIndex(Int aiPhaseIndex, Int aiDeltaDays, Int aiCycleLen = 32) Global
    ; • Guard cycle length then add delta with wrap
    If aiCycleLen < 1
        aiCycleLen = 1                                                 ; · Avoid zero/neg cycles
    EndIf
    Return Codex:Lib_Math.Math_AddWrapInt(aiPhaseIndex, aiDeltaDays, aiCycleLen) ; · 0..cycle-1
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Night Visibility & Light ]═════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● True if moon is considered up during night hours (simple rule-of-thumb)
Bool Function Lunar_IsMoonUp(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Consider moon up whenever it is not daytime (or if daylight unknown)
    Bool isDay = Codex:Lib_Solar.Solar_IsDaytime(aiNowMOD, aiSunriseMOD, aiSunsetMOD) ; · Daylight check
    Return !isDay                                                     ; · Night or unknown → moon up
EndFunction

; ============================================================================================================================

; ● 0.0..1.0 moonlight proxy (0 if moon not up)
Float Function Lunar_Light01(Float afIllum01, Bool abMoonUp) Global
    ; • No moonlight if moon is not up
    If !abMoonUp
        Return 0.0                                                    ; · Moon below horizon proxy
    EndIf

    ; • Clamp illumination and return
    Float i = Codex:Lib_Math.Math_Saturate01(afIllum01)               ; · 0..1
    Return i
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Naming ]═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Friendly name for the current phase (e.g., “Waxing Gibbous”)
String Function Lunar_PhaseName(Int aiPhaseIndex) Global
    ; • Map coarse class to label
    Int coarse = Lunar_PhaseCoarse(aiPhaseIndex)                      ; · 0..7
    If coarse == 0
        Return "New Moon"                                             ; · 0
    ElseIf coarse == 1
        Return "Waxing Crescent"                                      ; · 1
    ElseIf coarse == 2
        Return "First Quarter"                                        ; · 2
    ElseIf coarse == 3
        Return "Waxing Gibbous"                                       ; · 3
    ElseIf coarse == 4
        Return "Full Moon"                                            ; · 4
    ElseIf coarse == 5
        Return "Waning Gibbous"                                       ; · 5
    ElseIf coarse == 6
        Return "Last Quarter"                                         ; · 6
    EndIf
    Return "Waning Crescent"                                          ; · 7 (default)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Additional Helpers ]═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Illumination percent 0..100 (integer) from fine phase index
Int Function Lunar_IlluminationPct(Int aiPhaseIndex) Global
    Float f = Lunar_Illumination01(aiPhaseIndex)                          ; · 0..1
    Int pct = (f * 100.0) as Int
    If pct < 0
        pct = 0
    ElseIf pct > 100
        pct = 100
    EndIf
    Return pct
EndFunction

; ============================================================================================================================

; ● Days until the next lunar quarter edge (FirstQ/Full/LastQ/New) for a given cycle length
Int Function Lunar_DaysUntilNextQuarter(Int aiPhaseIndex, Int aiCycleLen = 32) Global
    ; • Guard and normalize
    If aiCycleLen < 1
        aiCycleLen = 1
    EndIf
    Int idx = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex, aiCycleLen)       ; · 0..cycle-1

    ; • Quarter indices are spaced evenly at cycle/4
    Int q = aiCycleLen / 4                                                ; · Step
    ; • Next quarter boundary ≥ idx: ceil(idx/q)*q, wrapped to cycle
    Int nextQ = ((idx + q - 1) / q) * q
    nextQ = nextQ % aiCycleLen

    ; • Forward wrapped distance
    Return Codex:Lib_Math.Math_WrapInt(nextQ - idx, aiCycleLen)
EndFunction

; ============================================================================================================================

; ● True if within ±tolerance days of a target phase index (wrap-safe)
Bool Function Lunar_IsNearPhase(Int aiPhaseIndex, Int aiTargetIndex, Int aiToleranceDays, Int aiCycleLen = 32) Global
    If aiCycleLen < 1
        aiCycleLen = 1
    EndIf
    Int cur = Codex:Lib_Math.Math_WrapInt(aiPhaseIndex,  aiCycleLen)
    Int tgt = Codex:Lib_Math.Math_WrapInt(aiTargetIndex, aiCycleLen)

    ; • Nearest signed difference on ring
    Int d = Codex:Lib_Math.Math_WrapNearestDelta(cur, tgt, aiCycleLen)    ; · −half..+half−1
    If d < 0
        d = -d
    EndIf
    Return d <= Codex:Lib_Math.Math_ClampInt(aiToleranceDays, 0, aiCycleLen) ; · Within tolerance
EndFunction

; ============================================================================================================================

; ● Convenience: days until Full (alias of existing logic) with explicit cycle
Int Function Lunar_DaysUntilFull_Cycle(Int aiPhaseIndex, Int aiCycleLen = 32) Global
    Return Lunar_DaysUntilFull(aiPhaseIndex, aiCycleLen)
EndFunction

; ============================================================================================================================

; ● Convenience: days until New (alias) with explicit cycle
Int Function Lunar_DaysUntilNew_Cycle(Int aiPhaseIndex, Int aiCycleLen = 32) Global
    Return Lunar_DaysUntilNew(aiPhaseIndex, aiCycleLen)
EndFunction

; ============================================================================================================================

; ● Phase index from “days since new” (wrap-safe), mirrors NextPhaseIndex but named for clarity
Int Function Lunar_PhaseIndexFromDaysSinceNew(Int aiDaysSinceNew, Int aiCycleLen = 32) Global
    If aiCycleLen < 1
        aiCycleLen = 1
    EndIf
    Return Codex:Lib_Math.Math_WrapInt(aiDaysSinceNew, aiCycleLen)
EndFunction

; ============================================================================================================================

; ● Night moonlight 0..1 for current time: Illumination × (moon up ? 1 : 0)
Float Function Lunar_NightMoonlight01(Int aiPhaseIndex, Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    Bool up = Lunar_IsMoonUp(aiNowMOD, aiSunriseMOD, aiSunsetMOD)         ; · Night proxy
    Float illum = Lunar_Illumination01(aiPhaseIndex)                       ; · 0..1
    Return Lunar_Light01(illum, up)                                       ; · 0 if not up
EndFunction

; ============================================================================================================================

; ● Night brightness with optional atmospheric dimming (0..1), e.g., clouds/overcast attenuation
Float Function Lunar_NightBrightness01(Int aiPhaseIndex, Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD, Float afDimmer01 = 0.0) Global
    ; • Clamp dimmer (0=no dim, 1=fully dark)
    Float d = Codex:Lib_Math.Math_Saturate01(afDimmer01)
    Float ml = Lunar_NightMoonlight01(aiPhaseIndex, aiNowMOD, aiSunriseMOD, aiSunsetMOD) ; · 0..1
    Float out = ml * (1.0 - d)
    If out < 0.0
        out = 0.0
    ElseIf out > 1.0
        out = 1.0
    EndIf
    Return out
EndFunction

; ============================================================================================================================

; ● Coarse bucket → stable tag for data routing (e.g., VFX/AI switches); avoids string compares at callsites
;   0=New,1=WaxCres,2=FirstQ,3=WaxGib,4=Full,5=WanGib,6=LastQ,7=WanCres (returns an int tag 0..7)
Int Function Lunar_PhaseTag(Int aiPhaseIndex) Global
    Return Lunar_PhaseCoarse(aiPhaseIndex)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝