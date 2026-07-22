#Requires AutoHotkey v2.0
#SingleInstance Force

global gGui := 0
global gLV := 0
global gStatus := 0
global gEdFilter := 0
global gChkAppsOnly := 0
global gChkAuto := 0
global gEdInterval := 0
global gBtnRefresh := 0
global gBtnShowSel := 0
global gBtnShowAll := 0

global gAllWindows := []
global gRowToHwnd := Map()
global gScanBusy := false

global gLblFilter := 0
global gLblCo := 0
global gLblS := 0
global gBtnLang := 0

global gLang := "pl"
global TR := Map(
    "pl", Map(
        "title", "Whim Hidden Window Rescue+",
        "filter", "Filtr:",
        "appsOnly", "Tylko prawdziwe okna aplikacji",
        "auto", "Auto-odświeżanie",
        "co", "co",
        "s", "s",
        "colHwnd", "HWND",
        "colTitle", "Tytuł",
        "colProcess", "Proces",
        "colClass", "Klasa",
        "colPid", "PID",
        "colFlags", "Flagi",
        "btnRefresh", "Skanuj",
        "btnShowSel", "Pokaż zaznaczone",
        "btnShowAll", "Pokaż wszystkie z listy",
        "btnLang", "EN",
        "statusFormat", "Ukryte łącznie: {1} | Na liście: {2}",
        "dash", "—"
    ),
    "en", Map(
        "title", "Whim Hidden Window Rescue+",
        "filter", "Filter:",
        "appsOnly", "Real application windows only",
        "auto", "Auto-refresh",
        "co", "every",
        "s", "s",
        "colHwnd", "HWND",
        "colTitle", "Title",
        "colProcess", "Process",
        "colClass", "Class",
        "colPid", "PID",
        "colFlags", "Flags",
        "btnRefresh", "Scan",
        "btnShowSel", "Show selected",
        "btnShowAll", "Show all listed",
        "btnLang", "PL",
        "statusFormat", "Hidden total: {1} | Listed: {2}",
        "dash", "—"
    )
)

T(key) {
    global gLang, TR
    return TR[gLang][key]
}

BuildGui()
ScanAndRefresh()

BuildGui() {
    global gGui, gLV, gStatus, gEdFilter, gChkAppsOnly, gChkAuto, gEdInterval
    global gBtnRefresh, gBtnShowSel, gBtnShowAll
    global gLblFilter, gLblCo, gLblS, gBtnLang

    gGui := Gui("+Resize", T("title"))
    gGui.SetFont("s9", "Segoe UI")

    gLblFilter := gGui.Add("Text", "xm ym+4", T("filter"))
    gEdFilter := gGui.Add("Edit", "x+6 yp-2 w280")

    gChkAppsOnly := gGui.Add("CheckBox", "x+12 yp+2 Checked", T("appsOnly"))
    gChkAuto := gGui.Add("CheckBox", "x+18 yp", T("auto"))
    gLblCo := gGui.Add("Text", "x+10 yp+3", T("co"))
    gEdInterval := gGui.Add("Edit", "x+4 yp-3 w40 Number Limit4", "3")
    gLblS := gGui.Add("Text", "x+4 yp+3", T("s"))
    gBtnLang := gGui.Add("Button", "x+14 yp-3 w40", T("btnLang"))

    gLV := gGui.Add("ListView", "xm y+10 w1180 r22 Grid", [T("colHwnd"), T("colTitle"), T("colProcess"), T("colClass"), T("colPid"), T("colFlags")])
    gLV.ModifyCol(1, 150)
    gLV.ModifyCol(2, 360)
    gLV.ModifyCol(3, 180)
    gLV.ModifyCol(4, 200)
    gLV.ModifyCol(5, 80)
    gLV.ModifyCol(6, 180)

    gBtnRefresh := gGui.Add("Button", "xm y+10 w120 Default", T("btnRefresh"))
    gBtnShowSel := gGui.Add("Button", "x+10 w180", T("btnShowSel"))
    gBtnShowAll := gGui.Add("Button", "x+10 w220", T("btnShowAll"))

    gStatus := gGui.Add("Text", "xm y+10 w1180", "")

    gEdFilter.OnEvent("Change", OnFilterChanged)
    gChkAppsOnly.OnEvent("Click", OnAppsOnlyChanged)
    gChkAuto.OnEvent("Click", OnAutoRefreshToggle)
    gEdInterval.OnEvent("Change", OnIntervalChanged)

    gBtnRefresh.OnEvent("Click", ScanAndRefresh)
    gBtnShowSel.OnEvent("Click", ShowSelected)
    gBtnShowAll.OnEvent("Click", ShowAllListed)
    gBtnLang.OnEvent("Click", ToggleLanguage)
    gLV.OnEvent("DoubleClick", ShowDoubleClicked)

    gGui.OnEvent("Close", GuiClose)
    gGui.OnEvent("Size", GuiSize)
    gGui.Show()
}

ToggleLanguage(*) {
    global gLang
    gLang := (gLang = "pl") ? "en" : "pl"
    ApplyLanguage()
}

ApplyLanguage() {
    global gGui, gLblFilter, gChkAppsOnly, gChkAuto, gLblCo, gLblS
    global gBtnRefresh, gBtnShowSel, gBtnShowAll, gBtnLang, gLV

    gGui.Title := T("title")
    gLblFilter.Text := T("filter")
    gChkAppsOnly.Text := T("appsOnly")
    gChkAuto.Text := T("auto")
    gLblCo.Text := T("co")
    gLblS.Text := T("s")
    gBtnRefresh.Text := T("btnRefresh")
    gBtnShowSel.Text := T("btnShowSel")
    gBtnShowAll.Text := T("btnShowAll")
    gBtnLang.Text := T("btnLang")

    gLV.ModifyCol(1,, T("colHwnd"))
    gLV.ModifyCol(2,, T("colTitle"))
    gLV.ModifyCol(3,, T("colProcess"))
    gLV.ModifyCol(4,, T("colClass"))
    gLV.ModifyCol(5,, T("colPid"))
    gLV.ModifyCol(6,, T("colFlags"))

    ApplyFilter()
}

GuiClose(*) {
    SetTimer(AutoRefreshTick, 0)
    ExitApp()
}

GuiSize(guiObj, minMax, width, height) {
    global gLV, gStatus, gBtnRefresh, gBtnShowSel, gBtnShowAll

    ; Nie zmieniaj układu podczas minimalizacji.
    if (minMax = -1)
        return

    margin := 10
    buttonH := 28
    statusH := 20
    gap := 10

    statusY := height - margin - statusH
    buttonY := statusY - gap - buttonH

    ; ListView rozciąga się razem z oknem.
    listY := 65
    listH := buttonY - gap - listY

    if (listH < 50)
        listH := 50

    gLV.Move(,, width - 2 * margin, listH)

    gBtnRefresh.Move(margin, buttonY)
    gBtnShowSel.Move(margin + 130, buttonY)
    gBtnShowAll.Move(margin + 320, buttonY)

    gStatus.Move(margin, statusY, width - 2 * margin, statusH)
}

OnFilterChanged(*) {
    ApplyFilter()
}

OnAppsOnlyChanged(*) {
    ApplyFilter()
}

OnAutoRefreshToggle(*) {
    global gChkAuto
    SetTimer(AutoRefreshTick, 0)
    if gChkAuto.Value
        SetTimer(AutoRefreshTick, GetIntervalMs())
}

OnIntervalChanged(*) {
    global gChkAuto
    if gChkAuto.Value {
        SetTimer(AutoRefreshTick, 0)
        SetTimer(AutoRefreshTick, GetIntervalMs())
    }
}

AutoRefreshTick() {
    ScanAndRefresh()
}

GetIntervalMs() {
    global gEdInterval

    raw := Trim(gEdInterval.Value)
    if (raw = "") {
        seconds := 3
    } else {
        try seconds := Integer(raw)
        catch
            seconds := 3
    }

    if (seconds < 1)
        seconds := 1
    if (seconds > 3600)
        seconds := 3600

    gEdInterval.Value := seconds
    return seconds * 1000
}

ScanAndRefresh(*) {
    global gScanBusy
    if gScanBusy
        return

    gScanBusy := true
    try {
        ScanHiddenWindows()
        ApplyFilter()
    } finally {
        gScanBusy := false
    }
}

ScanHiddenWindows() {
    global gAllWindows
    gAllWindows := []

    visible := Map()
    prev := DetectHiddenWindows(false)

    try {
        for hwnd in WinGetList()
            visible[hwnd] := true

        DetectHiddenWindows(true)

        for hwnd in WinGetList() {
            if visible.Has(hwnd)
                continue

            info := GetWindowInfo(hwnd)
            if info
                gAllWindows.Push(info)
        }
    } finally {
        DetectHiddenWindows(prev)
    }
}

GetWindowInfo(hwnd) {
    title := SafeWinGetTitle(hwnd)
    proc := SafeWinGetProcessName(hwnd)
    cls := SafeWinGetClass(hwnd)
    pid := SafeWinGetPID(hwnd)

    if (title = "" && proc = "" && cls = "")
        return 0

    style := SafeGetStyle(hwnd)
    exStyle := SafeGetExStyle(hwnd)
    owner := SafeGetOwner(hwnd)
    cloaked := IsWindowCloaked(hwnd)

    appLike := IsAppLikeWindow(hwnd, title, proc, cls, style, exStyle, owner)
    flags := BuildFlags(appLike, cloaked, exStyle, owner)

    return {
        hwnd: hwnd,
        title: title,
        proc: proc,
        cls: cls,
        pid: pid,
        style: style,
        exStyle: exStyle,
        owner: owner,
        cloaked: cloaked,
        appLike: appLike,
        flags: flags
    }
}

ApplyFilter(*) {
    global gLV, gStatus, gAllWindows, gEdFilter, gChkAppsOnly, gRowToHwnd

    gLV.Opt("-Redraw")
    try {
        gLV.Delete()
        gRowToHwnd := Map()

        shown := 0
        needle := StrLower(Trim(gEdFilter.Value))
        appsOnly := (gChkAppsOnly.Value = 1)

        for item in gAllWindows {
            if appsOnly && !item.appLike
                continue

            if (needle != "") {
                hay := StrLower(item.title " " item.proc " " item.cls " " item.pid " " item.flags)
                if !InStr(hay, needle)
                    continue
            }

            row := gLV.Add(""
                , FormatHwnd(item.hwnd)
                , item.title != "" ? item.title : T("dash")
                , item.proc != "" ? item.proc : T("dash")
                , item.cls != "" ? item.cls : T("dash")
                , item.pid != "" ? item.pid : T("dash")
                , item.flags)

            gRowToHwnd[row] := item.hwnd
            shown++
        }
    } finally {
        gLV.Opt("+Redraw")
    }

    gStatus.Text := Format(T("statusFormat"), gAllWindows.Length, shown)
}

ShowSelected(*) {
    global gLV, gRowToHwnd

    row := 0
    changed := false

    while row := gLV.GetNext(row) {
        if gRowToHwnd.Has(row) {
            RestoreWindow(gRowToHwnd[row])
            changed := true
        }
    }

    if changed {
        Sleep 150
        ScanAndRefresh()
    }
}

ShowAllListed(*) {
    global gRowToHwnd

    changed := false
    for _, hwnd in gRowToHwnd {
        RestoreWindow(hwnd)
        changed := true
    }

    if changed {
        Sleep 150
        ScanAndRefresh()
    }
}

ShowDoubleClicked(ctrl, row) {
    global gRowToHwnd

    if row && gRowToHwnd.Has(row) {
        RestoreWindow(gRowToHwnd[row])
        Sleep 150
        ScanAndRefresh()
    }
}

RestoreWindow(hwnd) {
    win := "ahk_id " hwnd

    try WinShow(win)
    Sleep 50

    try DllCall("ShowWindow", "ptr", hwnd, "int", 9)
    try WinRestore(win)
    try WinActivate(win)
}

IsAppLikeWindow(hwnd, title, proc, cls, style, exStyle, owner) {
    static denyClasses := Map(
        "Progman", 1,
        "WorkerW", 1,
        "Shell_TrayWnd", 1,
        "Shell_SecondaryTrayWnd", 1,
        "NotifyIconOverflowWindow", 1,
        "DV2ControlHost", 1
    )

    if denyClasses.Has(cls)
        return false

    if (exStyle & 0x00000080) ; WS_EX_TOOLWINDOW
        return false

    if (owner && !(exStyle & 0x00040000)) ; owner + brak WS_EX_APPWINDOW
        return false

    if (title = "")
        return false

    return true
}

BuildFlags(appLike, cloaked, exStyle, owner) {
    parts := []

    parts.Push(appLike ? "APP" : "OTHER")

    if cloaked
        parts.Push("CLOAKED")
    if (exStyle & 0x00000080)
        parts.Push("TOOL")
    if owner
        parts.Push("OWNER")
    if (exStyle & 0x00040000)
        parts.Push("APPWND")

    return JoinParts(parts, ", ")
}

JoinParts(arr, sep := ", ") {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= v
    }
    return out
}

IsWindowCloaked(hwnd) {
    cloak := Buffer(4, 0)
    try hr := DllCall("dwmapi\DwmGetWindowAttribute"
        , "ptr", hwnd
        , "uint", 14
        , "ptr", cloak
        , "uint", 4
        , "int")
    catch
        return false

    return (hr = 0) && (NumGet(cloak, 0, "uint") != 0)
}

SafeGetOwner(hwnd) {
    try return DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr") ; GW_OWNER
    catch
        return 0
}

SafeGetStyle(hwnd) {
    try return DllCall("GetWindowLongPtrW", "ptr", hwnd, "int", -16, "ptr") ; GWL_STYLE
    catch
        return 0
}

SafeGetExStyle(hwnd) {
    try return DllCall("GetWindowLongPtrW", "ptr", hwnd, "int", -20, "ptr") ; GWL_EXSTYLE
    catch
        return 0
}

FormatHwnd(hwnd) {
    return Format("0x{1:016X}", hwnd)
}

SafeWinGetTitle(hwnd) {
    try return WinGetTitle("ahk_id " hwnd)
    catch
        return ""
}

SafeWinGetClass(hwnd) {
    try return WinGetClass("ahk_id " hwnd)
    catch
        return ""
}

SafeWinGetProcessName(hwnd) {
    try return WinGetProcessName("ahk_id " hwnd)
    catch
        return ""
}

SafeWinGetPID(hwnd) {
    try return WinGetPID("ahk_id " hwnd)
    catch
        return ""
}
