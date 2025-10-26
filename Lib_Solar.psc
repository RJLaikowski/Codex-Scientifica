ScriptName Codex:Lib_Solar Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Solar — Pure daylight & sun-position proxies derived from hub solar times
;  Notes:
;   • Inputs are minute-of-day (MOD) in 0..1439 unless noted; −1 means “not available”.
;   • Uses Codex:Lib_Time for wrap-safe windows and minute math.
;   • No side effects; safe to call from anywhere.
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ══════[ Day/Night Checks ]═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● True between sunrise and sunset (wrap-safe; false if sunrise/sunset missing)
Bool Function Solar_IsDaytime(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Validate required inputs (−1 means not available)
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return False                                     ; · Without both, we cannot claim daylight
    EndIf

    ; • Wrap-safe inclusion test on a 24h ring
    Return Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunriseMOD, aiSunsetMOD, 1440) ; · Daylight window
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Durations & Distances ]════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Minutes of daylight today (0 if sunrise/sunset missing)
Int Function Solar_DayLengthMinutes(Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Validate inputs
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return 0                                         ; · No daylight info
    EndIf

    ; • Forward span from sunrise to sunset on a 24h ring
    Int d = Codex:Lib_Math.Math_WrapInt(aiSunsetMOD - aiSunriseMOD, 1440) ; · 0..1439
    Return d
EndFunction

; ============================================================================================================================

; ● Minutes of night today (assumes 24h minus daylight; 1440 if sunrise/sunset missing)
Int Function Solar_NightLengthMinutes(Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Use daylight length and invert
    Int dayLen = Solar_DayLengthMinutes(aiSunriseMOD, aiSunsetMOD) ; · 0..1440
    Return 1440 - dayLen                                 ; · Night span
EndFunction

; ============================================================================================================================

; ● Minutes until the next sunrise (0..1439; 0 if sunrise missing)
Int Function Solar_MinutesUntilSunrise(Int aiNowMOD, Int aiSunriseMOD) Global
    ; • Validate input
    If aiSunriseMOD < 0
        Return 0                                         ; · No known sunrise
    EndIf

    ; • Forward distance on a 24h ring
    Return Codex:Lib_Math.Math_WrapInt(aiSunriseMOD - aiNowMOD, 1440)    ; · Wrap-safe
EndFunction

; ============================================================================================================================

; ● Minutes until the next sunset (0..1439; 0 if sunset missing)
Int Function Solar_MinutesUntilSunset(Int aiNowMOD, Int aiSunsetMOD) Global
    ; • Validate input
    If aiSunsetMOD < 0
        Return 0                                         ; · No known sunset
    EndIf

    ; • Forward distance on a 24h ring
    Return Codex:Lib_Math.Math_WrapInt(aiSunsetMOD - aiNowMOD, 1440)     ; · Wrap-safe
EndFunction

; ============================================================================================================================

; ● Minutes until solar noon today (0 if already past or noon missing)
Int Function Solar_TimeToNoon(Int aiNowMOD, Int aiSolarNoonMOD) Global
    ; • Validate input and clamp now to day range
    If aiSolarNoonMOD < 0
        Return 0                                         ; · No known solar noon
    EndIf
    Int nowMOD = Codex:Lib_Math.Math_ClampInt(aiNowMOD, 0, 1439)         ; · Valid MOD

    ; • If before noon, return straight difference; else zero
    If nowMOD <= aiSolarNoonMOD
        Return aiSolarNoonMOD - nowMOD                   ; · Minutes to noon
    EndIf
    Return 0                                             ; · Already past noon today
EndFunction

; ============================================================================================================================

; ● Minutes since sunrise today (clamped ≥0; 0 if sunrise missing or not yet reached)
Int Function Solar_TimeSinceSunrise(Int aiNowMOD, Int aiSunriseMOD) Global
    ; • Validate input and clamp now
    If aiSunriseMOD < 0
        Return 0                                         ; · No sunrise info
    EndIf
    Int nowMOD = Codex:Lib_Math.Math_ClampInt(aiNowMOD, 0, 1439)         ; · Valid MOD

    ; • If before sunrise, zero; else elapsed minutes
    If nowMOD < aiSunriseMOD
        Return 0                                         ; · Not reached sunrise yet
    EndIf
    Return nowMOD - aiSunriseMOD                         ; · Elapsed since sunrise
EndFunction

; ============================================================================================================================

; ● Minutes since sunset today (clamped ≥0; 0 if sunset missing or not yet reached)
Int Function Solar_TimeSinceSunset(Int aiNowMOD, Int aiSunsetMOD) Global
    ; • Validate input and clamp now
    If aiSunsetMOD < 0
        Return 0                                         ; · No sunset info
    EndIf
    Int nowMOD = Codex:Lib_Math.Math_ClampInt(aiNowMOD, 0, 1439)       ; · Valid MOD

    ; • If before sunset, zero; else elapsed minutes
    If nowMOD < aiSunsetMOD
        Return 0                                         ; · Not reached sunset yet
    EndIf
    Return nowMOD - aiSunsetMOD                          ; · Elapsed since sunset
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Day Parts / Buckets ]══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 0 = Night, 1 = Morning, 2 = Afternoon, 3 = Evening (coarse buckets)
Int Function Solar_PeriodIndex(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Night if daylight window invalid or now is outside daylight
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return 0                                         ; · Unknown daylight → Night
    EndIf
    If !Solar_IsDaytime(aiNowMOD, aiSunriseMOD, aiSunsetMOD)
        Return 0                                         ; · Outside sunrise..sunset → Night
    EndIf

    ; • Compute day length and noon point
    Int dayLen = Solar_DayLengthMinutes(aiSunriseMOD, aiSunsetMOD) ; · 0..1440
    Int noonMOD = Codex:Lib_Math.Math_AddWrapInt(aiSunriseMOD, dayLen / 2, 1440) ; · Midpoint of daylight

    ; • Very short days: treat as Morning until noon, then Evening
    If dayLen < 120
        If aiNowMOD < noonMOD
            Return 1                                     ; · Morning (first half)
        EndIf
        Return 3                                         ; · Evening (second half)
    EndIf

    ; • Standard buckets: Morning → up to noon, Afternoon → until last hour, then Evening
    Int eveningStart = Codex:Lib_Math.Math_AddWrapInt(aiSunsetMOD, -60, 1440) ; · Last ~hour of daylight
    If aiNowMOD < noonMOD
        Return 1                                         ; · Morning
    ElseIf Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, noonMOD, eveningStart, 1440)
        Return 2                                         ; · Afternoon
    EndIf
    Return 3                                             ; · Evening
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Golden / Blue Hours ]══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● True during first/last ~window minutes of daylight (“golden hour”)
Bool Function Solar_IsGoldenHour(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD, Int aiWindowMins = 45) Global
    ; • Validate inputs
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return False                                     ; · Need both sunrise and sunset
    EndIf

    ; • Conform window minutes to sensible range
    Int w = Codex:Lib_Math.Math_ClampInt(aiWindowMins, 0, 240)                ; · 0..240 minutes

    ; • Compute morning and evening golden windows
    Int morningEnd   = Codex:Lib_Math.Math_AddWrapInt(aiSunriseMOD,  w, 1440) ; · Sunrise → +w
    Int eveningStart = Codex:Lib_Math.Math_AddWrapInt(aiSunsetMOD,  -w, 1440) ; · Sunset − w → sunset

    ; • Check if now lies in either window (wrap-safe)
    Bool inMorning = Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunriseMOD, morningEnd,   1440) ; · Morning golden
    Bool inEvening = Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, eveningStart,  aiSunsetMOD, 1440) ; · Evening golden
    If inMorning
        Return True                                      ; · Within morning window
    EndIf
    If inEvening
        Return True                                      ; · Within evening window
    EndIf
    Return False                                         ; · Outside golden windows
