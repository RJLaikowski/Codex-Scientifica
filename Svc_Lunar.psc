ScriptName Codex:Svc_Lunar Extends Quest


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       LUNAR INITIALIZATION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Initialization Routine ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

Codex:Hub_Nexus Property Link_Nexus Auto Const Mandatory     ; • Reference to the central Hub_Nexus instance responsible for coordinating all services

Bool Link_Lunar_HooksWired = False                           ; • Guard flag ensuring Svc_Lunar event hooks are only wired once to prevent redundant registrations

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Quest initialization — wire hooks only; do not compute/publish until first Time publish from Hub
Event OnQuestInit()
    Link_Lunar_BringUp()        ; · Start Svc_Lunar lifecycle (hooks only; idle until Time publishes)
EndEvent

; ============================================================================================================================

; ● Player load event — rewire hooks defensively; remain idle until Time publishes
Event Actor.OnPlayerLoadGame(Actor akSender)
    Link_Lunar_BringUp()        ; · Ensure hooks; no eager compute/publish
EndEvent

; ============================================================================================================================

; ● Defensive cleanup — avoid duplicate event handlers during dev restarts
Event OnQuestShutdown()
    UnregisterForAllEvents()    ; · clears custom/remote events
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Bring-up routine — validate nexus and wire event hooks (no lunar compute/publish here)
Function Link_Lunar_BringUp()
    ; • Validate nexus presence
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("BringUp - Link_Nexus=None; cannot publish LUNAR.")
        EndIf
        Return
    EndIf

    Link_Lunar_WireHooks()    ; · Subscribe to time bus (idempotent)
EndFunction

; ============================================================================================================================

; ● Hook wiring — subscribe to the nexus Time publish bus using Hub’s wrapper
Function Link_Lunar_WireHooks()
    ; • Register for nexus Time publishes only once
    If !Link_Lunar_HooksWired
        Bool ok = Link_Nexus.Event_Register_Time(Self)        ; · FO4 literal-safe registration via Hub helper
        If ok
            Link_Lunar_HooksWired = True
            If Archive_Level >= 3
                Archive_Info("WireHooks - listening: Hub_Nexus.Event_Publish_Time.")
            EndIf
        ElseIf Archive_Level >= 1
            Archive_Warn("WireHooks - failed to register for Hub_Nexus.Event_Publish_Time.")
        EndIf
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       LUNAR SERVICE
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Lunar Service ══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Simple lunar policy (keep Svc_Lunar lean; consumers can do fancier math off this phase)
Int Property Lunar_CycleDays   = 32 Auto Const           ; • Length of lunar cycle in days (default 32)
Int Property Lunar_PhaseOffset = 0  Auto Const           ; • Phase offset applied to the world day index (0..Cycle-1)

Int  Lunar_LastWorldDayIndex = -1                        ; • Last processed day index (to avoid redundant recomputes)
Int  Lunar_LastPhaseIndex    = -1                        ; • Last published phase index (to detect phase-change edges)
Int  Lunar_PhaseIndex_Today  = 0                         ; • Cached phase index for today (0..Lunar_CycleDays-1)
Int  Lunar_LastTimeStamp     = -1                        ; • Last processed Hub time-stamp (debounce duplicate pings)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Hub_Nexus → Time publish — first publish or day edge: recompute and publish (PhaseChange only when applicable)
Event Codex:Hub_Nexus.Event_Publish_Time(Codex:Hub_Nexus akSender, Var[] akArgs)
    ; • Debounce: skip if we already handled this exact Time publish
    Int stamp = Link_Nexus.GetTime_Stamp()                                ; · Monotonic change-stamp from Hub
    If stamp == Lunar_LastTimeStamp
        Return                                                            ; · Already processed this tick
    EndIf

    ; • Pull today’s absolute day
    Int dayIndex  = Link_Nexus.GetTime_WorldDayIndex()                    ; · ≥0 absolute day

    ; • First-time baseline OR new-day boundary → recompute + publish snapshot (with PhaseChange if applicable)
    If (Lunar_LastWorldDayIndex != dayIndex)                              ; · Covers “first Time publish” and day change
        Int prev = Lunar_PhaseIndex_Today                                 ; · Cache previous for change detection
        Lunar_Recompute()                                                 ; · Update Lunar_PhaseIndex_Today & LastWorldDayIndex

        Int edgeMask = 0
        edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Link_Nexus.Lunar_Edge_PhaseChange, (Lunar_PhaseIndex_Today != prev)) ; · Pulse on change

        Lunar_Publish(edgeMask)                                           ; · Atomic write + notify
    EndIf

    ; • Mark this time publish as handled
    Lunar_LastTimeStamp = stamp                                           ; · Debounce latch
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Recompute today’s lunar phase (simple cycle)
Function Lunar_Recompute()
    ; • Determine today’s phase index from world day + offset (wrap-safe; protects against odd cycle values)
    Int cycle = Lunar_CycleDays
    If cycle < 1
        cycle = 1                                                         ; · Safety: avoid zero/negative modulus
    EndIf
    Int worldDayIndex = Link_Nexus.GetTime_WorldDayIndex()                ; · Read current epoch day
    Int idx = Codex:Lib_Math.Math_AddWrapInt(worldDayIndex, Lunar_PhaseOffset, cycle) ; · 0..cycle-1 phase index

    ; • Update cached values and last-knowns
    Lunar_PhaseIndex_Today = idx                                          ; · Cache for this day
    Lunar_LastWorldDayIndex = worldDayIndex                               ; · Track day
    Lunar_LastPhaseIndex    = idx                                         ; · Track phase for change detection (local)
EndFunction

; ============================================================================================================================

; ● Publish snapshot to Hub_Nexus and ping lunar subscribers
Function Lunar_Publish(Int aiEdgeMask)
    ; • Guard: Nexus must exist to publish
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("Publish - Link_Nexus=None; cannot write LUNAR snapshot.")
        EndIf
        Return
    EndIf

    ; • Nexus write (atomic) then tiny bus notify
    Link_Nexus.Write_Lunar(Lunar_PhaseIndex_Today, aiEdgeMask)            ; · Persist phase index & edges into nexus
    Link_Nexus.Event_Notify_Lunar()                                       ; · Notify subscribers on the Solar/Lunar/Season bus family

    ; • Spam dev trace (quiet in release)
    If Archive_Level >= 4
        Archive_Spam("Publish - phase=" + Lunar_PhaseIndex_Today + " edge=" + aiEdgeMask + ".")
    EndIf
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
String Property Archive_Source Auto Const   ; • Source label, e.g., "[Lunar]" (identifies this system)

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