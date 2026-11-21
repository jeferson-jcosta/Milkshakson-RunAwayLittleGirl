-- Options panel: Options > AddOns > Milkshakson > Run Away Little Girl
local _, ns = ...
local L = ns.L

function ns:BuildOptions(db)
    local UI = MilkshaksonUI
    if not UI then return end

    local p = UI:NewPanel("Run Away Little Girl", L.CFG_DESC)

    UI:Section(p, L.CFG_ACTIVATION)
    UI:Note(p, L.CFG_TRIGGER)
    UI:Check(p, L.CFG_RUNNING, L.CFG_RUNNING_TIP, function() return db.requireRunning end, function(v) db.requireRunning = v end)
    UI:Slider(p, L.CFG_SECS, 0, 10, 0.5, "%.1f s", function() return db.secs end, function(v) db.secs = v end, L.CFG_SECS_TIP)
    UI:Check(p, L.CFG_SOUND, L.CFG_SOUND_TIP, function() return db.sound end, function(v) db.sound = v end)
    UI:Buttons(p, { { L.CFG_WOLF_TRY, function() if ns.PlayWolf then ns.PlayWolf() end end } })
    UI:Check(p, L.CFG_LAUGH, L.CFG_LAUGH_TIP, function() return db.escapeLaugh end, function(v) db.escapeLaugh = v end)
    UI:Buttons(p, { { L.CFG_LAUGH_TRY, function() if ns.PlayLaugh then ns.PlayLaugh() end end } })

    UI:Section(p, L.CFG_MIRROR)
    UI:Check(p, L.CFG_LOCKED, L.CFG_LOCKED_TIP, function() return db.locked end, function(v) if ns.SetLocked then ns.SetLocked(v) end end)
    UI:Buttons(p, {
        { L.CFG_MOVE, function() SlashCmdList.RUNAWAYLITTLEGIRL("move") end, L.MOVE_ON },
        { function() return ns.IsTesting and ns.IsTesting() and L.CFG_STOP_TEST or L.CFG_TEST end,
          function() SlashCmdList.RUNAWAYLITTLEGIRL("test") end, L.TEST_ON },
        { L.CFG_RESET, function() SlashCmdList.RUNAWAYLITTLEGIRL("reset") end },
    })

    UI:Section(p, L.CFG_LANGUAGE)
    UI:Language(p, ns, db, nil, L.CFG_LANG_NOTE)

    UI:Support(p)

    ns.optionsPanel = p
    ns.optionsCategory = UI:Register(p, "Run Away Little Girl")
end

function ns:OpenOptions()
    if MilkshaksonUI then MilkshaksonUI:Open(ns.optionsCategory) end
end
