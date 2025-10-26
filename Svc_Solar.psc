ScriptName Codex:Svc_Solar Extends Quest


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       SOLAR INITIALIZATION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Initialization Routine ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

Codex:Hub_Nexus Property Link_Nexus Auto Const Mandatory     ; • Reference to central Hub_Nexus (time/solar/lunar/season bus)

Bool Link_Solar_HooksWired = False                           ; • Guard so we only wire once per session

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Quest initialization — wire hooks only; do not compute/publish until first Time publish from Hub
Event OnQuestInit()
    Link_Solar_BringUp()        ; · Start Svc_Solar lifecycle (hooks only; idle until Time publishes)
EndEvent

; ============================================================================================================================

; ● Player load — rewire hooks defensively; remain idle until Time publishes
Event Actor.OnPlayerLoadGame(Actor akSender)
    Link_Solar_BringUp()        ; · Ensure hooks; no eager compute/publish
EndEvent

; ============================================================================================================================

; ● Defensive cleanup — avoid duplicate handlers during dev restarts
Event OnQuestShutdown()
    UnregisterForAllEvents()    ; · Clear custom/remote events
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Bring-up routine — validate nexus and wire event hooks (no solar compute/publish here)
Function Link_Solar_BringUp()
    ; • Validate nexus presence
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("BringUp - Link_Nexus=None; cannot subscribe to Time bus.")
        EndIf
        Return
    EndIf

    Link_Solar_WireHooks()    ; · Subscribe to Hub_Nexus time bus (idempotent)
    ; • Intentionally do NOT call Solar_Recompute() or Solar_Publish() here        ; · Defer until first Time publish
EndFunction

; ============================================================================================================================

; ● Hook wiring — subscribe to Hub time bus using the Hub’s wrapper (literal-safe)
Function Link_Solar_WireHooks()
    ; • Register once via Hub’s helper for consistency
    If !Link_Solar_HooksWired
        Bool ok = Link_Nexus.Event_Register_Time(Self)                              ; · FO4-safe literal dispatch
        If ok
            Link_Solar_HooksWired = True
            If Archive_Level >= 3
                Archive_Info("WireHooks - listening: Hub_Nexus.Event_Publish_Time.")
            EndIf
        ElseIf Archive_Level >= 1
            Archive_Warn("WireHooks - failed to register for Hub_Nexus.Event_Publish_Time.")
        EndIf
    ElseIf Archive_Level >= 4
        Archive_Spam("WireHooks - already wired; skipping.")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                         SOLAR SERVICE
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Solar Service ══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int  Solar_LastWorldDayIndex = -1                             ; • Last processed day index (baseline recompute guard)
Int  Solar_LastTimeStamp     = -1                             ; • Last processed Hub time-stamp (debounce duplicate pings)

Int Property Solar_SunriseBaseMinuteOfDay = 360 Auto Const    ; • Default sunrise at 06:00 (360)
Int Property Solar_DayLengthMinutes       = 720 Auto Const    ; • Default day length 12h (720)

Int Solar_SunriseMOD = 360                                    ; • Cached sunrise (minute-of-day)
Int Solar_SunsetMOD  = 1080                                   ; • Cached sunset (minute-of-day)
Int Solar_NoonMOD    = 720                                    ; • Cached solar noon (minute-of-day)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Hub_Nexus → Time publish — baseline after first publish; then recompute on day edge; pulse at rise/noon/set
Event Codex:Hub_Nexus.Event_Publish_Time(Codex:Hub_Nexus akSender, Var[] akArgs)
    ; • Debounce: skip if we already handled this exact Time publish
    Int stamp = Link_Nexus.GetTime_Stamp()                                        ; · Monotonic change-stamp
    If stamp == Solar_LastTimeStamp
        Return                                                                    ; · Already processed this tick
    EndIf

    ; • Pull minimal time signals needed
    Int minuteOfDay = Link_Nexus.GetTime_MinuteOfDay()                            ; · 0..1439
    Int dayIndex    = Link_Nexus.GetTime_WorldDayIndex()                          ; · ≥0 absolute day

    ; • First-time baseline OR new-day boundary → recompute + publish snapshot (no pulses)
    If (Solar_LastWorldDayIndex != dayIndex)                                      ; · Covers “first Time publish” and day change
        Solar_Recompute()                                                         ; · Update Solar_SunriseMOD / Solar_NoonMOD / Solar_SunsetMOD
        Solar_Publish(0)                                                          ; · Baseline snapshot (edge mask = 0)
        ; • Fall through: allow same-minute pulse if baseline minute equals a target (rare but valid)
    EndIf

    ; • Minute cadence: emit one-tick edges exactly at sunrise/noon/sunset
    Int solarEdges = Solar_ComputeEdges(minuteOfDay)                               ; · Sunrise/Noon/Sunset bit mask
    If solarEdges > 0
        Solar_Publish(solarEdges)                                                 ; · Atomic solar write + notify
    EndIf

    ; • Mark this time publish as handled
    Solar_LastTimeStamp = stamp                                                   ; · Debounce latch
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Recompute today’s solar minutes (simple 12h photoperiod policy)
Function Solar_Recompute()
    ; • Use the simple policy: sunrise at base, sunset = base + day length (wrap-safe at 1440), noon midpoint
    Int rise = Solar_SunriseBaseMinuteOfDay                   ; · e.g., 360 (06:00)
    Int setm = Codex:Lib_Time.Time_AddMinutesMOD(rise, Solar_DayLengthMinutes)    ; · Wrap-safe sunset
    Int noon = Codex:Lib_Time.Time_AddMinutesMOD(rise, Solar_DayLengthMinutes / 2); · Wrap-safe midpoint

    ; • Commit to locals (cached for tick comparisons)
    Solar_SunriseMOD = rise
    Solar_SunsetMOD  = setm
    Solar_NoonMOD    = noon

    ; • Track day index to avoid accidental double recompute
    Solar_LastWorldDayIndex = Link_Nexus.GetTime_WorldDayIndex()
