-- MonoForge — DaVinci Resolve 20
-- Bulk audio channel router for interview recordings
-- Workspace → Scripts → Utility → MonoForge

-- ── File logger (writes to Desktop so we can always see errors) ──────────
local LOG_PATH = os.getenv("HOME") .. "/Desktop/MonoForge.log"
local logFile  = io.open(LOG_PATH, "w")

local function flog(msg)
    local line = os.date("[%H:%M:%S] ") .. tostring(msg) .. "\n"
    if logFile then
        logFile:write(line)
        logFile:flush()
    end
end

flog("MonoForge starting")

-- ── Safe init ─────────────────────────────────────────────────────────────
local fusion, ui, disp

local ok, err = pcall(function()
    -- Try resolve:Fusion() first (DaVinci Resolve 18+)
    if resolve and resolve.Fusion then
        fusion = resolve:Fusion()
        flog("Got fusion via resolve:Fusion()")
    elseif fu then
        fusion = fu
        flog("Got fusion via fu global")
    else
        error("Could not find Fusion instance — resolve=" .. tostring(resolve) .. " fu=" .. tostring(fu))
    end

    ui   = fusion.UIManager
    disp = bmd.UIDispatcher(ui)
    flog("UIManager and dispatcher ready")
end)

if not ok then
    flog("FATAL: " .. tostring(err))
    if logFile then logFile:close() end
    return
end

-- ── Audio mapping helpers ──────────────────────────────────────────────────
local function makeMapping(ch)
    return string.format(
        '<AudioMapping version="1">' ..
        '<Track index="1">' ..
        '<AudioChannel type="L"><AudioSource>' ..
        '<AudioSourceEntry type="clip" channel="%d"/>' ..
        '</AudioSource></AudioChannel>' ..
        '<AudioChannel type="R"><AudioSource>' ..
        '<AudioSourceEntry type="clip" channel="%d"/>' ..
        '</AudioSource></AudioChannel>' ..
        '</Track></AudioMapping>',
        ch, ch
    )
end

local CH1 = makeMapping(1)
local CH2 = makeMapping(2)

local function getTimeline()
    local pm   = resolve:GetProjectManager()
    local proj = pm and pm:GetCurrentProject()
    return proj and proj:GetCurrentTimeline()
end

local function parseTracks(str)
    local tracks = {}
    for n in tostring(str):gmatch("%d+") do
        table.insert(tracks, tonumber(n))
    end
    return tracks
end

