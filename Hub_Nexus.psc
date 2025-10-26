ScriptName Codex:Hub_Nexus Extends Quest


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                          TIME SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ════════════ Time Signals ═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Core Time (per in-game minute) =========================================================================================

Int Time_Minute         ; • 0..59 – current minute of the hour
Int Time_Hour           ; • 0..23 – current hour of the day
Int Time_MinuteOfDay    ; • 0..1439 – minutes since today’s 00:00

; === Calendar (update on day/hour edges) ====================================================================================

Int Time_DayOfMonth    ; • 1..31 – day number in the month
Int Time_Month         ; • 1..12 – month number
Int Time_Year          ; • civil year (e.g., 2287)
Int Time_DayOfWeek     ; • 0..6 – 0 = Sun .. 6 = Sat
Int Time_WeekOfYear    ; • 1..53 – week number of the year
Int Time_DayOfYear     ; • 1..365 – day number in the year

; === Monotonic Indices (stable counters) ====================================================================================

Int Time_WorldMinuteIndex    ; • ≥0 – absolute minute counter since epoch
Int Time_WorldDayIndex       ; • ≥0 – absolute day counter since epoch

; === Edges & Diagnostics ====================================================================================================

Int Time_EdgeMask    ; • bit0 = newMinute, bit1 = newHour, bit2 = newDay, bit3 = newWeek, bit4 = newMonth, bit5 = newYear
Int Time_Stamp       ; • increments whenever Time publishes new values

; === Time Edge Bit Indexes (services read these) ============================================================================

Int Property Time_Edge_Minute = 0 Auto Const    ; • 1<<0 = minute edge
Int Property Time_Edge_Hour   = 1 Auto Const    ; • 1<<1 = hour edge
Int Property Time_Edge_Day    = 2 Auto Const    ; • 1<<2 = day edge
Int Property Time_Edge_Week   = 3 Auto Const    ; • 1<<3 = week edge
Int Property Time_Edge_Month  = 4 Auto Const    ; • 1<<4 = month edge
Int Property Time_Edge_Year   = 5 Auto Const    ; • 1<<5 = year edge

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Core Time (per in-game minute) =========================================================================================

; ● Current minute of the hour (0..59)
Int Function GetTime_Minute()
    Return Time_Minute
EndFunction

; ● Current hour of the day (0..23)
Int Function GetTime_Hour()
    Return Time_Hour
EndFunction

; ● Minutes since today’s 00:00 (0..1439)
Int Function GetTime_MinuteOfDay()
    Return Time_MinuteOfDay
EndFunction

; === Calendar (update on day/hour edges) ====================================================================================

; ● Day number in the month (1..31)
Int Function GetTime_DayOfMonth()
    Return Time_DayOfMonth
EndFunction

; ● Month number (1..12)
Int Function GetTime_Month()
    Return Time_Month
EndFunction

; ● Civil calendar year (e.g., 2287)
Int Function GetTime_Year()
    Return Time_Year
EndFunction

; ● Day of week (0 = Sun .. 6 = Sat)
Int Function GetTime_DayOfWeek()
    Return Time_DayOfWeek
EndFunction

; ● Week number of the year (1..53)
Int Function GetTime_WeekOfYear()
    Return Time_WeekOfYear
EndFunction

; ● Day number in the year (1..365)
Int Function GetTime_DayOfYear()
    Return Time_DayOfYear
EndFunction

; === Monotonic Indices (stable counters) ====================================================================================

; ● Absolute minute counter since epoch (≥0)
Int Function GetTime_WorldMinuteIndex()
    Return Time_WorldMinuteIndex
EndFunction

; ● Absolute day counter since epoch (≥0)
Int Function GetTime_WorldDayIndex()
    Return Time_WorldDayIndex
EndFunction

; === Edges & Diagnostics ====================================================================================================

; ● One-tick time events packed as bits (minute/hour/day/week/month/year)
Int Function GetTime_EdgeMask()
    Return Time_EdgeMask
EndFunction

; ● Change stamp for time data (increments on publish)
Int Function GetTime_Stamp()
    Return Time_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Time Event Bus (Push) ══════════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Time    ; • Time service publish ping (minute/hour/day edges available via getters)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Time publish
