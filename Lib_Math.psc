ScriptName Codex:Lib_Math Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Math — Common math helpers used across Time, Solar, Lunar, Season
;  Notes:
;   • Papyrus-safe: no bitwise ops; all functions are stateless, Global.
;   • Wrap helpers work for any modulus (e.g., 1440 for minute-of-day, 32 for lunar).
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ══════[ Clamp & Saturate ]═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Clamp an integer to [lo..hi]
Int Function Math_ClampInt(Int aiValue, Int aiLo, Int aiHi) Global
    ; • Ensure lo<=hi (swap if needed)
    If aiLo > aiHi
        Int t = aiLo                                     ; · Swap bounds
        aiLo = aiHi
        aiHi = t
    EndIf
    ; • Clamp to range
    If   aiValue < aiLo
        Return aiLo                                      ; · Below → lo
    ElseIf aiValue > aiHi
        Return aiHi                                      ; · Above → hi
    EndIf
    Return aiValue                                       ; · Inside → value
EndFunction

; ============================================================================================================================

; ● Clamp a float to [lo..hi]
Float Function Math_ClampFloat(Float afValue, Float afLo, Float afHi) Global
    ; • Ensure lo<=hi (swap if needed)
    If afLo > afHi
        Float t = afLo                                   ; · Swap bounds
        afLo = afHi
        afHi = t
    EndIf
    ; • Clamp to range
    If   afValue < afLo
        Return afLo                                      ; · Below → lo
    ElseIf afValue > afHi
        Return afHi                                      ; · Above → hi
    EndIf
    Return afValue                                       ; · Inside → value
EndFunction

; ============================================================================================================================

; ● Clamp a float to [0..1] (“saturate”)
Float Function Math_Saturate01(Float afValue) Global
    If afValue < 0.0
        Return 0.0                                       ; · Clamp low
    ElseIf afValue > 1.0
        Return 1.0                                       ; · Clamp high
    EndIf
    Return afValue                                       ; · Inside
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Wrap & Modulo ]════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Wrap an integer into [0..modulus-1] (supports negatives)
Int Function Math_WrapInt(Int aiValue, Int aiModulus) Global
    ; • Guard modulus
    If aiModulus <= 0
        Return 0                                         ; · Degenerate modulus
    EndIf
    Int r = aiValue % aiModulus                          ; · Reduce to range
    If r < 0
        r += aiModulus                                   ; · Fix negative remainder
    EndIf
    Return r
EndFunction

; ============================================================================================================================

; ● Add a delta then wrap into [0..modulus-1]
Int Function Math_AddWrapInt(Int aiBase, Int aiDelta, Int aiModulus) Global
    ; • Reduce delta first, then wrap
    Int r = (aiBase + (aiDelta % aiModulus)) % aiModulus ; · Sum reduced
    If r < 0
        r += aiModulus                                   ; · Fix negative remainder
    EndIf
    Return r
EndFunction

; ============================================================================================================================

; ● Shortest signed delta on a ring (−half..+half−1)
Int Function Math_WrapNearestDelta(Int aiFrom, Int aiTo, Int aiModulus) Global
    ; • Guard modulus
    If aiModulus <= 0
        Return 0                                         ; · Degenerate modulus
    EndIf
    Int half = aiModulus / 2                             ; · Half-span
    Int d = aiTo - aiFrom                                ; · Raw delta
    If d > half
        d -= aiModulus                                   ; · Prefer backward
    ElseIf d < -half
        d += aiModulus                                   ; · Prefer forward
    EndIf
    Return d
EndFunction

; ============================================================================================================================

; ● Check if value lies within [start..end] on a ring (wrap-safe)
Bool Function Math_IsWithinWrap(Int aiValue, Int aiStart, Int aiEnd, Int aiModulus) Global
    ; • Normalize to 0..mod-1
    Int v = Math_WrapInt(aiValue, aiModulus)             ; · Value
    Int s = Math_WrapInt(aiStart, aiModulus)             ; · Start
    Int e = Math_WrapInt(aiEnd,   aiModulus)             ; · End
    ; • Non-wrapping vs. wrapping interval
    If s <= e
        Return (v >= s) && (v <= e)                      ; · Straight interval
    EndIf
    Return (v >= s) || (v <= e)                          ; · Wrapped interval
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Lerp & Easing ]════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Linear interpolation between a and b by t (no clamp)
Float Function Math_Lerp(Float afA, Float afB, Float afT) Global
    Return afA + (afB - afA) * afT                       ; · Basic lerp
EndFunction

; ============================================================================================================================

; ● Inverse lerp: map x in [a..b] to t in [0..1] (clamped)
Float Function Math_InverseLerp01(Float afA, Float afB, Float afX) Global
    ; • Handle degenerate span
    Float span = afB - afA                               ; · Range width
    If span == 0.0
        Return 0.0                                       ; · Avoid div by zero
    EndIf
    Float t = (afX - afA) / span                         ; · Raw t
    Return Math_Saturate01(t)                            ; · Clamp to 0..1
EndFunction

; ============================================================================================================================

; ● Smoothstep(0..1): cubic ease t*t*(3-2*t) (clamped)
Float Function Math_SmoothStep01(Float afT) Global
    Float t = Math_Saturate01(afT)                       ; · Clamp to 0..1
    Return t * t * (3.0 - 2.0 * t)                       ; · Smooth ease
EndFunction

; ============================================================================================================================

; ● Linear interpolation between integer bounds (returns float)
Float Function Math_LerpInt(Int aiA, Int aiB, Float afT) Global
    Return aiA + ((aiB - aiA) * afT)
EndFunction

