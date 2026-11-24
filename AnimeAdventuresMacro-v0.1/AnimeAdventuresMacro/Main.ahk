#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\Profile.ahk
#Include src\Screen.ahk
#Include src\FirstRun.ahk

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

if A_Args.Length > 1 || (A_Args.Length = 1 && !RegExMatch(A_Args[1], "^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$")) {
    MsgBox("Укажи одно имя профиля латиницей. Например, story_map_1.", "Anime Adventures Macro")
    ExitApp(2)
}

profileName := A_Args.Length ? A_Args[1] : "story_first_map"
profile := MacroProfile(A_ScriptDir "\profiles\" profileName, A_ScriptDir "\runtime\" profileName ".log")
gameExe := "RobloxPlayerBeta.exe"
app := FirstRun(profile, GameScreen(gameExe))

HotIfWinActive("ahk_exe " gameExe)
bindings := Map(
    "F6", "BindWindow", "F8", "Start", "F9", "ManualStop", "F10", "Probe",
    "^!p", "SavePlacement"
)
for key, action in bindings
    Hotkey(key, ObjBindMethod(app, "Dispatch", action))

markers := Map("^!m", "match", "^!i", "menu", "^!u", "ready", "^!l", "upgraded",
    "^!a", "placed", "^!g", "placing")
for key, marker in markers
    Hotkey(key, ObjBindMethod(app, "Dispatch", "CaptureMarker", marker))

