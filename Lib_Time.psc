ScriptName Codex:Lib_Time Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Time — Pure helpers derived from Central API Hub time/calendar signals
;  Notes:
;   • All functions are stateless, Global, and safe to call from anywhere.
;   • Minute-of-day (MOD) is 0..1439; hour is 0..23; minute is 0..59.
;   • “Wrap-safe” means windows and deltas correctly handle crossing midnight.
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ══════[ Progress Scalars ]═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 0.0..1.0 progress through the current hour
Float Function Time_HourProgress01(Int aiMinute) Global
    ; • Clamp inputs and compute normalized fraction
    Int m = Codex:Lib_Math.Math_ClampInt(aiMinute, 0, 59)            ; · Valid minute 0..59
    Float t = m / 59.0                                               ; · Normalize to 0..1
    Return Codex:Lib_Math.Math_Saturate01(t)                         ; · Safety clamp
EndFunction

; ============================================================================================================================

; ● 0.0..1.0 progress through the current day
Float Function Time_DayProgress01(Int aiMinuteOfDay) Global
    ; • Clamp inputs and compute normalized fraction
    Int mod = Codex:Lib_Math.Math_ClampInt(aiMinuteOfDay, 0, 1439)   ; · Valid MOD 0..1439
    Float t = mod / 1439.0                                           ; · Normalize to 0..1
    Return Codex:Lib_Math.Math_Saturate01(t)                         ; · Safety clamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Remaining Time Left ]══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Minutes remaining until the next top-of-hour
Int Function Time_MinutesLeftInHour(Int aiHour, Int aiMinute) Global
    ; • Clamp and subtract from last minute of hour
    Int m = Codex:Lib_Math.Math_ClampInt(aiMinute, 0, 59)            ; · Valid minute 0..59
    Return 59 - m                                                    ; · Remaining minutes
EndFunction

; ============================================================================================================================

; ● Minutes remaining until midnight (24:00)
Int Function Time_MinutesLeftInDay(Int aiMinuteOfDay) Global
    ; • Clamp and subtract from last minute of day
    Int mod = Codex:Lib_Math.Math_ClampInt(aiMinuteOfDay, 0, 1439)   ; · Valid MOD 0..1439
    Return 1439 - mod                                                ; · Remaining minutes
EndFunction

; ============================================================================================================================

; ● Seconds remaining in the current hour
Int Function Time_SecondsLeftInHour(Int aiHour, Int aiMinute) Global
    ; • Reuse minute math and scale to seconds
    Return Time_MinutesLeftInHour(aiHour, aiMinute) * 60             ; · Minutes × 60
EndFunction

; ============================================================================================================================

; ● Seconds remaining in the current day
Int Function Time_SecondsLeftInDay(Int aiMinuteOfDay) Global
    ; • Reuse minute math and scale to seconds
    Return Time_MinutesLeftInDay(aiMinuteOfDay) * 60                 ; · Minutes × 60
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Windows & Deltas ]═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Forward minutes from now to a target minute-of-day (wrap-safe)
Int Function Time_MinutesUntilMOD(Int aiNowMOD, Int aiTargetMOD) Global
    ; • Use wrap-int on the difference to get forward distance (0..1439)
    Int d = Codex:Lib_Math.Math_WrapInt(aiTargetMOD - aiNowMOD, 1440) ; · Forward distance
    Return d
EndFunction

; ============================================================================================================================

; ● Shortest signed minute difference on a 24h loop (−720..+719)
Int Function Time_WrapDeltaMOD(Int aiFromMOD, Int aiToMOD) Global
    ; • Use ring delta helper for nearest signed difference
    Return Codex:Lib_Math.Math_WrapNearestDelta(aiFromMOD, aiToMOD, 1440) ; · Nearest path
EndFunction

; ============================================================================================================================

; ● True if now lies within [start..end] on a 24h loop (wrap-safe)
Bool Function Time_IsWithinMOD(Int aiNowMOD, Int aiStartMOD, Int aiEndMOD) Global
    ; • Delegate to wrap-safe interval test
    Return Codex:Lib_Math.Math_IsWithinWrap(aiNowMOD, aiStartMOD, aiEndMOD, 1440) ; · Interval check
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Hour Boundaries ]══════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Minute-of-day for the next top-of-hour (always ahead, wraps at 24:00)
Int Function Time_NextHourBoundaryMOD(Int aiNowMOD) Global
    ; • Compute minutes until next hour and add with wrap
    Int modNow = Codex:Lib_Math.Math_ClampInt(aiNowMOD, 0, 1439)      ; · Valid MOD
    Int minuteInHour = modNow % 60                                    ; · 0..59
    Int delta = 60 - minuteInHour                                     ; · 1..60 (60 means at :00 → +60)
    Return Codex:Lib_Math.Math_AddWrapInt(modNow, delta, 1440)        ; · Next boundary MOD
