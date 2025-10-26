ScriptName Codex:Svc_Season Extends Quest


; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       SEASON INITIALIZATION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Initialization Routine ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

Codex:Hub_Nexus Property Link_Nexus Auto Const Mandatory     ; • Reference to the central Hub_Nexus instance responsible for coordinating all services

Bool Link_Season_HooksWired = False                          ; • Guard flag ensuring Svc_Season event hooks are only wired once to prevent redundant registrations

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Quest initialization — wire hooks only; do not compute/publish until first Time publish from Hub
Event OnQuestInit()
    Link_Season_BringUp()       ; · Start Svc_Season lifecycle (hooks only; idle until Time publishes)
EndEvent

; ============================================================================================================================

; ● Player load event — rewire hooks defensively; remain idle until Time publishes
Event Actor.OnPlayerLoadGame(Actor akSender)
    Link_Season_BringUp()       ; · Ensure hooks; no eager compute/publish
EndEvent

; ============================================================================================================================

; ● Defensive cleanup — avoid duplicate event handlers during dev restarts
Event OnQuestShutdown()
    UnregisterForAllEvents()    ; · clears custom/remote events
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Bring-up routine — validate Nexus and wire event hooks (no season compute/publish here)
Function Link_Season_BringUp()
    ; • Validate Nexus presence
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("BringUp - Link_Nexus=None; cannot publish SEASON.")
        EndIf
        Return
    EndIf

    Link_Season_WireHooks()    ; · Subscribe to time bus (idempotent)
    ; • Intentionally do NOT call Season_Recompute() or Season_Publish() here   ; · Defer until first Time publish
EndFunction

; ============================================================================================================================

; ● Hook wiring — subscribe to nexus Time publish bus using Hub’s wrapper
Function Link_Season_WireHooks()
    ; • Register for nexus Time publishes only once
    If !Link_Season_HooksWired
        Bool ok = Link_Nexus.Event_Register_Time(Self)          ; · FO4 literal-safe registration via Hub helper
        If ok
            Link_Season_HooksWired = True
            If Archive_Level >= 3
                Archive_Info("WireHooks - listening: Hub_Nexus.Event_Publish_Time.")
            EndIf
        ElseIf Archive_Level >= 1
            Archive_Warn("WireHooks - failed to register for Hub_Nexus.Event_Publish_Time.")
        EndIf
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       SEASON SERVICE
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Season Service ═════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● 365-day, no-leap seasonal boundaries (DoY). Adjust in CK if desired.
;   1..365 baseline: Spring ≈ Mar 21 (80), Summer ≈ Jun 21 (172), Fall ≈ Sep 22 (265), Winter ≈ Dec 21 (355)
Int Property Season_Spring_Start = 80  Auto Const          ; • Start day-of-year for Spring
Int Property Season_Summer_Start = 172 Auto Const          ; • Start day-of-year for Summer
Int Property Season_Fall_Start   = 265 Auto Const          ; • Start day-of-year for Fall
Int Property Season_Winter_Start = 355 Auto Const          ; • Start day-of-year for Winter

; ● Cached state for publish decisions
Int Season_Index_Today   = 0                               ; • 0 = Spring, 1 = Summer, 2 = Fall, 3 = Winter
Int Season_DayOfSeason   = 1                               ; • 1..DaysInSeason
Int Season_DaysInSeason  = 90                              ; • >0, depends on boundary span
Int Season_LastIndex     = -1                              ; • Last published season index (to detect boundary)
Int Season_LastWorldDay  = -1                              ; • Last processed day index (guard)
Int Season_LastTimeStamp = -1                              ; • Last processed Hub time-stamp (debounce duplicate pings)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Hub_Nexus → Time publish — first publish or day edge: recompute and publish (SeasonStart only when applicable)
Event Codex:Hub_Nexus.Event_Publish_Time(Codex:Hub_Nexus akSender, Var[] akArgs)
    ; • Debounce: skip if we already handled this exact Time publish
    Int stamp = Link_Nexus.GetTime_Stamp()                                 ; · Monotonic change-stamp
    If stamp == Season_LastTimeStamp
        Return                                                             ; · Already processed this tick
    EndIf

    ; • Observe today’s world-day index
    Int dayIndex  = Link_Nexus.GetTime_WorldDayIndex()                     ; · ≥0 absolute day

    ; • First-time baseline OR new-day boundary → recompute + publish snapshot (SeasonStart pulse if index changed)
    If (Season_LastWorldDay != dayIndex)
        Int prevIndex = Season_Index_Today
        Season_Recompute()

        Int edgeMask = 0
        edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Link_Nexus.Season_Edge_SeasonStart, (Season_Index_Today != prevIndex)) ; · Pulse on boundary

        Season_Publish(edgeMask)                                           ; · Atomic write + notify
    EndIf

    ; • Mark this time publish as handled
    Season_LastTimeStamp = stamp                                           ; · Debounce latch
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Recompute today’s season index and counters (365-day)
Function Season_Recompute()
    ; • Fetch today's DayOfYear and resolve via library helper
    Int doy = Link_Nexus.GetTime_DayOfYear()                               ; · 1..365
    Int[] rec = Codex:Lib_Season.Season_RecomputeFromDoY(doy, Season_Spring_Start, Season_Summer_Start, Season_Fall_Start, Season_Winter_Start, 365) ; · [idx, dayOfSeason, daysInSeason]

    ; • Commit to locals
    Season_Index_Today  = rec[0]
    Season_DayOfSeason  = rec[1]
    Season_DaysInSeason = rec[2]
    Season_LastWorldDay = Link_Nexus.GetTime_WorldDayIndex()               ; · Track last processed day
    Season_LastIndex    = Season_Index_Today                               ; · Track last index for boundary detection
EndFunction

; ============================================================================================================================


; ● Publish snapshot to Hub_Nexus and ping season subscribers
Function Season_Publish(Int aiEdgeMask)
    ; • Guard: Nexus must exist to publish
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("Publish - Link_Nexus=None; cannot write SEASON snapshot.")
        EndIf
        Return
    EndIf

    ; • Nexus write (atomic) then tiny bus notify
    Link_Nexus.Write_Season(Season_Index_Today, Season_DayOfSeason, Season_DaysInSeason, aiEdgeMask)
    Link_Nexus.Event_Notify_Season()                                       ; · Notify subscribers on the Season bus

    ; • Spam dev trace (quiet in release)
    If Archive_Level >= 4
        Archive_Spam("Publish - sIdx=" + Season_Index_Today + " day=" + Season_DayOfSeason + "/" + Season_DaysInSeason + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                           Telemetry & Audit
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Telemetry & Audit ══════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int    Property Archive_Level  Auto Const   ; • 0 = Off, 1 = Error, 2 = Warn, 3 = Info, 4 = Spam (recommended: 3 in dev)
String Property Archive_Prefix Auto Const   ; • Standard tag prefix, e.g., "[Codex]" for consistent log scanning
String Property Archive_Source Auto Const   ; • Source label, e.g., "[Season]" (identifies this system)

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
    Debug.Trace(sLine)  ; · Emit to Papyrus log
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