Bool Function Event_Register_Time(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Time", "Time")
EndFunction

; ● Unregister a listener for Time publish
Bool Function Event_Unregister_Time(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Time", "Time")
EndFunction

; ● Notify all Time listeners (no payload — readers pull getters)
Int Function Event_Notify_Time()
    Return Event_Notify("Event_Publish_Time", "Time")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Time Signals ═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● TIME — single write gate: atomically update the Time snapshot and bump the change-stamp
Function Write_Time(Int aiMinute, Int aiHour, Int aiMinuteOfDay, Int aiDayOfMonth, Int aiMonth, Int aiYear, Int aiDayOfWeek, Int aiWeekOfYear, Int aiDayOfYear, Int aiWorldMinuteIndex, Int aiWorldDayIndex, Int aiEdgeMask)
    ; • Assign snapshot coherently (readers see either old or new, never a mix)
    Time_Minute             = aiMinute              ; · 0..59
    Time_Hour               = aiHour                ; · 0..23
    Time_MinuteOfDay        = aiMinuteOfDay         ; · 0..1439

    Time_DayOfMonth         = aiDayOfMonth          ; · 1..31
    Time_Month              = aiMonth               ; · 1..12
    Time_Year               = aiYear                ; · civil year

    Time_DayOfWeek          = aiDayOfWeek           ; · 0..6 (per your baseline)
    Time_WeekOfYear         = aiWeekOfYear          ; · 1..53
    Time_DayOfYear          = aiDayOfYear           ; · 1..365

    Time_WorldMinuteIndex   = aiWorldMinuteIndex    ; · ≥ 0 (epoch minutes)
    Time_WorldDayIndex      = aiWorldDayIndex       ; · ≥ 0 (epoch days)
    Time_EdgeMask           = aiEdgeMask            ; · bit0 = Minute, bit1 = Hour, bit2 = Day, bit3 = Week, bit4 = Month, bit5 = Year

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Time_Stamp = Time_Stamp + 1

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Time - commit. MOD=" + aiMinuteOfDay + " DoM=" + aiDayOfMonth + " Mo=" + aiMonth + " Yr=" + aiYear + " DoW=" + aiDayOfWeek + " Wk=" + aiWeekOfYear + " DoY=" + aiDayOfYear + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                         SOLAR SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Solar Signals ══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Daylight Timing (minute-of-day) ========================================================================================

Int Solar_SunriseMinute      ; • 0..1439 – today’s sunrise time
Int Solar_SunsetMinute       ; • 0..1439 – today’s sunset time
Int Solar_SolarNoonMinute    ; • 0..1439 – today’s solar noon time

; === Edges & Diagnostics ====================================================================================================

Int Solar_EdgeMask    ; • bit0 = sunriseNow, bit1 = sunsetNow, bit2 = noonNow
Int Solar_Stamp       ; • increments whenever Solar publishes new values

; === Solar Edge Bit Indexes (services read these) ===========================================================================

Int Property Solar_Edge_Sunrise   = 0 Auto Const    ; • 1<<0 = sunrise pulse
Int Property Solar_Edge_Sunset    = 1 Auto Const    ; • 1<<1 = sunset pulse
Int Property Solar_Edge_SolarNoon = 2 Auto Const    ; • 1<<2 = solar-noon pulse

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Daylight Timing (minute-of-day) ========================================================================================

; ● Today’s sunrise time as minute-of-day (0..1439, −1 if N/A)
Int Function GetSolar_SunriseMinute()
    Return Solar_SunriseMinute
EndFunction

; ● Today’s sunset time as minute-of-day (0..1439, −1 if N/A)
Int Function GetSolar_SunsetMinute()
    Return Solar_SunsetMinute
EndFunction

; ● Today’s solar noon time as minute-of-day (0..1439, −1 if N/A)
Int Function GetSolar_SolarNoonMinute()
    Return Solar_SolarNoonMinute
EndFunction

; === Edges & Diagnostics ====================================================================================================

; ● One-tick solar events packed as bits (sunrise/sunset/noon)
Int Function GetSolar_EdgeMask()
    Return Solar_EdgeMask
EndFunction

; ● Change stamp for solar data (increments on publish)
Int Function GetSolar_Stamp()
    Return Solar_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Solar Event Bus (Push) ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Solar    ; • Solar service publish ping (sunrise/sunset/noon computed)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Solar publish
Bool Function Event_Register_Solar(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Solar", "Solar")
EndFunction

; ● Unregister a listener for Solar publish
Bool Function Event_Unregister_Solar(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Solar", "Solar")
EndFunction

; ● Notify all Solar listeners (no payload — readers pull getters)
Int Function Event_Notify_Solar()
    Return Event_Notify("Event_Publish_Solar", "Solar")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Solar Signals ════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● SOLAR — single write gate: sunrise/sunset/noon and edges, then stamp bump
Function Write_Solar(Int aiSunriseMinuteOfDay, Int aiSunsetMinuteOfDay, Int aiSolarNoonMinuteOfDay, Int aiEdgeMask)
    
    ; • Assign as one unit to preserve snapshot coherence
    Solar_SunriseMinute   = aiSunriseMinuteOfDay      ; · 0..1439 or -1 if N/A
    Solar_SunsetMinute    = aiSunsetMinuteOfDay       ; · 0..1439 or -1 if N/A
    Solar_SolarNoonMinute = aiSolarNoonMinuteOfDay    ; · 0..1439 or -1 if N/A
    Solar_EdgeMask        = aiEdgeMask                ; · sunrise/noon/sunset edge pulses

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Solar_Stamp = Solar_Stamp + 1

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Solar - commit. riseMOD=" + aiSunriseMinuteOfDay + " noonMOD=" + aiSolarNoonMinuteOfDay + " setMOD=" + aiSunsetMinuteOfDay + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       LUNAR SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Lunar Signals ══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Phase (fine index; other forms derived in Lib_Lunar) ===================================================================

Int   Lunar_PhaseIndex    ; • 0..31 – fine-grained moon phase position

; === Edges & Diagnostics ====================================================================================================

Int   Lunar_EdgeMask    ; • bit0 = phaseChanged (reserve others for future)
Int   Lunar_Stamp       ; • increments whenever Lunar publishes new values

; === Lunar Edge Bit Indexes (services read these) ===========================================================================

Int Property Lunar_Edge_PhaseChange = 0 Auto Const    ; • 1<<0 = phase changed today

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Phase (fine index; other forms derived in Lib_Lunar) ===================================================================

; ● Fine-grained moon phase index (0..31)
Int Function GetLunar_PhaseIndex()
    Return Lunar_PhaseIndex
EndFunction

; === Edges & Diagnostics ====================================================================================================

; ● One-tick lunar events packed as bits (phaseChanged, reserved)
Int Function GetLunar_EdgeMask()
    Return Lunar_EdgeMask
EndFunction

; ● Change stamp for lunar data (increments on publish)
Int Function GetLunar_Stamp()
    Return Lunar_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Lunar Event Bus (Push) ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Lunar    ; • Lunar service publish ping (phase advanced)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Lunar publish
Bool Function Event_Register_Lunar(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Lunar", "Lunar")
EndFunction

; ● Unregister a listener for Lunar publish
Bool Function Event_Unregister_Lunar(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Lunar", "Lunar")
EndFunction

; ● Notify all Lunar listeners (no payload — readers pull getters)
Int Function Event_Notify_Lunar()
    Return Event_Notify("Event_Publish_Lunar", "Lunar")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Lunar Signals ════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● LUNAR — single write gate: phase index and edges, then stamp bump
Function Write_Lunar(Int aiPhaseIndex, Int aiEdgeMask)
    
    ; • Assign snapshot
    Lunar_PhaseIndex = aiPhaseIndex    ; · 0..31 (nexus granularity), or per your convention
    Lunar_EdgeMask   = aiEdgeMask      ; · phase change edges, quarter transitions, etc.

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Lunar_Stamp = Lunar_Stamp + 1

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Lunar - commit. phase=" + aiPhaseIndex + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                      SEASON SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Season Signals ═════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Season State (simple 4-season model) ===================================================================================
Int Season_Index           ; • 0 = Winter, 1 = Spring, 2 = Summer, 3 = Fall
Int Season_DayOfSeason     ; • 1..Season_DaysInSeason – day count within season
Int Season_DaysInSeason    ; • total days in the current season

; === Edges & Diagnostics ====================================================================================================

Int Season_EdgeMask    ; • bit0 = seasonChanged (reserve others for solstice/equinox/holiday)
Int Season_Stamp       ; • increments whenever Season publishes new values

; === Season Edge Bit Indexes (services read these) ==========================================================================

Int Property Season_Edge_SeasonStart = 0 Auto Const    ; • 1<<0 = season boundary today

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Season State (simple 4-season model) ===================================================================================

; ● Current season index (0 = Winter, 1 = Spring, 2 = Summer, 3 = Fall)
Int Function GetSeason_Index()
    Return Season_Index
EndFunction

; ● Day count within the current season (1..DaysInSeason)
Int Function GetSeason_DayOfSeason()
    Return Season_DayOfSeason
EndFunction

; ● Total days in the current season
Int Function GetSeason_DaysInSeason()
    Return Season_DaysInSeason
EndFunction

; === Edges & Diagnostics ====================================================================================================

; ● One-tick seasonal events packed as bits (seasonChanged, reserved)
Int Function GetSeason_EdgeMask()
    Return Season_EdgeMask
EndFunction

; ● Change stamp for seasonal data (increments on publish)
Int Function GetSeason_Stamp()
    Return Season_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Season Event Bus (Push) ════════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Season    ; • Season service publish ping (season boundary/daily tick)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Season publish
Bool Function Event_Register_Season(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Season", "Season")
EndFunction

; ● Unregister a listener for Season publish
Bool Function Event_Unregister_Season(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Season", "Season")
EndFunction

; ● Notify all Season listeners (no payload — readers pull getters)
Int Function Event_Notify_Season()
    Return Event_Notify("Event_Publish_Season", "Season")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Season Signals ═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● SEASON — single write gate: index/progress and edges, then stamp bump
Function Write_Season(Int aiSeasonIndex, Int aiDayOfSeason, Int aiDaysInSeason, Int aiEdgeMask)
    
    ; • Assign snapshot coherently
    Season_Index        = aiSeasonIndex     ; · 0..3 (0 = Winter, 1 = Spring, 2 = Summer, 3 = Fall)
    Season_DayOfSeason  = aiDayOfSeason     ; · 1..aiDaysInSeason
    Season_DaysInSeason = aiDaysInSeason    ; · >0
    Season_EdgeMask     = aiEdgeMask        ; · boundary/equinox/solstice per nexus convention

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Season_Stamp = Season_Stamp + 1

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Season - commit. sIdx=" + aiSeasonIndex + " day=" + aiDayOfSeason + "/" + aiDaysInSeason + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                        REGION SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Region Signals ═════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int Region_Index       ; • −1 = unknown, 0 = Northern Foothills, 1 = Blasted Forest, 2 = Coast, 3 = Downtown, 4 = Marsh, 5 = Glowing Sea
Int Region_EdgeMask    ; • bit0 = regionChanged (one-tick pulse on change)
Int Region_Stamp       ; • Increments whenever Region publishes

; === Region Edge Bit Indexes (services read these) ==========================================================================

Int Property Region_Edge_Changed = 0 Auto Const    ; • 1<<0 = region changed this event

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Current region index (−1 when unknown)
Int Function GetRegion_Index()
    Return Region_Index
EndFunction

; ● One-tick region edge bits (non-zero only during publish window)
Int Function GetRegion_EdgeMask()
    Return Region_EdgeMask
EndFunction

; ● Monotonic change-stamp for Region
Int Function GetRegion_Stamp()
    Return Region_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Region Event Bus (Push) ════════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Region    ; • Region service publish ping (fires only on true region change)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Region publish
Bool Function Event_Register_Region(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Region", "Region")
EndFunction

; ● Unregister a listener for Region publish
Bool Function Event_Unregister_Region(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Region", "Region")
EndFunction

; ● Notify all Region listeners (no payload — readers pull getters)
Int Function Event_Notify_Region()
    Return Event_Notify("Event_Publish_Region", "Region")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Region Signals ═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● REGION — single write gate: index + edges, then stamp bump
Function Write_Region(Int aiRegionIndex, Int aiEdgeMask)
    ; • Assign snapshot atomically so readers never see a mixed state
    Region_Index    = aiRegionIndex          ; · −1 when unknown
    Region_EdgeMask = aiEdgeMask             ; · bit0 = changed (one-tick pulse)

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Region_Stamp = Region_Stamp + 1

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Region - idx=" + aiRegionIndex + " edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       CLIMATE SIGNALS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Climate Signals ══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; === Snapshot (minute cadence) =================================================================================================

Int Climate_TemperatureC     ; • Ambient air temperature in °C (rounded Int)
Int Climate_Humidity         ; • Relative humidity 0..100 %
Int Climate_Wind             ; • Wind speed in deci-m/s (e.g., 25 = 2.5 m/s)

; === Edges & Diagnostics ======================================================================================================

Int Climate_EdgeMask         ; • bit0 = PrecipChanged, bit1 = BiomeChanged, bit2 = FrontShift, bit3 = WindGust
Int Climate_Stamp            ; • Increments whenever Climate publishes

; === Climate Edge Bit Indexes (services read these) ===========================================================================

Int Property Climate_Edge_PrecipChanged = 0 Auto Const   ; • 1<<0 precip on/off changed
Int Property Climate_Edge_BiomeChanged  = 1 Auto Const   ; • 1<<1 biome context changed
Int Property Climate_Edge_FrontShift    = 2 Auto Const   ; • 1<<2 |ΔTemp| exceeded threshold
Int Property Climate_Edge_WindGust      = 3 Auto Const   ; • 1<<3 gust spike detected

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Temperature (°C)
Int Function GetClimate_TemperatureC()
    Return Climate_TemperatureC
EndFunction

; ● Relative humidity (0..100 %)
Int Function GetClimate_Humidity()
    Return Climate_Humidity
EndFunction

; ● Wind speed (deci-m/s)
Int Function GetClimate_Wind()
    Return Climate_Wind
EndFunction

; ● Climate one-tick edges
Int Function GetClimate_EdgeMask()
    Return Climate_EdgeMask
EndFunction

; ● Climate change stamp
Int Function GetClimate_Stamp()
    Return Climate_Stamp
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Climate Event Bus (Push) ═══════════════════════════════════════════════════════════════════════════════════════════════════╗

CustomEvent Event_Publish_Climate

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Register a listener for Climate publish
Bool Function Event_Register_Climate(Form akListener)
    Return Event_Register(akListener, "Event_Publish_Climate", "Climate")
EndFunction

; ● Unregister a listener for Climate publish
Bool Function Event_Unregister_Climate(Form akListener)
    Return Event_Unregister(akListener, "Event_Publish_Climate", "Climate")
EndFunction

; ● Notify all Climate listeners (no payload — readers pull getters)
Int Function Event_Notify_Climate()
    Return Event_Notify("Event_Publish_Climate", "Climate")
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ══════ Write Climate Signals ══════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● CLIMATE — single write gate: atomically update snapshot and bump stamp
Function Write_Climate(Int aiTempC, Int aiRH_pct, Int aiWind_dMPS, Int aiEdgeMask)
    Climate_TemperatureC = aiTempC            ; · °C
    Climate_Humidity     = aiRH_pct           ; · 0..100
    Climate_Wind         = aiWind_dMPS        ; · deci-m/s
    Climate_EdgeMask     = aiEdgeMask         ; · edge pulses set by Svc_Climate

    ; • Bump monotonic change-stamp last (freshness test for consumers)
    Climate_Stamp        = Climate_Stamp + 1  ; · freshness last

    ; • Optional spam trace
    If Archive_Level >= 4
        Archive_Spam("Write_Climate - T=" + aiTempC + "C RH=" + aiRH_pct + "% W=" + aiWind_dMPS + "dMPS edge=" + aiEdgeMask + ".")
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                       SYSTEM CLOCK SERVICE
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ System Clock Service ═══════════════════════════════════════════════════════════════════════════════════════════════════════╗

Int Property Clock_Interval      = 1    Auto Const    ; • Game-time interval between clock ticks, in minutes

Int Property Clock_BaseYear      = 2287 Auto Const    ; • Civil calendar base year for the epoch (Fallout timeline)
Int Property Clock_BaseDayOfYear = 296  Auto Const    ; • 1..365 — day-of-year for Oct 23 (Jan = 31, Feb = 28 → Oct 23 = 296)
Int Property Clock_BaseDayOfWeek = 0    Auto Const    ; • Starting offset for calculating day-of-week (0 = Sunday baseline)

Int  Clock_TimerID        = 247 Const    ; • Unique timer identifier used for the System Clock loop
Bool Clock_Armed          = False        ; • TRUE when the System Clock is currently armed and active
Bool Clock_PublishEnabled = False        ; • TRUE after MQ102 gate met — allows Write_Time + Event_Notify

Int Clock_LastMinuteIndex    = -1    ; • Last recorded world-minute index, used for detecting minute-edge transitions
Int Clock_LastHourIndex      = -1    ; • Last recorded in-game hour, used for detecting hour-edge transitions
Int Clock_LastDayOfYearIndex = -1    ; • Last recorded world-day index, used for detecting day/week/month/year edges

Int[] Clock_MonthLengths    ; • Static array of month lengths for a fixed 365-day year (initialized once)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● System Clock Tick — minute cadence; computes time signals and publishes only when MQ102 gate is enabled
Event OnTimerGameTime(Int aiTimerID)
    ; • Validate the timer and ensure the System Clock is armed
    If aiTimerID != Clock_TimerID
        Return        ; · Ignore stray timer events
    EndIf
    If !Clock_Armed
        Return        ; · Exit if not armed
    EndIf

    ; • Gate: maintain cadence quietly until MQ102 gate is satisfied (no publishes)
    If !Clock_PublishEnabled
        StartTimerGameTime(Clock_Interval / 60.0, Clock_TimerID)    ; · Keep timer running quietly
        Return
    EndIf

    ; • Cache previous indices to detect edge transitions
    Int prevMinute    = Clock_LastMinuteIndex
    Int prevHour      = Clock_LastHourIndex
    Int prevDayOfYear = Clock_LastDayOfYearIndex

    ; • Read engine time primitives
    Float fDays          = Utility.GetCurrentGameTime()             ; · Absolute game time in days (fractional)
    Int   minuteIndex    = (fDays * 1440.0) as Int                  ; · Total elapsed in-game minutes
    Int   dayOfYearIndex = (fDays as Int)                           ; · Total elapsed in-game days
    Int   minuteOfDay    = minuteIndex - (dayOfYearIndex * 1440)    ; · 0–1439 minutes since 00:00
    Int   hourOfDay      = minuteOfDay / 60                         ; · 0–23 current hour
    Int   minuteOfHour   = minuteOfDay % 60                         ; · 0–59 current minute

    ; • Compute one-tick edge mask for minute/hour/day transitions
    Int edgeMask = 0
    edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Minute, (minuteIndex != prevMinute))
    edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Hour,   (hourOfDay   != prevHour))
    Bool dayChanged = (dayOfYearIndex != prevDayOfYear)
    edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Day, dayChanged)

    ; • Derive civil calendar fields anchored to the Fallout epoch (Oct 23, 2287) using a fixed 365-day year
    Int shiftedDayIndex = dayOfYearIndex + (Clock_BaseDayOfYear - 1)               ; · Align day 0 to Oct 23 instead of Jan 1
    Int dayOfYear       = Codex:Lib_Math.Math_WrapInt(shiftedDayIndex, 365) + 1    ; · 1–365 day-of-year via wrap
    Int civilYear       = (shiftedDayIndex / 365) + Clock_BaseYear                 ; · Year increases when day-of-year wraps
    Int civilMonth      = 1
    Int dayOfMonth      = 1

    ; • Resolve month and day by walking the 12-month length table
    Int remaining = dayOfYear
    Int i = 0
    While i < 12
        Int len = Clock_MonthLengths[i]
        If remaining <= len
            civilMonth = i + 1
            dayOfMonth = remaining
            i = 12        ; · Break loop once resolved
        Else
            remaining = remaining - len
            i = i + 1
        EndIf
    EndWhile

    ; • Compute day-of-week (civil-aligned) and week-of-year using Lib_Math for wrap safety
    Int dayOfWeek  = Codex:Lib_Math.Math_WrapInt(shiftedDayIndex + Clock_BaseDayOfWeek, 7)  ; · 0–6, 0 = Sunday
    Int weekOfYear = ((dayOfYear - 1) / 7) + 1                                              ; · 1–53 simple week blocks

    ; • Determine week/month/year edge transitions derived from day changes
    If dayChanged
        If dayOfWeek == 0
            edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Week,  True)      ; · Sunday = new week
        EndIf
        If dayOfMonth == 1
            edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Month, True)      ; · 1st = new month
            If dayOfYear == 1
                edgeMask = Codex:Lib_Math.Math_SetBit(edgeMask, Time_Edge_Year,  True)  ; · 1st day of year
            EndIf
        EndIf
    EndIf

    ; • Commit updated time snapshot atomically
    Write_Time(minuteOfHour, hourOfDay, minuteOfDay, dayOfMonth, civilMonth, civilYear, dayOfWeek, weekOfYear, dayOfYear, minuteIndex, dayOfYearIndex, edgeMask)

    ; • Broadcast “time updated” to all subscribed services (Solar, Lunar, Season)
    Event_Notify_Time()

    ; • Cache new values for the next edge comparison
    Clock_LastMinuteIndex    = minuteIndex
    Clock_LastHourIndex      = hourOfDay
    Clock_LastDayOfYearIndex = dayOfYearIndex

    ; • Re-arm next in-game minute tick
    StartTimerGameTime(Clock_Interval / 60.0, Clock_TimerID)
    Clock_Armed = True
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Initialize Month-Length Table — builds a static 12-month array for a fixed 365-day calendar (no leap years)
Function Clock_BuildMonthTable()
    ; • Skip initialization if the table already exists
    If Clock_MonthLengths != None
        Return        ; · Already initialized
    EndIf

    ; • Allocate and populate the month-length array
    Clock_MonthLengths = new Int[12]    ; · 12 entries representing months Jan – Dec
    Clock_MonthLengths[0]  = 31         ; · January
    Clock_MonthLengths[1]  = 28         ; · February
    Clock_MonthLengths[2]  = 31         ; · March
    Clock_MonthLengths[3]  = 30         ; · April
    Clock_MonthLengths[4]  = 31         ; · May
    Clock_MonthLengths[5]  = 30         ; · June
    Clock_MonthLengths[6]  = 31         ; · July
    Clock_MonthLengths[7]  = 31         ; · August
    Clock_MonthLengths[8]  = 30         ; · September
    Clock_MonthLengths[9]  = 31         ; · October
    Clock_MonthLengths[10] = 30         ; · November
    Clock_MonthLengths[11] = 31         ; · December
EndFunction

; ============================================================================================================================

; ● Arm the System Clock — activates the timer loop and optionally primes an immediate first tick (~1 in-game second)
Function Clock_ArmTimer(Bool abPrime, String asContext)
    ; • Ensure the clock is marked as active before arming
    If !Clock_Armed
        Clock_Armed = True        ; · Prevent duplicate arming
    EndIf

    ; • Determine timer duration based on prime flag
    Float hours
    If abPrime
        hours = 1.0 / 3600.0             ; · ~1 in-game second for immediate tick
    Else
        hours = Clock_Interval / 60.0    ; · Standard cadence (1-minute interval)
    EndIf

    ; • Arm the GameTime timer
    StartTimerGameTime(hours, Clock_TimerID)

    ; • Optional developer trace
    If Archive_Level >= 4
        String suffix = ""
        If abPrime
            suffix = " (prime)"    ; · Annotate prime arming in logs
        EndIf
        Archive_Spam("TimeClock - armed" + suffix + " [" + asContext + "].")  ; · Verbose trace
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                      SERVICE STARTUP / SHUTDOWN
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Service Start/Stop ═════════════════════════════════════════════════════════════════════════════════════════════════════════╗

Quest Property Service_Solar  Auto Const Mandatory   ; • Service quest: solar domain (sunrise/sunset/noon; not Start Game Enabled)
Quest Property Service_Lunar  Auto Const Mandatory   ; • Service quest: lunar domain (phase progression; not Start Game Enabled)
Quest Property Service_Season Auto Const Mandatory   ; • Service quest: season domain (4-season model; not Start Game Enabled)
Quest Property Service_Region Auto Const Mandatory   ; • Service quest: region domain ()

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Start all services (safe to call repeatedly; each service is started idempotently)
Function Service_StartAll()
    ; • Attempt start in forward order (no dependencies assumed)
    Service_StartOne(Service_Solar,  "Svc_Solar")     ; · Start Solar
    Service_StartOne(Service_Lunar,  "Svc_Lunar")     ; · Start Lunar
    Service_StartOne(Service_Season, "Svc_Season")    ; · Start Season
    Service_StartOne(Service_Region, "Svc_Region")    ; · Start Region

    ; • Emit summary after attempts
    If Archive_Level >= 4
        Archive_Spam("StartAll - attempted.")    ; · Post-state snapshot
    EndIf
EndFunction

; ============================================================================================================================

; ● Stop all services (reverse order for courtesy; still safe if no dependencies exist)
Function Service_StopAll()
    ; • Attempt stop in reverse order (defensive if future dependencies arise)
    Service_StopOne(Service_Region, "Svc_Region")     ; · Stop Region
    Service_StopOne(Service_Season, "Svc_Season")     ; · Stop Season
    Service_StopOne(Service_Lunar,  "Svc_Lunar")      ; · Stop Lunar
    Service_StopOne(Service_Solar,  "Svc_Solar")      ; · Stop Solar

    ; • Emit summary after attempts
    If Archive_Level >= 4
        Archive_Spam("StopAll - attempted.")    ; · Post-state snapshot
    EndIf
EndFunction

; ============================================================================================================================

; ● Start one service quest safely (null-safe, idempotent)
Function Service_StartOne(Quest aqSvc, String asName)
    ; • Validate input quest handle
    If aqSvc == None        ; · Guard missing quest property
        If Archive_Level >= 2
            Archive_Warn("StartService - missing; not installed? name=" + asName + ".")  ; · Informative warning for misconfigured setup
        EndIf
        Return              ; · Abort start
    EndIf

    ; • Exit early if already running
    If aqSvc.IsRunning()    ; · Avoid redundant Start()
        If Archive_Level >= 4
            Archive_Spam("StartService - already running. name=" + asName + ".")  ; · No-op path
        EndIf
        Return              ; · Exit early
    EndIf
    
    ; • Attempt to start the quest
    If Archive_Level >= 4
        Archive_Spam("StartService - starting. name=" + asName + ".")        ; · Pre-start trace
    EndIf
    Bool ok = aqSvc.Start()                                                  ; · Invoke quest start
    If ok
        If Archive_Level >= 3
            Archive_Info("StartService - " + asName + " started.")           ; · Success path
        EndIf
    Else
        If Archive_Level >= 1
            Archive_Error("StartService - FAILED to start " + asName + ".")  ; · Failure path
        EndIf
    EndIf
EndFunction

; ============================================================================================================================

; ● Stop one service quest safely (null-safe, idempotent)
Function Service_StopOne(Quest aqSvc, String asName)
    ; • Validate input quest handle
    If aqSvc == None        ; · Guard missing quest property
        If Archive_Level >= 4
            Archive_Spam("StopService - handle=None. name=" + asName + ".")  ; · No-op when not configured
        EndIf
        Return              ; · Exit early
    EndIf

    ; • Stop if running
    If aqSvc.IsRunning()    ; · Only stop active quests
        aqSvc.Stop()                                               ; · Attempt quest stop
        If Archive_Level >= 3
            Archive_Info("StopService - " + asName + " stopped.")  ; · Success path
        EndIf
    Else
        If Archive_Level >= 4
            Archive_Spam("StopService - not running. name=" + asName + ".")  ; · No-op when already stopped
        EndIf
    EndIf
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                              EVENT BUS
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Event Bus Registration ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Internal: register a listener for a specific custom event in Nexus
Bool Function Event_Register(Form akListener, String asEventName, String asTag)
    ; • Validate listener
    If akListener == None
        If Archive_Level >= 2
            Archive_Warn("Event_Register - invalid listener=None. tag=" + asTag + ".")  ; · Defensive logging
        EndIf
        Return False
    EndIf

    ; • Dispatch based on known event name (FO4 Papyrus requires literal event identifiers)
    If asEventName == "Event_Publish_Time"
        akListener.RegisterForCustomEvent(Self, "Event_Publish_Time")
    ElseIf asEventName == "Event_Publish_Solar"
        akListener.RegisterForCustomEvent(Self, "Event_Publish_Solar")
    ElseIf asEventName == "Event_Publish_Lunar"
        akListener.RegisterForCustomEvent(Self, "Event_Publish_Lunar")
    ElseIf asEventName == "Event_Publish_Season"
        akListener.RegisterForCustomEvent(Self, "Event_Publish_Season")
    ElseIf asEventName == "Event_Publish_Region"
        akListener.RegisterForCustomEvent(Self, "Event_Publish_Region")
    Else
        If Archive_Level >= 2
            Archive_Warn("Event_Register - unknown event. tag=" + asTag + " event=" + asEventName + ".")  ; · Unsupported event
        EndIf
        Return False
    EndIf

    ; • Telemetry confirmation
    If Archive_Level >= 3
        Archive_Info("Event_Register - tag=" + asTag + " event=" + asEventName + ".")  ; · Log success
    EndIf
    Return True
EndFunction

; ============================================================================================================================

; ● Internal: unregister a listener for a specific custom event in Nexus
Bool Function Event_Unregister(Form akListener, String asEventName, String asTag)
    ; • Validate listener
    If akListener == None    ; · Guard invalid listener
        If Archive_Level >= 4
            Archive_Spam("Event_Unregister - invalid listener=None. tag=" + asTag + ".")  ; · Low-noise note
        EndIf
        Return False         ; · Reject
    EndIf

    ; • Dispatch based on known event name (FO4 Papyrus requires a raw string literal, not a variable)
    If asEventName == "Event_Publish_Time"
        akListener.UnregisterForCustomEvent(Self, "Event_Publish_Time")
    ElseIf asEventName == "Event_Publish_Solar"
        akListener.UnregisterForCustomEvent(Self, "Event_Publish_Solar")
    ElseIf asEventName == "Event_Publish_Lunar"
        akListener.UnregisterForCustomEvent(Self, "Event_Publish_Lunar")
    ElseIf asEventName == "Event_Publish_Season"
        akListener.UnregisterForCustomEvent(Self, "Event_Publish_Season")
    ElseIf asEventName == "Event_Publish_Region"
        akListener.UnregisterForCustomEvent(Self, "Event_Publish_Region")
    Else
        If Archive_Level >= 2
            Archive_Warn("Event_Unregister - unknown event. tag=" + asTag + " event=" + asEventName + ".") ; · Unsupported event
        EndIf
        Return False        ; · Reject
    EndIf

    ; • Telemetry confirmation
    If Archive_Level >= 3
        Archive_Info("Event_Unregister - tag=" + asTag + " event=" + asEventName + ".")  ; · Confirmation
    EndIf
    Return True             ; · OK
EndFunction

; ============================================================================================================================

; ● Internal: notify all listeners (no payload for hot paths — listeners pull from Nexus getters)
Int Function Event_Notify(String asEventName, String asTag)
    ; • Validate event name (must match a known literal; FO4 Papyrus forbids variable event names)
    If asEventName == ""        ; · Guard: empty event name
        If Archive_Level >= 1
            Archive_Error("Event_Notify - missing event name. tag=" + asTag + ".")  ; · Error: cannot notify without a name
        EndIf
        Return -1               ; · Fail
    EndIf

    ; • Dispatch using compile-time literals (FO4 requires raw strings for SendCustomEvent)
    If asEventName == "Event_Publish_Time"
        SendCustomEvent("Event_Publish_Time")      ; · Broadcast Time ping (no payload)
    ElseIf asEventName == "Event_Publish_Solar"
        SendCustomEvent("Event_Publish_Solar")     ; · Broadcast Solar ping (no payload)
    ElseIf asEventName == "Event_Publish_Lunar"
        SendCustomEvent("Event_Publish_Lunar")     ; · Broadcast Lunar ping (no payload)
    ElseIf asEventName == "Event_Publish_Season"
        SendCustomEvent("Event_Publish_Season")    ; · Broadcast Season ping (no payload)
    ElseIf asEventName == "Event_Publish_Region"
        SendCustomEvent("Event_Publish_Region")    ; · Broadcast Region ping (no payload)
    Else
        If Archive_Level >= 2
            Archive_Warn("Event_Notify - unknown event. tag=" + asTag + " event=" + asEventName + ".") ; · Unsupported event
        EndIf
        Return -1               ; · Fail
    EndIf

    ; • Telemetry (kept at SPAM to avoid noise)
    If Archive_Level >= 4
        Archive_Spam("Event_Notify - event=" + asEventName + ". tag=" + asTag + ".")  ; · Confirmation of dispatch
    EndIf
    Return 1                    ; · Success
EndFunction

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


; ========================================================================================================================================
; ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
; ║                                                      NEXUS INITIALIZATION
; ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ========================================================================================================================================


; ══════ Initialization Routine ═════════════════════════════════════════════════════════════════════════════════════════════════════╗

Actor Property Link_Player    Auto Const Mandatory    ; • Player actor reference used for event wiring and context linkage
Quest Property Link_GateQuest Auto Const Mandatory    ; • Vanilla MQ102 quest handle used as world-state gate for safe bring-up

Bool Link_Nexus_HooksWired = False     ; • Guard flag: TRUE after remote-event subscriptions are completed once

Int Link_Clock_GateStage = 10 Const    ; • Stage number on MQ102 required before boot (prevents premature start)

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Quest Initialization — wires events, starts services, and arms the System Clock (publishing gated by MQ102)
Event OnQuestInit()
    ; • Begin Nexus initialization
    If Archive_Level >= 3
        Archive_Info("OnQuestInit - initializing Hub_Nexus and services.")  ; · Entry point for Nexus startup
    EndIf

    Link_Nexus_WireHooks()        ; · Wire remote events (player load + MQ102 gate)
    Clock_BuildMonthTable()       ; · Ensure month table exists for 365-day calendar

    ; • Start dependent services early — they idle until first publish
    Service_StartAll()        ; · Start Solar/Lunar/Season safely

    ; • Determine publish gate state (safe for mid-playthrough installs)
    Clock_PublishEnabled = Link_GateQuest && Link_GateQuest.GetStageDone(Link_Clock_GateStage)

    ; • Arm the System Clock timer at standard cadence (publishing will still be gated)
    Clock_ArmTimer(False, "QuestInit")

    ; • Log state summary
    If Archive_Level >= 3
        Archive_Info("OnQuestInit - clock armed; publishEnabled=" + Clock_PublishEnabled + ".")
    EndIf
EndEvent

; ============================================================================================================================

; ● Player Load — re-wire events, rebuild calendar table, and re-arm the System Clock (publishing gated by MQ102)
Event Actor.OnPlayerLoadGame(Actor akSender)
    ; • Load-time reinit entry
    If Archive_Level >= 3
        Archive_Info("OnPlayerLoadGame - re-establishing links and cadence.")  ; · Log entry point
    EndIf

    Link_Nexus_WireHooks()         ; · Ensure remote events are wired
    Clock_BuildMonthTable()        ; · Ensure 365-day month table exists

    ; • GameTime timers are not serialized — clear and re-arm
    Clock_Armed = False        ; · Explicitly drop armed guard

    ; • Re-evaluate MQ102 gate on this save (mid-playthrough safe)
    Clock_PublishEnabled = Link_GateQuest && Link_GateQuest.GetStageDone(Link_Clock_GateStage)

    ; • Re-arm the System Clock at standard cadence (publishing may remain gated)
    Clock_ArmTimer(False, "LoadGame")

    ; • State summary
    If Archive_Level >= 3
        Archive_Info("OnPlayerLoadGame - clock re-armed; publishEnabled=" + Clock_PublishEnabled + ".")
    EndIf
EndEvent

; ============================================================================================================================

; ● Gate Trip (MQ102) — enable publishing and prime a near-immediate clock tick
Event Quest.OnStageSet(Quest akSender, Int auiStageID, Int auiItemID)
    ; • Validate source and required stage threshold
    If (akSender == Link_GateQuest) && (auiStageID >= Link_Clock_GateStage)
        ; • Trip the gate if not yet enabled
        If !Clock_PublishEnabled
            Clock_PublishEnabled = True         ; · Allow Write_Time + Event_Notify_Time
            If Archive_Level >= 3
                Archive_Info("GateTrip - MQ102 satisfied; enabling clock publishing and priming first tick.")
            EndIf

            Clock_BuildMonthTable()             ; · Ensure month table exists before ticking
            Clock_ArmTimer(True, "PostGate")    ; · Prime near-immediate tick (~1 in-game second)
        ElseIf Archive_Level >= 4
            Archive_Spam("GateTrip - already enabled; skipping duplicate trip.")  ; · No-op on repeat
        EndIf

        ; • Optional cleanup — we no longer need to listen for further stage changes
        UnregisterForRemoteEvent(Link_GateQuest, "OnStageSet")
    ElseIf Archive_Level >= 4
        Archive_Spam("OnStageSet - ignored (not our gate or below threshold).")   ; · Irrelevant stage/source
    EndIf
EndEvent

; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
; ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗

; ● Establishes remote event subscriptions — runs only once per session
Function Link_Nexus_WireHooks()
    ; • Verify if hooks have already been wired
    If !Link_Nexus_HooksWired
        ; • Register remote events for player load and MQ102 stage gate
        If Archive_Level >= 4
            Archive_Spam("Link_Nexus_WireHooks - registering remote events.")  ; · Log registration phase
        EndIf

        RegisterForRemoteEvent(Link_Player, "OnPlayerLoadGame")    ; · Player load event subscription
        RegisterForRemoteEvent(Link_GateQuest, "OnStageSet")      ; · MQ102 stage event subscription

        ; • Self-subscription removed — Hub does not need to hear its own Time publish
        Link_Nexus_HooksWired = True    ; · Mark wiring as complete

        If Archive_Level >= 3
            Archive_Info("Link_Nexus_WireHooks - hooks wired: Player.OnPlayerLoadGame, MQ102.OnStageSet.")  ; · Confirmation
        EndIf
    Else
        ; • Hooks already wired — no further action needed
        If Archive_Level >= 4
            Archive_Spam("Link_Nexus_WireHooks - already wired; skipping.")  ; · Idempotent no-op
        EndIf
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
String Property Archive_Source Auto Const   ; • Source label, e.g., "[Nexus]" (identifies this system)

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