; ============================================================================================================================

; ● Map a value from one numeric range to another (clamped to [c..d])
Float Function Math_MapRange(Float afX, Float afInA, Float afInB, Float afOutA, Float afOutB) Global
    If afInB == afInA
        Return afOutA
    EndIf
    Float t = (afX - afInA) / (afInB - afInA)
    t = Math_Saturate01(t)
    Return Math_Lerp(afOutA, afOutB, t)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Powers & Bits ]════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Compute 2^n for n>=0 (Papyrus-safe, no bit shifts)
Int Function Math_Pow2(Int aiN) Global
    If aiN <= 0
        Return 1                                         ; · 2^0 = 1
    EndIf
    Int r = 1
    Int i = 0
    While i < aiN
        r *= 2                                           ; · Multiply by two
        i += 1
    EndWhile
    Return r
EndFunction

; ============================================================================================================================

; ● Check if a bit is set using division/modulo (no & / << in FO4)
Bool Function Math_BitIsSet(Int aiMask, Int aiBitIndex) Global
    ; • Validate bit range (avoid sign bit)
    If (aiBitIndex < 0) || (aiBitIndex > 30)
        Return False                                     ; · Out of range
    EndIf
    Int pow = Math_Pow2(aiBitIndex)                      ; · 1 << bit
    Int shifted = aiMask / pow                           ; · Shift right by bit
    Int bit = shifted % 2                                ; · Isolated bit
    Return (bit == 1)                                    ; · True if set
EndFunction

; ============================================================================================================================

; ● Set or clear a bit, Papyrus-safe (returns the new mask)
Int Function Math_SetBit(Int aiMask, Int aiBitIndex, Bool abValue) Global
    ; • Validate bit range (avoid sign bit)
    If (aiBitIndex < 0) || (aiBitIndex > 30)
        Return aiMask                                    ; · Ignore invalid
    EndIf
    Int pow = Math_Pow2(aiBitIndex)                      ; · 1 << bit
    Bool isSet = Math_BitIsSet(aiMask, aiBitIndex)       ; · Current state
    If abValue
        If isSet
            Return aiMask                                ; · Already set
        EndIf
        Return aiMask + pow                              ; · Add bit
    Else
        If !isSet
            Return aiMask                                ; · Already clear
        EndIf
        Return aiMask - pow                              ; · Remove bit
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

; ══════[ Additional Small Helpers ]═════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Round a float to the nearest integer (banker’s rounding not needed)
Int Function Math_RoundToInt(Float afValue) Global
    If afValue >= 0.0
        Return (afValue + 0.5) as Int
    EndIf
    Return (afValue - 0.5) as Int
EndFunction

; ============================================================================================================================

; ● Add bounded random noise to a base value (uniform distribution)
Float Function Math_AddNoise(Float afBase, Float afAmplitude) Global
    Float delta = Utility.RandomFloat(-afAmplitude, afAmplitude)
    Return afBase + delta
EndFunction

; ============================================================================================================================

; ● Absolute value for Int
Int Function Math_AbsInt(Int aiValue) Global
    If aiValue < 0
        Return -aiValue                                      ; · Negate negatives
    EndIf
    Return aiValue                                           ; · Already non-negative
EndFunction

; ============================================================================================================================

; ● Absolute value for Float
Float Function Math_AbsFloat(Float afValue) Global
    If afValue < 0.0
        Return -afValue                                      ; · Negate negatives
    EndIf
    Return afValue                                           ; · Already non-negative
EndFunction

; ============================================================================================================================

; ● Sign of Int (−1, 0, +1)
Int Function Math_SignInt(Int aiValue) Global
    If aiValue > 0
        Return 1                                             ; · Positive
    ElseIf aiValue < 0
        Return -1                                            ; · Negative
    EndIf
    Return 0                                                 ; · Zero
EndFunction

; ============================================================================================================================

; ● Sign of Float (−1.0, 0.0, +1.0)
Float Function Math_SignFloat(Float afValue) Global
    If afValue > 0.0
        Return 1.0                                           ; · Positive
    ElseIf afValue < 0.0
        Return -1.0                                          ; · Negative
    EndIf
    Return 0.0                                               ; · Zero
EndFunction

; ============================================================================================================================

; ● Float equality check within tolerance (epsilon)
Bool Function Math_FloatEquals(Float afA, Float afB, Float afEpsilon = 0.0001) Global
    ; • True if |a−b| < epsilon
    Float diff = Math_AbsFloat(afA - afB)
    Return (diff < afEpsilon)
EndFunction

; ============================================================================================================================

; ● Int equality check (alias for clarity in service logic)
Bool Function Math_IntEquals(Int aiA, Int aiB) Global
    Return (aiA == aiB)
EndFunction

; ============================================================================================================================

; ● Clamp integer to non-negative range [0..∞)
Int Function Math_ClampNonNegative(Int aiValue) Global
    If aiValue < 0
        Return 0                                             ; · Enforce ≥0
    EndIf
    Return aiValue
EndFunction

; ============================================================================================================================

; ● Clamp float to non-negative range [0..∞)
Float Function Math_ClampNonNegativeFloat(Float afValue) Global
    If afValue < 0.0
        Return 0.0                                           ; · Enforce ≥0
    EndIf
    Return afValue
EndFunction

; ============================================================================================================================

; ● Integer wrap-around add for small bounded counters (safer alias)
Int Function Math_AddClampInt(Int aiBase, Int aiDelta, Int aiMin, Int aiMax) Global
    ; • Add delta then clamp result
    Int result = aiBase + aiDelta
    Return Math_ClampInt(result, aiMin, aiMax)
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