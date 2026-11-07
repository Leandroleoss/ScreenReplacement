#Requires AutoHotkey v2.0

global IniFile := A_ScriptDir . "\configuracoes.ini"

; --- DETECÇÃO AUTOMÁTICA DE MONITORES ---
global QtdMonitores := MonitorGetCount()
global ListaMonitores := []

Loop QtdMonitores {
    MonitorGet(A_Index, &L, &T, &R, &B)
    MonitorGetWorkArea(A_Index, &WAL, &WAT, &WAR, &WAB)
    
    ; Salva as dimensões da área de trabalho útil (sem a barra de tarefas)
    ListaMonitores.Push({
        ID: A_Index,
        X: WAL, Y: WAT,
        W: WAR - WAL, H: WAB - WAT
    })
}

; Opções de Posição Amigáveis
global OpcoesPosicao := ["Tela Cheia", "Metade Esquerda", "Metade Direita", "Parte Superior", "Parte Inferior"]
global OpcoesMonitores := []
Loop QtdMonitores {
    OpcoesMonitores.Push("Monitor " . A_Index)
}

; Lista atualizada de Tipos de Programas
global OpcoesTipos := ["Chrome", "Firefox", "Brave", "Edge", "Executável"]

; --- CONSTRUÇÃO DA GUI ---
guiMain := Gui("+AlwaysOnTop", "Configurador Visual de Telas")
guiMain.SetFont("s9 Bold", "Segoe UI")
guiMain.Add("Text", "x15 y12 w500 cBlue", "Selecione o programa, em qual monitor e como ele deve abrir:")

guiMain.SetFont("s9 norm", "Segoe UI")

; Cabeçalhos amigáveis
guiMain.Add("Text", "x15 y40 w160", "Caminho / URL / App")
guiMain.Add("Text", "x180 y40 w90", "Tipo")
guiMain.Add("Text", "x275 y40 w80", "Monitor")
guiMain.Add("Text", "x360 y40 w110", "Posição na Tela")

inputs := []
yPos := 60

; Cria 6 slots de configuração
Loop 6 {
    idx := A_Index
    
    txtPath := guiMain.Add("Edit", "x15 y" . yPos . " w160 h23")
    ddlType := guiMain.Add("DropDownList", "x180 y" . yPos . " w90 Choose1", OpcoesTipos)
    ddlMon := guiMain.Add("DropDownList", "x275 y" . yPos . " w80 Choose1", OpcoesMonitores)
    ddlPos := guiMain.Add("DropDownList", "x360 y" . yPos . " w110 Choose1", OpcoesPosicao)
    
    ; Carrega dados salvos
    txtPath.Text := IniRead(IniFile, "App" . idx, "Path", "")
    try ddlType.Text := IniRead(IniFile, "App" . idx, "Type", "Chrome")
    try ddlMon.Text := IniRead(IniFile, "App" . idx, "Monitor", "Monitor 1")
    try ddlPos.Text := IniRead(IniFile, "App" . idx, "Posicao", "Tela Cheia")
    
    inputs.Push({Path: txtPath, Type: ddlType, Mon: ddlMon, Pos: ddlPos})
    yPos += 30
}

btnSalvar := guiMain.Add("Button", "x15 y" . yPos + 10 . " w455 h35 Default", "Salvar e Executar")
btnSalvar.OnEvent("Click", (*) => SalvarEExecutar(guiMain, inputs))

guiMain.Show("w485")

; ==============================================================================
; LÓGICA E CÁLCULO AUTOMÁTICO DE COORDENADAS
; ==============================================================================

SalvarEExecutar(guiObj, inputList) {
    Loop inputList.Length {
        idx := A_Index
        item := inputList[idx]
        
        IniWrite(item.Path.Text, IniFile, "App" . idx, "Path")
        IniWrite(item.Type.Text, IniFile, "App" . idx, "Type")
        IniWrite(item.Mon.Text, IniFile, "App" . idx, "Monitor")
        IniWrite(item.Pos.Text, IniFile, "App" . idx, "Posicao")
    }
    
    guiObj.Hide()
    ExecutarAplicacoes(inputList)
}

ExecutarAplicacoes(inputList) {
    For item in inputList {
        path := item.Path.Text
        if (path == "")
            continue

        tipo := item.Type.Text
        numMon := RegExReplace(item.Mon.Text, "\D") ; Extrai apenas o número do monitor
        posicao := item.Pos.Text
        
        ; Calcula X, Y, W, H automaticamente com base na escolha do usuário
        coords := CalcularCoordenadas(numMon, posicao)

        switch tipo {
            case "Chrome":
                AbrirNavegadorChromium("chrome.exe", "chrome.exe", path, coords.X, coords.Y, coords.W, coords.H)
            case "Brave":
                AbrirNavegadorChromium("brave.exe", "brave.exe", path, coords.X, coords.Y, coords.W, coords.H)
            case "Edge":
                AbrirNavegadorChromium("msedge.exe", "msedge.exe", path, coords.X, coords.Y, coords.W, coords.H)
            case "Firefox":
                AbrirComJanela("firefox.exe --new-window " . path, "ahk_exe firefox.exe", coords.X, coords.Y, coords.W, coords.H)
            case "Executável":
                AbrirComJanela(path, "", coords.X, coords.Y, coords.W, coords.H)
        }
        Sleep 800
    }
}

CalcularCoordenadas(numMon, posicao) {
    ; Garante que o monitor existe (senão usa o monitor 1)
    monIdx := (numMon <= ListaMonitores.Length) ? numMon : 1
    m := ListaMonitores[monIdx]
    
    x := m.X
    y := m.Y
    w := m.W
    h := m.H

    switch posicao {
        case "Metade Esquerda":
            w := m.W / 2
        case "Metade Direita":
            x := m.X + (m.W / 2)
            w := m.W / 2
        case "Parte Superior":
            h := m.H / 2
        case "Parte Inferior":
            y := m.Y + (m.H / 2)
            h := m.H / 2
    }
    
    return {X: Floor(x), Y: Floor(y), W: Floor(w), H: Floor(h)}
}

AbrirNavegadorChromium(exeName, ahkExe, url, x, y, w, h) {
    janelasAntigas := WinGetList("ahk_exe " . ahkExe)
    Run exeName . " --new-window " . url
    
    Loop 20 {
        Sleep 500
        janelasAtuais := WinGetList("ahk_exe " . ahkExe)
        For id in janelasAtuais {
            nova := true
            For idAntigo in janelasAntigas {
                if (id == idAntigo) {
                    nova := false
                    break
                }
            }
            if (nova && WinExist(id)) {
                try {
                    WinRestore(id)
                    WinMove(x, y, w, h, id)
                    WinActivate(id)
                }
                return
            }
        }
    }
}

AbrirComJanela(comandoRun, ahkClass, x, y, w, h) {
    Run comandoRun
    if (ahkClass != "" && hwnd := WinWait(ahkClass, , 10)) {
        Sleep 500
        if WinExist(hwnd) {
            try {
                WinRestore(hwnd)
                WinMove(x, y, w, h, hwnd)
                WinActivate(hwnd)
            }
        }
    }
}