EndFunction

; ============================================================================================================================

; ● True just before sunrise or just after sunset (“blue hour”)
Bool Function Solar_IsBlueHour(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD, Int aiWindowMins = 30) Global
    ; • Validate inputs
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return False                                     ; · Need both sunrise and sunset
    EndIf

    ; • Conform window minutes to sensible range
    Int w = Codex:Lib_Math.Math_ClampInt(aiWindowMins, 0, 180)                   ; · 0..180 minutes

    ; • Compute pre-sunrise and post-sunset blue windows
    Int preSunriseStart = Codex:Lib_Math.Math_AddWrapInt(aiSunriseMOD, -w, 1440) ; · Before sunrise
    Int postSunsetEnd   = Codex:Lib_Math.Math_AddWrapInt(aiSunsetMOD,   w, 1440) ; · After sunset

    ; • Check if now lies within either blue window (wrap-safe)
    Bool pre  = Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, preSunriseStart, aiSunriseMOD, 1440)  ; · Pre-sunrise blue
    Bool post = Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunsetMOD,     postSunsetEnd, 1440) ; · Post-sunset blue
    If pre
        Return True                                      ; · Within pre-sunrise blue hour
    EndIf
    If post
        Return True                                      ; · Within post-sunset blue hour
    EndIf
    Return False                                         ; · Outside blue windows
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Light & Elevation Proxies ]════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 0.0..1.0 proxy for sun height over the day (simple symmetric arch)
Float Function Solar_Elevation01(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Must be daytime with valid window
    If !Solar_IsDaytime(aiNowMOD, aiSunriseMOD, aiSunsetMOD)
        Return 0.0                                       ; · Night or unknown window
    EndIf

    ; • Derive fraction of daylight completed t ∈ [0..1]
    Int dayLen = Solar_DayLengthMinutes(aiSunriseMOD, aiSunsetMOD)       ; · Daylight span
    If dayLen <= 0
        Return 0.0                                       ; · Degenerate day
    EndIf
    Int sinceRise = Solar_TimeSinceSunrise(aiNowMOD, aiSunriseMOD)       ; · Elapsed since sunrise
    Float t = sinceRise / (dayLen * 1.0)                 ; · Normalize to 0..1

    ; • Symmetric triangular arch peaking at noon
    Float arch = 0.0
    If t <= 0.5
        arch = t * 2.0                                   ; · Rising half
    Else
        arch = (1.0 - t) * 2.0                           ; · Falling half
    EndIf

    ; • Clamp and return
    Return Codex:Lib_Math.Math_Saturate01(arch)          ; · 0..1
EndFunction

; ============================================================================================================================

; ● 0..~90° approximate sun height in degrees (scaled from elevation01)
Float Function Solar_ElevationDeg(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Scale normalized elevation to degrees (0..90)
    Float e = Solar_Elevation01(aiNowMOD, aiSunriseMOD, aiSunsetMOD)     ; · 0..1
    Return e * 90.0                                      ; · Degrees proxy
EndFunction

; ============================================================================================================================

; ● 0.0..1.0 perceived daylight brightness (smoothed elevation curve)
Float Function Solar_Light01(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Compute elevation-based light and apply smoothstep easing
    Float e = Solar_Elevation01(aiNowMOD, aiSunriseMOD, aiSunsetMOD)     ; · 0..1 raw elevation
    Return Codex:Lib_Math.Math_SmoothStep01(e)           ; · Smoothed brightness
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Additional Helpers ]═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Normalized daylight fraction 0..1 based on Solar rise/set (fallback to 06:00–18:00 if missing)
Float Function Solar_DaylightFrac01(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Valid window?
    If (aiSunriseMOD >= 0) && (aiSunsetMOD >= 0)
        Bool isDay = Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunriseMOD, aiSunsetMOD, 1440)  ; · Within daylight?
        If isDay
            Return Codex:Lib_Math.Math_InverseLerp01(aiSunriseMOD as Float, aiSunsetMOD as Float, aiNowMOD as Float)
        EndIf
        Return 0.0  ; · Night
    EndIf

    ; • Fallback day window (06:00–18:00)
    Bool isFallbackDay = (aiNowMOD >= 360) && (aiNowMOD <= 1080)
    If isFallbackDay
        Return Codex:Lib_Math.Math_InverseLerp01(360.0, 1080.0, aiNowMOD as Float)
    EndIf
    Return 0.0
EndFunction

; ============================================================================================================================

; ● Daylight ratio (day length / 1440) as 0.0..1.0
Float Function Solar_DaylightRatio01(Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Compute total daylight minutes and normalize
    Int dayLen = Solar_DayLengthMinutes(aiSunriseMOD, aiSunsetMOD)
    Return dayLen / 1440.0
EndFunction

; ============================================================================================================================

; ● Time (minutes) until the next solar event (rise or set) whichever is sooner
Int Function Solar_MinutesUntilNextEvent(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD) Global
    ; • Guard invalids
    If (aiSunriseMOD < 0) && (aiSunsetMOD < 0)
        Return 0                                           ; · No data
    EndIf

    Int toRise = 9999
    Int toSet  = 9999
    If aiSunriseMOD >= 0
        toRise = Codex:Lib_Math.Math_WrapInt(aiSunriseMOD - aiNowMOD, 1440)
    EndIf
    If aiSunsetMOD >= 0
        toSet  = Codex:Lib_Math.Math_WrapInt(aiSunsetMOD - aiNowMOD, 1440)
    EndIf

    ; • Pick smaller positive distance
    If toRise < toSet
        Return toRise
    EndIf
    Return toSet
EndFunction

; ============================================================================================================================

; ● Fractional “light blend” 0..1 that rises smoothly at sunrise and fades after sunset
Float Function Solar_LightBlend01(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD, Int aiBlendWindow = 60) Global
    ; • Guard inputs
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return 0.0                                         ; · No data
    EndIf
    Int w = Codex:Lib_Math.Math_ClampInt(aiBlendWindow, 0, 240)

    ; • Blend up 1h after sunrise, down 1h before sunset
    Int dawnEnd   = Codex:Lib_Math.Math_AddWrapInt(aiSunriseMOD, w, 1440)
    Int duskStart = Codex:Lib_Math.Math_AddWrapInt(aiSunsetMOD, -w, 1440)

    ; • Rising or falling transition windows
    If Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunriseMOD, dawnEnd, 1440)
        Float t = Codex:Lib_Math.Math_InverseLerp01(aiSunriseMOD as Float, dawnEnd as Float, aiNowMOD as Float)
        Return Codex:Lib_Math.Math_SmoothStep01(t)
    ElseIf Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, duskStart, aiSunsetMOD, 1440)
        Float t = Codex:Lib_Math.Math_InverseLerp01(aiSunsetMOD as Float, duskStart as Float, aiNowMOD as Float)
        Return Codex:Lib_Math.Math_SmoothStep01(1.0 - t)
    EndIf

    ; • Fully day or night
    If Solar_IsDaytime(aiNowMOD, aiSunriseMOD, aiSunsetMOD)
        Return 1.0
    EndIf
    Return 0.0
EndFunction

; ============================================================================================================================

; ● True during civil twilight (±window around sunrise/sunset)
Bool Function Solar_IsTwilight(Int aiNowMOD, Int aiSunriseMOD, Int aiSunsetMOD, Int aiWindowMins = 45) Global
    ; • Validate data
    If (aiSunriseMOD < 0) || (aiSunsetMOD < 0)
        Return False
    EndIf
    Int w = Codex:Lib_Math.Math_ClampInt(aiWindowMins, 0, 180)
    Int dawnStart = Codex:Lib_Math.Math_AddWrapInt(aiSunriseMOD, -w, 1440)
    Int duskEnd   = Codex:Lib_Math.Math_AddWrapInt(aiSunsetMOD,   w, 1440)
    Return Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, dawnStart, aiSunriseMOD, 1440) || Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiSunsetMOD, duskEnd, 1440)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