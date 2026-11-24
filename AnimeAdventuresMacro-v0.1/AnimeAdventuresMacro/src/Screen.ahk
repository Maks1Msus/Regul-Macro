class GameScreen {
    __New(executable) {
        this.executable := executable
        this.hwnd := 0
    }

    PrepareBinding() {
        hwnd := WinExist("A")
        if !hwnd || StrLower(WinGetProcessName("ahk_id " hwnd)) != StrLower(this.executable)
            throw Error("Активируй окно " this.executable " и нажми F6.")
        WinGetClientPos(&left, &top, &width, &height, "ahk_id " hwnd)
        if width < 320 || height < 240
            throw Error("Разверни игровое окно до рабочего размера.")
        return {hwnd: hwnd, width: width, height: height}
    }

    Bind(binding) {
        this.hwnd := binding.hwnd
        this.width := binding.width
        this.height := binding.height
    }

    Client() {
        if !this.hwnd
            throw Error("Сначала привяжи окно клавишей F6.")
        target := "ahk_id " this.hwnd
        if !WinActive(target)
            throw Error("Игровое окно потеряло фокус.")
        WinGetClientPos(&left, &top, &width, &height, target)
        if width != this.width || height != this.height
            throw Error("Размер игрового окна изменился.")
        return {left: left, top: top, width: width, height: height}
    }

    Cursor() {
        client := this.Client()
        MouseGetPos(&x, &y)
        point := {x: x - client.left, y: y - client.top}
        this.CheckPoint(point, client)
        this.CheckVisible(x, y)
        return point
    }

    CheckPoint(point, client) {
        if point.x < 0 || point.y < 0 || point.x >= client.width || point.y >= client.height
            throw Error("Точка находится за пределами игрового окна.")
    }

    CheckVisible(x, y) {
        packedPoint := (y << 32) | (x & 0xFFFFFFFF)
        hit := DllCall("User32\WindowFromPoint", "Int64", packedPoint, "Ptr")
        if !hit || DllCall("User32\GetAncestor", "Ptr", hit, "UInt", 2, "Ptr") != this.hwnd
            throw Error("Точка закрыта другим окном.")
    }

    Search(marker) {
        if !marker
            return false
        client := this.Client()
        this.CheckPoint({x: marker.left, y: marker.top}, client)
        this.CheckPoint({x: marker.right, y: marker.bottom}, client)
        padding := 6
        x1 := client.left + Max(0, marker.left - padding)
        y1 := client.top + Max(0, marker.top - padding)
        x2 := client.left + Min(client.width - 1, marker.right + padding)
        y2 := client.top + Min(client.height - 1, marker.bottom + padding)
        if !ImageSearch(&x, &y, x1, y1, x2, y2, "*" marker.variation " " marker.path)
            return false
        return {x: x - client.left + (marker.right - marker.left) // 2,
            y: y - client.top + (marker.bottom - marker.top) // 2}
    }

    ClickPoint(point) {
        client := this.Client()
        this.CheckPoint(point, client)
        x := client.left + point.x
        y := client.top + point.y
        this.CheckVisible(x, y)
        MouseClick("Left", x, y, 1, 0)
    }

    SelectSlot(key) {
        this.Client()
        SendInput("{" key "}")
    }

    Capture(rect, path) {
        client := this.Client()
        this.CheckPoint({x: rect.left, y: rect.top}, client)
        this.CheckPoint({x: rect.right, y: rect.bottom}, client)
        this.CheckVisible(client.left + rect.left, client.top + rect.top)
        this.CheckVisible(client.left + rect.right, client.top + rect.bottom)
        CaptureDesktopBitmap(path, client.left + rect.left, client.top + rect.top,
            rect.right - rect.left + 1, rect.bottom - rect.top + 1)
    }
}

CaptureDesktopBitmap(path, x, y, width, height) {
    rowBytes := ((width * 3 + 3) // 4) * 4
    pixelBytes := rowBytes * height
    info := Buffer(40, 0)
    NumPut("UInt", 40, "Int", width, "Int", height, "UShort", 1, "UShort", 24, info)
    header := Buffer(14, 0)
    NumPut("UShort", 0x4D42, "UInt", 54 + pixelBytes, header)
    NumPut("UInt", 54, header, 10)

    screenDC := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    if !screenDC
        throw Error("Windows не предоставила доступ к видимому экрану.")
    memoryDC := 0
    bitmap := 0
    previous := 0
    file := false
    temporaryPath := path ".tmp"

    try {
        memoryDC := DllCall("Gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        if !memoryDC
            throw Error("Не удалось создать контекст захвата экрана.")
        pixels := 0
        bitmap := DllCall("Gdi32\CreateDIBSection", "Ptr", screenDC, "Ptr", info, "UInt", 0,
            "Ptr*", &pixels, "Ptr", 0, "UInt", 0, "Ptr")
        if !bitmap || !pixels
            throw Error("Не удалось создать образец экрана.")
        previous := DllCall("Gdi32\SelectObject", "Ptr", memoryDC, "Ptr", bitmap, "Ptr")
        if !previous
            throw Error("Не удалось подготовить образец экрана.")
        if !DllCall("Gdi32\BitBlt", "Ptr", memoryDC, "Int", 0, "Int", 0, "Int", width,
            "Int", height, "Ptr", screenDC, "Int", x, "Int", y, "UInt", 0x00CC0020, "Int")
            throw Error("Не удалось снять выбранную область.")
        DllCall("Gdi32\GdiFlush")
        file := FileOpen(temporaryPath, "w", "CP0")
        if !file || file.RawWrite(header) != 14 || file.RawWrite(info) != 40
            || file.RawWrite(pixels, pixelBytes) != pixelBytes
            throw Error("Не удалось записать образец экрана.")
        file.Close()
        file := false
        FileMove(temporaryPath, path, true)
    } finally {
        if file
            file.Close()
        if FileExist(temporaryPath)
            FileDelete(temporaryPath)
        if previous
            DllCall("Gdi32\SelectObject", "Ptr", memoryDC, "Ptr", previous)
        if bitmap
            DllCall("Gdi32\DeleteObject", "Ptr", bitmap)
        if memoryDC
            DllCall("Gdi32\DeleteDC", "Ptr", memoryDC)
        DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

