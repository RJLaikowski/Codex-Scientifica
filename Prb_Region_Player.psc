ScriptName Codex:Prb_Region_Player Extends ReferenceAlias


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                        PLAYER ALIAS FOR REGION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Forward — gather current parent cell and current location, then notify Svc_Region
Function Forward()
    ; • Resolve subject reference and compute current context
    ObjectReference r = GetReference()                                  ; · Player reference from this alias
    If r == None
        Return                                                          ; · Guard: alias not filled yet
    EndIf
    Cell     c = r.GetParentCell()                                      ; · Current parent cell (may be None in edge cases)
    Location l = r.GetCurrentLocation()                                 ; · Current location (may be None in wilderness)

    ; • Cast owning quest to the Region service and forward both cell and location
    Quest q = GetOwningQuest()                                          ; · Owning quest for this alias
    Codex:Svc_Region svc = q as Codex:Svc_Region                        ; · Service handle (same quest)
    If svc != None
        svc.Region_Publish(c, l)                                        ; · Pass context to service (location-first resolver)
    EndIf
EndFunction

; ============================================================================================================================

; ● On Cell Attach — fires whenever the player enters a new parent cell; forward context
Event OnCellAttach()
    ; • Forward the latest context to the Region service
    Forward()                                                           ; · Single hop to service
EndEvent

; ============================================================================================================================

; ● On Location Change — redundancy for larger transitions or edge cases; forward context
Event OnLocationChange(Location akOldLoc, Location akNewLoc)
    ; • Forward the latest context to the Region service
    Forward()                                                           ; · Service de-dupes if cell didn’t actually change
EndEvent

; ============================================================================================================================

; ● On Player Load Game — ensure Hub has a region immediately after load; forward context
Event OnPlayerLoadGame()
    ; • Forward the latest context to the Region service
    Forward()                                                           ; · Prime state after load
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