EndFunction

; ============================================================================================================================

; ● Publish snapshot to Hub_Nexus and ping solar subscribers
Function Solar_Publish(Int aiEdgeMask)
    ; • Guard: Nexus must exist to publish
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("Publish - Link_Nexus=None; cannot write SOLAR snapshot.")
        EndIf
        Return
    EndIf

    ; • Nexus write (atomic) then tiny bus notify
    Link_Nexus.Write_Solar(Solar_SunriseMOD, Solar_SunsetMOD, Solar_NoonMOD, aiEdgeMask)    ; · Coherent write
    Link_Nexus.Event_Notify_Solar()                                                         ; · Push ping (listeners pull getters)

    ; • Verbose dev trace (quiet in release)
    If Archive_Level >= 4
        Archive_Spam("Publish - riseMOD=" + Solar_SunriseMOD + " noonMOD=" + Solar_NoonMOD + " setMOD=" + Solar_SunsetMOD + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ============================================================================================================================

; ● Compute edge mask for the current minute (rise/noon/set)
Int Function Solar_ComputeEdges(Int aiMinuteOfDay)
    Int edges = 0
    edges = Codex:Lib_Math.Math_SetBit(edges, Link_Nexus.Solar_Edge_Sunrise,   (aiMinuteOfDay == Solar_SunriseMOD))
    edges = Codex:Lib_Math.Math_SetBit(edges, Link_Nexus.Solar_Edge_SolarNoon, (aiMinuteOfDay == Solar_NoonMOD))
    edges = Codex:Lib_Math.Math_SetBit(edges, Link_Nexus.Solar_Edge_Sunset,    (aiMinuteOfDay == Solar_SunsetMOD))
    Return edges
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                           Telemetry & Audit
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Telemetry & Audit ══════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int    Property Archive_Level  Auto Const   ; • 0 = Off, 1 = Error, 2 = Warn, 3 = Info, 4 = Spam (recommended: 3 in dev)
String Property Archive_Prefix Auto Const   ; • Standard tag prefix, e.g., "[Codex]" for consistent log scanning
String Property Archive_Source Auto Const   ; • Source label, e.g., "[Solar]" (identifies this system)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Emit canonical report: level-gated, categorized by level, branded, traced
Function Archive_Report(Int aiLevel, String asMessage)
    ; • Normalize level and gate by policy (0 = Off, 1 = Error, 2 = Warn, 3 = Info, 4 = Spam)
    If aiLevel < 1
        aiLevel = 1          ; · Clamp to ERROR
    ElseIf aiLevel > 4
        aiLevel = 4          ; · Clamp to SPAM
    EndIf
    If aiLevel > Archive_Level  ; · Threshold gate (silence when level exceeds policy)
        Return               ; · Not authorized to emit
    EndIf

    ; • Derive category token from level (enforce chain)
    String sCat = "SPAM"     ; · Default to SPAM
    If aiLevel == 1
        sCat = "ERROR"       ; · Level 1
    ElseIf aiLevel == 2
        sCat = "WARN"        ; · Level 2
    ElseIf aiLevel == 3
        sCat = "INFO"        ; · Level 3
    EndIf

    ; • Compose standardized line and emit
    String sLine = Archive_Prefix + "[" + sCat + "][" + Archive_Source + "] " + asMessage
    Debug.Trace(sLine)       ; · Emit to Papyrus log
EndFunction

; ============================================================================================================================

; ● Convenience: error severity (level 1)
Function Archive_Error(String asMessage)
    ; • Canonical ERROR; level decides category
    Archive_Report(1, asMessage)  ; · Route through core logger
EndFunction

; ● Convenience: warning severity (level 2)
Function Archive_Warn(String asMessage)
    ; • Canonical WARN; level decides category
    Archive_Report(2, asMessage)  ; · Route through core logger
EndFunction

; ● Convenience: informational severity (level 3)
Function Archive_Info(String asMessage)
    ; • Canonical INFO; level decides category
    Archive_Report(3, asMessage)  ; · Route through core logger
EndFunction

; ● Convenience: spam severity (level 4)
Function Archive_Spam(String asMessage)
    ; • Canonical SPAM; level decides category
    Archive_Report(4, asMessage)  ; · Route through core logger
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