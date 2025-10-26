ScriptName Codex:Lib_Region Hidden


; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
;  Lib_Region — Pure helpers for Region classification
;  Notes:
;   • Stateless, Global functions safe to call anywhere.
;   • Centralizes “Location matches a Region FormList” policy with kinship checks (direct, child-of, common-parent).
; ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                          REGION MEMBERSHIP HELPERS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Parent/kinship membership — checks direct match, child-of, or common-parent without walking
Bool Function Region_LocMatchesList(Location akLoc, FormList akList) Global
    ; • Guard
    If akLoc == None || akList == None
        Return False                                               ; · No membership
    EndIf

    ; • Scan the list: direct equality, child-of, or common-parent
    Int n = akList.GetSize()
    Int i = 0
    While i < n
        Location L = akList.GetAt(i) as Location                   ; · Safe cast
        If L != None
            If (akLoc == L)                                        ; · Exact match
                Return True
            EndIf
            If akLoc.IsChild(L)                                    ; · akLoc descends from L
                Return True
            EndIf
            If L.IsChild(akLoc)                                    ; · L descends from akLoc (broad cover)
                Return True
            EndIf
            If akLoc.HasCommonParent(L)                            ; · Share a parent; good enough for region grouping
                Return True
            EndIf
        EndIf
        i = i + 1
    EndWhile
    Return False                                                   ; · Not found by kinship
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