EndFunction

; ============================================================================================================================

; ● Minute-of-day for the previous top-of-hour (at or before now)
Int Function Time_PrevHourBoundaryMOD(Int aiNowMOD) Global
    ; • Subtract current minute-in-hour and wrap
    Int modNow = Codex:Lib_Math.Math_ClampInt(aiNowMOD, 0, 1439)       ; · Valid MOD
    Int minuteInHour = modNow % 60                                     ; · 0..59
    Return Codex:Lib_Math.Math_AddWrapInt(modNow, -minuteInHour, 1440) ; · Previous boundary MOD
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Arithmetic & Wrap ]════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Minute-of-day after adding minutes (wrap-safe, supports negatives)
Int Function Time_AddMinutesMOD(Int aiBaseMOD, Int aiDeltaMins) Global
    ; • Clamp base and delegate to add+wrap
    Int base = Codex:Lib_Math.Math_ClampInt(aiBaseMOD, 0, 1439)       ; · Valid MOD
    Return Codex:Lib_Math.Math_AddWrapInt(base, aiDeltaMins, 1440)    ; · Wrapped sum
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Formatting Aids ]══════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● “HH:MM” string for UI or logs (zero-padded, 24-hour)
String Function Time_FormatHHMM(Int aiHour, Int aiMinute) Global
    ; • Clamp inputs to valid ranges
    Int hVal = Codex:Lib_Math.Math_ClampInt(aiHour,   0, 23)          ; · Valid hour
    Int mVal = Codex:Lib_Math.Math_ClampInt(aiMinute, 0, 59)          ; · Valid minute

    ; • Build zero-padded hour
    String h = ""
    If hVal < 10
        h = "0" + hVal                                                ; · Pad single digit
    Else
        h = "" + hVal                                                 ; · Cast to string
    EndIf

    ; • Build zero-padded minute
    String m = ""
    If mVal < 10
        m = "0" + mVal                                                ; · Pad single digit
    Else
        m = "" + mVal                                                 ; · Cast to string
    EndIf

    ; • Combine with colon separator
    Return h + ":" + m                                                ; · “HH:MM”
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Additional Helpers ]═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Add whole hours to a minute-of-day (wrap-safe, supports negatives)
Int Function Time_AddHoursMOD(Int aiBaseMOD, Int aiDeltaHours) Global
    ; • Convert hours→minutes and delegate to Time_AddMinutesMOD
    Int deltaMins = aiDeltaHours * 60                                ; · Scale hours to minutes
    Return Time_AddMinutesMOD(aiBaseMOD, deltaMins)                  ; · Wrapped addition
EndFunction

; ============================================================================================================================

; ● Midpoint between two minute-of-day values (wrap-safe)
Int Function Time_MidpointMOD(Int aiA, Int aiB) Global
    ; • Compute nearest signed delta then offset half that distance
    Int d = Codex:Lib_Math.Math_WrapNearestDelta(aiA, aiB, 1440)     ; · Shortest path (−720..+719)
    Int mid = Codex:Lib_Math.Math_AddWrapInt(aiA, d / 2, 1440)       ; · Move halfway along ring
    Return mid
EndFunction

; ============================================================================================================================

; ● Forward distance (in minutes) from start→end on a 24-hour ring
Int Function Time_MinutesBetweenMOD(Int aiStartMOD, Int aiEndMOD) Global
    ; • Simple forward span; always ≥0 and <1440
    Return Codex:Lib_Math.Math_WrapInt(aiEndMOD - aiStartMOD, 1440)  ; · Forward distance
EndFunction

; ============================================================================================================================

; ● Signed delta (in minutes) from start→end on a 24-hour ring (−720..+719)
Int Function Time_SignedDeltaMOD(Int aiStartMOD, Int aiEndMOD) Global
    ; • Directional difference; positive = forward, negative = backward
    Return Codex:Lib_Math.Math_WrapNearestDelta(aiStartMOD, aiEndMOD, 1440)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