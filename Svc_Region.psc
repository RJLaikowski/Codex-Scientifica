ScriptName Codex:Svc_Region Extends Quest


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       REGION INITIALIZATION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Hub Link ==================================================================================================================
Codex:Hub_Nexus Property Link_Nexus Auto Const Mandatory           ; • Nexus sink for Region write/event

; === Region Cell Sets ==========================================================================================================
FormList Property Region_Cells_NorthernFoothills Auto              ; • CELL set: Northern Foothills
FormList Property Region_Cells_BlastedForest    Auto               ; • CELL set: Blasted Forest
FormList Property Region_Cells_Coast            Auto               ; • CELL set: Coast
FormList Property Region_Cells_Downtown         Auto               ; • CELL set: Downtown
FormList Property Region_Cells_Marsh            Auto               ; • CELL set: Marsh
FormList Property Region_Cells_GlowingSea       Auto               ; • CELL set: Glowing Sea

; === Region Location Sets ======================================================================================================
FormList Property Region_Locs_NorthernFoothills Auto              ; • LCTN set: Northern Foothills
FormList Property Region_Locs_BlastedForest    Auto               ; • LCTN set: Blasted Forest
FormList Property Region_Locs_Coast            Auto               ; • LCTN set: Coast
FormList Property Region_Locs_Downtown         Auto               ; • LCTN set: Downtown
FormList Property Region_Locs_Marsh            Auto               ; • LCTN set: Marsh
FormList Property Region_Locs_GlowingSea       Auto               ; • LCTN set: Glowing Sea

; === Fixed-order tables (0..5) =================================================================================================
FormList[] gRegionCellLists                                         ; • Index → FormList of CELLs
FormList[] gRegionLocLists                                          ; • Index → FormList of LOCATIONs

; === Optional data-driven fast path (Location keywords) =========================================================================
Keyword Property Region_KW_NorthernFoothills Auto                 ; • Keyword → region 0
Keyword Property Region_KW_BlastedForest    Auto                  ; • Keyword → region 1
Keyword Property Region_KW_Coast            Auto                  ; • Keyword → region 2
Keyword Property Region_KW_Downtown         Auto                  ; • Keyword → region 3
Keyword Property Region_KW_Marsh            Auto                  ; • Keyword → region 4
Keyword Property Region_KW_GlowingSea       Auto                  ; • Keyword → region 5
Keyword[] gRegionLocKeywords                                      ; • Index → keyword (optional, bound at bring-up)

; === Local cache — fast no-op when cell unchanged ==============================================================================
Cell cache_LastCell                                                 ; • Last processed player parent cell
Int  cache_LastIndex = -1                                           ; • Last computed region index (−1 = unknown)

; === Memo rings — tiny recent caches to avoid repeated scans ===================================================================
Int     Region_MemoSize_Cells = 128 Const                           ; • Ring capacity for cells
Cell[]  memo_Cells                                                  ; • Ring: recent cells
Int[]   memo_CellIdx                                                ; • Ring: resolved indices (may be −1)
Int     memo_CellWritePos = 0                                       ; • Next write slot (wraps)

Int       Region_MemoSize_Locs = 128 Const                          ; • Ring capacity for locations
Location[] memo_Locs                                                ; • Ring: recent locations
Int[]      memo_LocIdx                                              ; • Ring: resolved indices (may be −1)
Int        memo_LocWritePos = 0                                     ; • Next write slot (wraps)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Quest initialization — bind tables/memos; idle until alias events
Event OnQuestInit()
    Link_Region_BringUp()                                           ; · Ready to resolve on cell/location change
EndEvent

; ============================================================================================================================

; ● Player load — rebind defensively; arrays persist but keep idempotent
Event Actor.OnPlayerLoadGame(Actor akSender)
    Link_Region_BringUp()                                           ; · Ensure tables/memos are bound
EndEvent

; ============================================================================================================================

; ● Defensive cleanup — avoid residue during dev restarts
Event OnQuestShutdown()
    UnregisterForAllEvents()                                        ; · Clear any stray subs (none expected)
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Bring-up — validate nexus, bind region lists and memo buffers
Function Link_Region_BringUp()
    ; • Validate nexus presence
    If Link_Nexus == None
        If Archive_Level >= 1
            Archive_Error("BringUp - Link_Nexus=None; cannot publish Region.")
        EndIf
        Return
    EndIf

    ; • Bind fixed-order CELL lists once
    If gRegionCellLists == None
        gRegionCellLists = new FormList[6]                          ; · Allocate slots
        gRegionCellLists[0] = Region_Cells_NorthernFoothills        ; · 0
        gRegionCellLists[1] = Region_Cells_BlastedForest            ; · 1
        gRegionCellLists[2] = Region_Cells_Coast                    ; · 2
        gRegionCellLists[3] = Region_Cells_Downtown                 ; · 3
        gRegionCellLists[4] = Region_Cells_Marsh                    ; · 4
        gRegionCellLists[5] = Region_Cells_GlowingSea               ; · 5
        If Archive_Level >= 3
            Archive_Info("BringUp - CELL lists bound (6).")
        EndIf
    EndIf

    ; • Bind fixed-order LCTN lists once (may be empty if not authored yet)
    If gRegionLocLists == None
        gRegionLocLists = new FormList[6]                           ; · Allocate slots
        gRegionLocLists[0] = Region_Locs_NorthernFoothills          ; · 0
        gRegionLocLists[1] = Region_Locs_BlastedForest              ; · 1
        gRegionLocLists[2] = Region_Locs_Coast                      ; · 2
        gRegionLocLists[3] = Region_Locs_Downtown                   ; · 3
        gRegionLocLists[4] = Region_Locs_Marsh                      ; · 4
        gRegionLocLists[5] = Region_Locs_GlowingSea                 ; · 5
        If Archive_Level >= 3
            Archive_Info("BringUp - LCTN lists bound (6).")
        EndIf
    EndIf

    ; • Optional keyword map (data-driven fast path). Zero cost if left None.
    If gRegionLocKeywords == None
        gRegionLocKeywords = new Keyword[6]                         ; · Allocate slots
        gRegionLocKeywords[0] = Region_KW_NorthernFoothills         ; · 0
        gRegionLocKeywords[1] = Region_KW_BlastedForest             ; · 1
        gRegionLocKeywords[2] = Region_KW_Coast                     ; · 2
        gRegionLocKeywords[3] = Region_KW_Downtown                  ; · 3
        gRegionLocKeywords[4] = Region_KW_Marsh                     ; · 4
        gRegionLocKeywords[5] = Region_KW_GlowingSea                ; · 5
        If Archive_Level >= 3
            Archive_Info("BringUp - Keyword map bound (opt).")
        EndIf
    EndIf

    ; • Allocate memo rings if uninitialized (cells)
    If memo_Cells == None
        memo_Cells       = new Cell[Region_MemoSize_Cells]          ; · Create ring
        memo_CellIdx     = new Int[Region_MemoSize_Cells]           ; · Parallel indices
        memo_CellWritePos = 0                                       ; · Reset head
        If Archive_Level >= 4
            Archive_Spam("BringUp - memo ring (cells) size=" + Region_MemoSize_Cells + ".")
        EndIf
    EndIf

    ; • Allocate memo rings if uninitialized (locations)
    If memo_Locs == None
        memo_Locs        = new Location[Region_MemoSize_Locs]       ; · Create ring
        memo_LocIdx      = new Int[Region_MemoSize_Locs]            ; · Parallel indices
        memo_LocWritePos = 0                                        ; · Reset head
        If Archive_Level >= 4
            Archive_Spam("BringUp - memo ring (locs) size=" + Region_MemoSize_Locs + ".")
        EndIf
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                          REGION SERVICE (HELPERS)
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Memo lookup (Cell) — try recent cells before any list checks
Int Function Region_MemoLookup_Cell(Cell akCell)
    ; • Guard
    If akCell == None || memo_Cells == None
        Return -1                                                  ; · Unknown
    EndIf

    ; • Linear probe over tiny ring (fast)
    Int i = 0
    While i < Region_MemoSize_Cells
        If memo_Cells[i] == akCell
            Return memo_CellIdx[i]                                 ; · Hit (may be −1)
        EndIf
        i = i + 1
    EndWhile
    Return -1                                                      ; · Miss
EndFunction

; ============================================================================================================================

; ● Memo store (Cell) — write (cell→index) at ring head then advance
Function Region_MemoStore_Cell(Cell akCell, Int aiIndex)
    ; • Guard
    If memo_Cells == None
        Return                                                     ; · Not allocated
    EndIf

    ; • Write then wrap
    memo_Cells[memo_CellWritePos]   = akCell                       ; · Cell
    memo_CellIdx[memo_CellWritePos] = aiIndex                      ; · Index (may be −1)
    memo_CellWritePos = memo_CellWritePos + 1                      ; · Advance
    If memo_CellWritePos >= Region_MemoSize_Cells
        memo_CellWritePos = 0                                      ; · Wrap
    EndIf
EndFunction

; ============================================================================================================================

; ● Memo lookup (Location) — try recent locations before any list checks
Int Function Region_MemoLookup_Loc(Location akLoc)
    ; • Guard
    If akLoc == None || memo_Locs == None
        Return -1                                                  ; · Unknown
    EndIf

    ; • Linear probe over tiny ring (fast)
    Int i = 0
    While i < Region_MemoSize_Locs
        If memo_Locs[i] == akLoc
            Return memo_LocIdx[i]                                  ; · Hit (may be −1)
        EndIf
        i = i + 1
    EndWhile
    Return -1                                                      ; · Miss
EndFunction

; ============================================================================================================================

; ● Memo store (Location) — write (loc→index) at ring head then advance
Function Region_MemoStore_Loc(Location akLoc, Int aiIndex)
    ; • Guard
    If memo_Locs == None
        Return                                                     ; · Not allocated
    EndIf

    ; • Write then wrap
    memo_Locs[memo_LocWritePos]   = akLoc                          ; · Location
    memo_LocIdx[memo_LocWritePos] = aiIndex                        ; · Index (may be −1)
    memo_LocWritePos = memo_LocWritePos + 1                        ; · Advance
    If memo_LocWritePos >= Region_MemoSize_Locs
        memo_LocWritePos = 0                                       ; · Wrap
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                          REGION RESOLUTION (LOCATION-FIRST)
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Resolve from Location — memo → last-region-first (parent chain) → scan others (parent chain)
Int Function Region_FromLocation(Location akLoc)
    ; • Guard
    If akLoc == None
        Return -1                                                  ; · Unknown (wilderness or unmapped)
    EndIf

    ; • Step 1: memo probe
    Int memo = Region_MemoLookup_Loc(akLoc)
    If memo != -1
        Return memo                                                ; · Use memoized result (may be −1)
    EndIf

    ; • Step 1b: data-driven keyword fast path (optional, O(1))
    If gRegionLocKeywords != None
        Int k = 0
        While k < 6
            Keyword kw = gRegionLocKeywords[k]
            If (kw != None) && akLoc.HasKeyword(kw)
                Return k                                           ; · Direct hit via keyword
            EndIf
            k = k + 1
        EndWhile
    EndIf

    ; • Step 2: last-region-first using parent-chain membership
    Int last = cache_LastIndex
    If (last >= 0) && (last < 6)
        FormList lst = gRegionLocLists[last]                       ; · Prior region LCTN list
        If lst != None && Codex:Lib_Region.Region_LocMatchesList(akLoc, lst)
            Return last                                            ; · Fast path
        EndIf
    EndIf

    ; • Step 3: linear scan across remaining LCTN lists
    Int i = 0
    While i < 6
        If i != last                                               ; · Skip already-probed list
            FormList fl = gRegionLocLists[i]                       ; · Slot
            If fl != None && Codex:Lib_Region.Region_LocMatchesList(akLoc, fl)
                Return i                                           ; · Found
            EndIf
        EndIf
        i = i + 1
    EndWhile

    Return -1                                                      ; · Not mapped via Location
EndFunction

; ============================================================================================================================

; ● Resolve from Cell — memo → last-region-first → scan others
Int Function Region_FromCell(Cell akCell)
    ; • Guard
    If akCell == None
        Return -1                                                  ; · Unknown
    EndIf

    ; • Step 1: memo probe (common hotspots/interiors)
    Int memo = Region_MemoLookup_Cell(akCell)
    If memo != -1
        Return memo                                                ; · Use memoized result (may be −1)
    EndIf

    ; • Step 2: last-region-first probe (most transitions stay in-region)
    Int last = cache_LastIndex
    If (last >= 0) && (last < 6)
        FormList flLast = gRegionCellLists[last]                   ; · Prior region CELL list
        If flLast != None && flLast.HasForm(akCell)
            Return last                                            ; · Fast path
        EndIf
    EndIf

    ; • Step 3: linear scan across remaining CELL lists (skip last if probed)
    Int i = 0
    While i < 6
        If i != last                                               ; · Skip already-probed list
            FormList fl = gRegionCellLists[i]                      ; · Slot
            If fl != None && fl.HasForm(akCell)
                Return i                                           ; · Found
            EndIf
        EndIf
        i = i + 1
    EndWhile

    Return -1                                                      ; · Not mapped via Cell
EndFunction

; ============================================================================================================================

; ● Resolve from Location-first, then Cell as fallback — returns index (−1 when unknown)
Int Function Region_FromAny(Cell akCell, Location akLoc)
    ; • Try Location-first path
    Int idxLoc = Region_FromLocation(akLoc)                        ; · May be −1
    If idxLoc != -1
        ; • Memoize success (Location)
        Region_MemoStore_Loc(akLoc, idxLoc)                        ; · Store hit
        Return idxLoc                                              ; · Found via Location
    Else
        ; • Memoize miss (Location) to avoid re-walking parents immediately next time
        If akLoc != None
            Region_MemoStore_Loc(akLoc, -1)                        ; · Store miss
        EndIf
    EndIf

    ; • Fallback to Cell path
    Int idxCell = Region_FromCell(akCell)                          ; · May be −1
    ; • Memoize result for cell
    If akCell != None
        Region_MemoStore_Cell(akCell, idxCell)                     ; · Store hit/miss
    EndIf
    Return idxCell
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                EVENT INGEST (FROM PLAYER ALIAS) → HUB PUBLISH
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Handle player cell/location event — compute/publish only on true cell change; memoize results
Function Region_Publish(Cell akCell, Location akLoc)
    ; • De-dupe: identical cell as last processed?
    If akCell == cache_LastCell
        Return                                                     ; · No change
    EndIf

    ; • Compute new index via Location-first ladder with Cell fallback
    Int newIdx = Region_FromAny(akCell, akLoc)                     ; · Resolve (may be −1)
    Int prevIdx = cache_LastIndex                                  ; · Snapshot old

    ; • Update local cache
    cache_LastCell  = akCell                                       ; · Cache cell
    cache_LastIndex = newIdx                                       ; · Cache index

    ; • Edge bit (bit0) only when region actually changed
    Int edge = 0
    If newIdx != prevIdx
        edge = 1                                                   ; · Pulse “changed”
    EndIf

    ; • Publish through Hub — coherent write then ping on change
    If Link_Nexus != None
        Link_Nexus.Write_Region(newIdx, edge)                      ; · Atomic region snapshot
        If edge != 0
            Link_Nexus.Event_Notify_Region()                       ; · Notify listeners (pull getters)
        EndIf
    EndIf

    ; • Optional trace
    If Archive_Level >= 4
        Archive_Spam("CellLocEvent - idx=" + newIdx + " prev=" + prevIdx + " edge=" + edge + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                        Telemetry & Audit
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Telemetry & Audit ══════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int    Property Archive_Level  Auto Const   ; • 0 = Off, 1 = Error, 2 = Warn, 3 = Info, 4 = Spam (recommended: 3 in dev)
String Property Archive_Prefix Auto Const   ; • Standard tag prefix, e.g., "[Codex]" for consistent log scanning
String Property Archive_Source Auto Const   ; • Source label, e.g., "[Region]" (identifies this system)

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