local function applyMapping(mapping, tracksStr, logFn)
    flog("applyMapping called, tracks=" .. tostring(tracksStr))
    local tl = getTimeline()
    if not tl then
        local msg = "Ingen timeline er åpen."
        flog("ERROR: " .. msg)
        logFn("❌  " .. msg)
        return
    end

    local tracks = parseTracks(tracksStr)
    if #tracks == 0 then
        local msg = "Skriv inn minst ett track-nummer."
        flog("ERROR: " .. msg)
        logFn("❌  " .. msg)
        return
    end

    local totalOk, totalFail = 0, 0
    for _, t in ipairs(tracks) do
        local items = tl:GetItemListInTrack("audio", t)
        flog("Track A" .. t .. " items: " .. tostring(items and #items or "nil"))
        if not items or not items[1] then
            logFn("  Track A" .. t .. ": ingen klipp — hopper over.")
        else
            local ok2, fail = 0, 0
            for _, item in ipairs(items) do
                local r = item:SetAudioMapping(mapping)
                flog("  " .. item:GetName() .. " → SetAudioMapping = " .. tostring(r))
                if r then ok2 = ok2 + 1 else fail = fail + 1 end
            end
            logFn(string.format("  Track A%d: %d ok, %d feilet (%d klipp)", t, ok2, fail, ok2 + fail))
            totalOk   = totalOk   + ok2
            totalFail = totalFail + fail
        end
    end
    logFn(string.format("✅  Ferdig — %d oppdatert, %d feilet.", totalOk, totalFail))
    flog("applyMapping done: ok=" .. totalOk .. " fail=" .. totalFail)
end

local function debugClip(trackStr, logFn)
    local tl = getTimeline()
    if not tl then logFn("❌  Ingen timeline.") return end
    local tracks = parseTracks(trackStr)
    local t = tracks[1] or 1
    local items = tl:GetItemListInTrack("audio", t)
    if not items or not items[1] then
        logFn("Ingen klipp på audio track " .. t)
        return
    end
    local item = items[1]
    local m = item:GetAudioMapping()
    logFn("Klipp: " .. tostring(item:GetName()))
    logFn("GetAudioMapping():\n" .. tostring(m))
    local r = item:SetAudioMapping(CH1)
    logFn("SetAudioMapping(Ch1) → " .. tostring(r))
    flog("debug: clip=" .. item:GetName() .. " mapping=" .. tostring(m) .. " set_result=" .. tostring(r))
end

-- ── Build UI ──────────────────────────────────────────────────────────────
flog("Building UI")

local ACCENT    = "#5B6BF5"
local BG        = "#1a1a1f"
local BG2       = "#25252d"
local TEXT      = "#e0e0f0"
local MUTED     = "#888899"
local SUCCESS   = "#3ecf8e"

local winOk, winErr = pcall(function()

win = disp:AddWindow({
    ID          = "MF",
    WindowTitle = "MonoForge",
    Geometry    = { 700, 300, 480, 500 },
    StyleSheet  = "background-color:" .. BG .. "; color:" .. TEXT .. ";",

    ui:VGroup{
        Spacing = 0,

        -- Header
        ui:Label{
            Text        = "  ⚡ MonoForge",
            StyleSheet  = string.format(
                "background-color:%s; color:#fff; font-size:18px; font-weight:bold;"
             .. "padding:14px 18px; letter-spacing:1px;", ACCENT),
            Weight      = 0,
        },

        ui:Label{
            Text        = "  Bulk-ruter stereo-klipp til mono per kanal",
            StyleSheet  = string.format(
                "background-color:%s; color:%s; font-size:11px; padding:6px 18px 10px 18px;",
                ACCENT, "rgba(255,255,255,0.7)"),
            Weight      = 0,
        },

        -- Body
        ui:VGroup{
            Spacing    = 12,
            StyleSheet = "padding:18px;",

            -- Ch1 row
            ui:VGroup{
                Spacing    = 4,
                Weight     = 0,
                StyleSheet = string.format(
                    "background-color:%s; border-radius:8px; padding:12px;", BG2),

                ui:Label{
                    Text       = "Channel 1  →  L + R",
                    StyleSheet = "font-size:13px; font-weight:bold; color:" .. TEXT .. ";",
                    Weight     = 0,
                },
                ui:HGroup{
                    Spacing = 8,
                    Weight  = 0,
                    ui:Label{
                        Text       = "Tracks:",
                        StyleSheet = "color:" .. MUTED .. "; font-size:12px;",
                        Weight     = 0,
                    },
                    ui:LineEdit{
                        ID          = "T1",
                        Text        = "1",
                        PlaceholderText = "f.eks.  1, 3, 5",
                        Weight      = 1,
                        StyleSheet  = string.format(
                            "background:#111118; color:%s; border:1px solid #333345;"
                         .. "border-radius:6px; padding:4px 8px; font-size:13px;", TEXT),
                    },
                    ui:Button{
                        ID         = "A1",
                        Text       = "Set Ch1 →",
                        Weight     = 0,
                        StyleSheet = string.format(
                            "background:%s; color:#fff; font-weight:bold;"
                         .. "border:none; border-radius:6px; padding:6px 16px;"
                         .. "font-size:13px;", ACCENT),
                    },
                },
            },

            -- Ch2 row
            ui:VGroup{
                Spacing    = 4,
                Weight     = 0,
                StyleSheet = string.format(
                    "background-color:%s; border-radius:8px; padding:12px;", BG2),

                ui:Label{
                    Text       = "Channel 2  →  L + R",
                    StyleSheet = "font-size:13px; font-weight:bold; color:" .. TEXT .. ";",
                    Weight     = 0,
                },
                ui:HGroup{
                    Spacing = 8,
                    Weight  = 0,
                    ui:Label{
                        Text       = "Tracks:",
                        StyleSheet = "color:" .. MUTED .. "; font-size:12px;",
                        Weight     = 0,
                    },
                    ui:LineEdit{
                        ID          = "T2",
                        Text        = "2",
                        PlaceholderText = "f.eks.  2, 4, 6",
                        Weight      = 1,
                        StyleSheet  = string.format(
                            "background:#111118; color:%s; border:1px solid #333345;"
                         .. "border-radius:6px; padding:4px 8px; font-size:13px;", TEXT),
                    },
                    ui:Button{
                        ID         = "A2",
                        Text       = "Set Ch2 →",
                        Weight     = 0,
                        StyleSheet = string.format(
                            "background:%s; color:#fff; font-weight:bold;"
                         .. "border:none; border-radius:6px; padding:6px 16px;"
                         .. "font-size:13px;", ACCENT),
                    },
                },
            },

            -- Debug row
            ui:HGroup{
                Spacing = 8,
                Weight  = 0,
                ui:Label{
                    Text       = "Debug track:",
                    StyleSheet = "color:" .. MUTED .. "; font-size:11px;",
                    Weight     = 0,
                },
                ui:LineEdit{
                    ID         = "DT",
                    Text       = "1",
                    Weight     = 0,
                    StyleSheet = string.format(
                        "background:#111118; color:%s; border:1px solid #333345;"
                     .. "border-radius:6px; padding:3px 8px; font-size:12px; max-width:60px;", TEXT),
                },
                ui:Button{
                    ID         = "DBG",
                    Text       = "Vis debug",
                    Weight     = 0,
                    StyleSheet = string.format(
                        "background:#333345; color:%s; border:none; border-radius:6px;"
                     .. "padding:4px 12px; font-size:11px;", MUTED),
                },
                ui:Button{
                    ID         = "OpenLog",
                    Text       = "Åpne log",
                    Weight     = 0,
                    StyleSheet = string.format(
                        "background:#333345; color:%s; border:none; border-radius:6px;"
                     .. "padding:4px 12px; font-size:11px;", MUTED),
                },
            },

            -- Log
            ui:TextEdit{
                ID         = "Log",
                ReadOnly   = true,
                PlainText  = "Klar. Log skrives også til: ~/Desktop/MonoForge.log\n",
                Weight     = 1,
                StyleSheet = string.format(
                    "background:#111118; color:%s; border:1px solid #333345;"
                 .. "border-radius:8px; padding:8px; font-size:11px; font-family:monospace;", TEXT),
            },

            ui:Button{
                ID         = "ClearLog",
                Text       = "Tøm log",
                Weight     = 0,
                StyleSheet = string.format(
                    "background:#1e1e28; color:%s; border:1px solid #333345;"
                 .. "border-radius:6px; padding:4px; font-size:11px;", MUTED),
            },
        },
    },
})

end)

if not winOk then
    flog("FATAL building UI: " .. tostring(winErr))
    if logFile then logFile:close() end
    return
end

flog("UI built successfully")

local itm = win:GetItems()

local function uiLog(msg)
    itm.Log.PlainText = itm.Log.PlainText .. msg .. "\n"
    flog("UI: " .. msg)
end

-- ── Event handlers ────────────────────────────────────────────────────────
win.On.A1.Clicked = function(ev)
    uiLog("\n▶ Set Ch1 på tracks: " .. itm.T1.Text)
    applyMapping(CH1, itm.T1.Text, uiLog)
end

win.On.A2.Clicked = function(ev)
    uiLog("\n▶ Set Ch2 på tracks: " .. itm.T2.Text)
    applyMapping(CH2, itm.T2.Text, uiLog)
end

win.On.DBG.Clicked = function(ev)
    uiLog("\n▶ Debug track: " .. itm.DT.Text)
    debugClip(itm.DT.Text, uiLog)
end

win.On.ClearLog.Clicked = function(ev)
    itm.Log.PlainText = ""
end

win.On.OpenLog.Clicked = function(ev)
    os.execute('open "' .. LOG_PATH .. '"')
end

win.On.MF.Close = function(ev)
    flog("Window closed")
    disp:ExitLoop()
end

flog("Starting event loop — window should be visible now")
win:Show()
win:Raise()
disp:RunLoop()
win:Hide()

flog("Script exiting cleanly")
if logFile then logFile:close() end
