class MacroProfile {
    __New(directory, logPath) {
        this.directory := directory
        this.ini := directory "\profile.ini"
        this.logPath := logPath
        this.markerNames := ["match", "menu", "ready", "upgraded", "placed", "placing"]
        DirCreate(directory)
        SplitPath(logPath, , &logDirectory)
        DirCreate(logDirectory)
    }

    ReadInt(section, key, fallback := "") {
        value := IniRead(this.ini, section, key, fallback)
        if !RegExMatch(value, "^\d+$")
            throw Error("Проверь параметр " section "/" key " в profile.ini.")
        return Integer(value)
    }

    BindSize(width, height) {
        if !FileExist(this.ini) {
            IniWrite(width, this.ini, "Window", "Width")
            IniWrite(height, this.ini, "Window", "Height")
            IniWrite(1, this.ini, "Run", "UnitKey")
            IniWrite(8, this.ini, "Recognition", "Variation")
        }
        expectedWidth := this.ReadInt("Window", "Width")
        expectedHeight := this.ReadInt("Window", "Height")
        if width != expectedWidth || height != expectedHeight
            throw Error("Профиль ожидает размер " expectedWidth "×" expectedHeight
                ", сейчас " width "×" height ". Восстанови размер или выбери новый профиль.")
    }

    SavePlacement(point) {
        IniWrite(point.x, this.ini, "Placement", "X")
        IniWrite(point.y, this.ini, "Placement", "Y")
    }

    Placement() {
        return {x: this.ReadInt("Placement", "X"), y: this.ReadInt("Placement", "Y")}
    }

    UnitKey() {
        key := IniRead(this.ini, "Run", "UnitKey", "1")
        if !RegExMatch(key, "^[1-9]$")
            throw Error("UnitKey должен быть цифрой от 1 до 9.")
        return key
    }

    MarkerPath(marker) {
        return this.directory "\" marker ".bmp"
    }

    SaveMarkerBounds(marker, rect) {
        IniWrite(Format("{},{},{},{}", rect.left, rect.top, rect.right, rect.bottom),
            this.ini, "Markers", marker)
    }

    LoadMarker(marker) {
        path := this.MarkerPath(marker)
        bounds := IniRead(this.ini, "Markers", marker, "")
        if !FileExist(path) || bounds = ""
            return false

        if !RegExMatch(bounds, "^(\d+),(\d+),(\d+),(\d+)$", &match)
            throw Error("Некорректная область образца " marker ".")
        left := Integer(match[1])
        top := Integer(match[2])
        right := Integer(match[3])
        bottom := Integer(match[4])
        if right < left || bottom < top
            throw Error("Некорректный размер образца " marker ".")

        variation := this.ReadInt("Recognition", "Variation", "8")
        if variation > 30
            throw Error("Variation должен быть в диапазоне от 0 до 30.")
        return {path: path, left: left, top: top, right: right, bottom: bottom,
            variation: variation}
    }

    Log(message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " message Chr(10), this.logPath, "UTF-8")
    }
}

