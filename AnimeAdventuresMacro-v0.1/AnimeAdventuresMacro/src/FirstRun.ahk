class FirstRun {
    __New(profile, screen) {
        this.profile := profile
        this.screen := screen
        this.state := "idle"
        this.corner := false
        this.tick := ObjBindMethod(this, "Tick")
        this.hideStatus := () => ToolTip()
    }

    Dispatch(action, args*) {
        args.Pop()
        if this.state != "idle" && action != "ManualStop"
            return
        try {
            this.%action%(args*)
        } catch Error as issue {
            this.Status(issue.Message)
        }
    }

    Status(message) {
        this.profile.Log(message)
        ToolTip(message, 8, 8)
        SetTimer(this.hideStatus, -4200)
    }

    BindWindow() {
        binding := this.screen.PrepareBinding()
        this.profile.BindSize(binding.width, binding.height)
        this.screen.Bind(binding)
        this.corner := false
        this.Status("Окно привязано. Профиль " this.profile.directory)
    }

    SavePlacement() {
        point := this.screen.Cursor()
        this.profile.SavePlacement(point)
        this.Status("Точка установки сохранена: " point.x ", " point.y)
    }

    CaptureMarker(marker) {
        point := this.screen.Cursor()
        if !this.corner || this.corner.marker != marker {
            this.corner := {marker: marker, point: point}
            this.Status("Отметь противоположный угол тем же сочетанием. Образец " marker)
            return
        }

        first := this.corner.point
        this.corner := false
        rect := {left: Min(first.x, point.x), top: Min(first.y, point.y),
            right: Max(first.x, point.x), bottom: Max(first.y, point.y)}
        width := rect.right - rect.left + 1
        height := rect.bottom - rect.top + 1
        if width < 8 || height < 8 || width > 240 || height > 120
            throw Error("Образец должен быть от 8×8 до 240×120 пикселей. Выбери область заново.")
        ToolTip()
        Sleep(150)
        this.screen.Capture(rect, this.profile.MarkerPath(marker))
        this.profile.SaveMarkerBounds(marker, rect)
        this.Status("Образец сохранён: " marker)
    }

    Probe() {
        ToolTip()
        this.screen.Client()
        lines := ["Проверка образцов"]
        for name in this.profile.markerNames {
            marker := this.profile.LoadMarker(name)
            found := !marker ? "пусто" : this.screen.Search(marker) ? "найден" : "не найден"
            lines.Push(name " — " found)
        }
        message := ""
        for line in lines
            message .= (message = "" ? "" : Chr(10)) line
        this.Status(message)
    }

    Start() {
        Critical("On")
        ToolTip()
        client := this.screen.Client()
        this.markers := Map()
        for name in this.profile.markerNames {
            marker := this.profile.LoadMarker(name)
            if !marker && name != "placed" && name != "placing"
                throw Error("Сначала сними обязательный образец " name ".")
            this.markers[name] := marker
        }
        this.point := this.profile.Placement()
        this.screen.CheckPoint(this.point, client)
        this.key := this.profile.UnitKey()
        this.RequireMatch()
        if this.Find("menu") || this.Find("ready") || this.Find("upgraded") || this.Find("placed")
            || this.Find("placing")
            throw Error("Запусти чистый матч с закрытым меню юнита и без сохранённого признака установки.")

        this.openedMenu := false
        this.screen.SelectSlot(this.key)
        this.Step("place", 6000)
        SetTimer(this.tick, 125)
        this.profile.Log("Начата установка. F9 — остановить.")
    }

    ManualStop() {
        this.corner := false
        this.Stop("Остановлено.")
    }

    Stop(message) {
        this.state := "idle"
        SetTimer(this.tick, 0)
        this.Status(message)
    }

    Step(state, timeoutMs) {
        this.state := state
        this.startedAt := A_TickCount
        this.deadline := this.startedAt + timeoutMs
    }

    Find(name) {
        return this.screen.Search(this.markers[name])
    }

    RequireMatch() {
        this.screen.Client()
        if !this.Find("match")
            throw Error("Не виден признак матча. Проверь кадр и профиль.")
    }

    Tick() {
        Critical("On")
        try {
            if this.state != "idle"
                this.Advance()
        } catch Error as issue {
            this.Stop(issue.Message)
        }
    }

    Advance() {
        if A_TickCount >= this.deadline {
            messages := Map("place", "Режим установки не подтверждён.",
                "menu", "Установка не подтверждена. Проверь поле и меню юнита.",
                "ready", "Улучшение не стало доступным за 90 секунд.",
                "upgraded", "Первое улучшение не подтверждено. Повторный клик отменён.")
            this.Stop(messages[this.state])
            return
        }

        this.RequireMatch()
        switch this.state {
            case "place":
                if A_TickCount - this.startedAt < 250
                    return
                if this.markers["placing"] && !this.Find("placing")
                    return
                this.screen.ClickPoint(this.point)
                this.Step("menu", 16000)
                this.profile.Log("Отправлен клик установки. Ожидается меню юнита.")
            case "menu":
                if this.Find("menu") {
                    this.Step("ready", 90000)
                    this.profile.Log("Меню юнита найдено. Ожидается активная кнопка улучшения.")
                    return
                }
                if this.markers["placed"] && !this.openedMenu && this.Find("placed") {
                    this.screen.ClickPoint(this.point)
                    this.openedMenu := true
                }
            case "ready":
                if !this.Find("menu")
                    return
                if this.Find("upgraded")
                    throw Error("Признак улучшения виден до нажатия кнопки. Проверь образцы.")
                if readyButton := this.Find("ready") {
                    this.screen.ClickPoint(readyButton)
                    this.Step("upgraded", 12000)
                    this.profile.Log("Клик улучшения отправлен. Ожидается новый уровень.")
                }
            case "upgraded":
                if this.Find("menu") && this.Find("upgraded")
                    this.Stop("Установка и первое улучшение подтверждены.")
        }
    }
}

