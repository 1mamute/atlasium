local ADDON_NAME, ns = ...

local Localization = { name = ADDON_NAME }
ns.Localization = Localization

Localization.languages = { { code = "enUS", name = "English" }, { code = "ptBR", name = "Português (Brasil)" } }
Localization.translations = {
    enUS = {
        title = "Atlasium Settings", general = "General", minimap = "Minimap", worldmap = "World Map",
        advanced = "Advanced", language = "Language", immediate = "Changes apply immediately.",
        defaults = "Restore Defaults", close = "Close", button = "Show minimap button",
        angle = "Minimap button position: %s°", minimapZoom = "Minimap mouse wheel zoom",
        tiles = "Custom minimap terrain (experimental)", fog = "Reveal unexplored areas",
        mapNav = "World map zoom and drag", maxZoom = "Maximum world map zoom: %s×",
        step = "Zoom multiplier per wheel notch: %s", color = "Unexplored area tint",
        debug = "Debug mode",
        debugDescription = "Developer aids: map marker, Num Pad shortcuts, Lua console and error capture.",
        languageTip = "Choose the language for Atlasium. Blizzard windows keep the client language.",
        buttonTip = "Show or hide the button. You can always open settings with /atlasium.",
        angleTip = "Move the button around the minimap. You can also drag it with the left mouse button.",
        minimapZoomTip = "Use the mouse wheel over the minimap to zoom. Another add-on's wheel handler takes priority.",
        tilesTip = "Draw custom terrain at the game's zoom levels. "
            .. "Indoors, instances and some cities use Blizzard terrain.",
        fogTip = "Show unexplored parts of zone maps with the tint below.",
        mapNavTip = "Zoom with the mouse wheel and drag the world map with the left mouse button.",
        maxZoomTip = "Set the largest world map zoom, from 1 to 16 times its normal size.",
        stepTip = "Set how much each wheel notch multiplies world map zoom, from 1.05 to 2.",
        colorTip = "Choose the color and opacity of unexplored areas. Cancel restores the previous tint.",
        invalid = "Invalid value for this setting.", commands = "commands: /atlasium %s",
        on = "on", off = "off", state = "%s %s (/atlasium %s %s)", submenu = "%s: %s",
        debugState = "debug %s", version = "v%s",
        buttonClick = "|cffa6a6a6Left-click|r: Open or close settings",
        buttonDrag = "|cffa6a6a6Drag|r: Move this button",
        buttonHide = "|cffa6a6a6/atlasium minimap button off|r: Hide this button",
    },
    ptBR = {
        title = "Configurações do Atlasium", general = "Geral", minimap = "Minimapa", worldmap = "Mapa-múndi",
        advanced = "Avançado", language = "Idioma", immediate = "As alterações são aplicadas imediatamente.",
        defaults = "Restaurar padrões", close = "Fechar", button = "Mostrar botão no minimapa",
        angle = "Posição do botão no minimapa: %s°", minimapZoom = "Zoom no minimapa com a roda do mouse",
        tiles = "Terreno personalizado no minimapa (experimental)", fog = "Revelar áreas inexploradas",
        mapNav = "Zoom e arraste no mapa-múndi", maxZoom = "Zoom máximo do mapa-múndi: %s×",
        step = "Multiplicador de zoom por passo da roda: %s", color = "Cor das áreas inexploradas",
        debug = "Modo de depuração",
        debugDescription = "Ferramentas de desenvolvimento: marcador do mapa, atalhos do teclado numérico, "
            .. "console Lua e captura de erros.",
        languageTip = "Escolha o idioma do Atlasium. As janelas da Blizzard usam o idioma do cliente.",
        buttonTip = "Mostre ou oculte o botão. Você sempre pode abrir as configurações com /atlasium.",
        angleTip = "Mova o botão ao redor do minimapa. Você também pode arrastá-lo com o botão esquerdo do mouse.",
        minimapZoomTip = "Use a roda do mouse sobre o minimapa para ajustar o zoom. "
            .. "O controle de outro addon tem prioridade.",
        tilesTip = "Mostre terreno personalizado nos níveis de zoom do jogo. "
            .. "Interiores, instâncias e algumas cidades usam o terreno da Blizzard.",
        fogTip = "Mostre as partes inexploradas dos mapas de zona com a cor abaixo.",
        mapNavTip = "Ajuste o zoom com a roda do mouse e arraste o mapa-múndi com o botão esquerdo.",
        maxZoomTip = "Defina o zoom máximo do mapa-múndi, de 1 a 16 vezes o tamanho normal.",
        stepTip = "Defina o multiplicador de zoom de cada passo da roda do mouse, de 1,05 a 2.",
        colorTip = "Escolha a cor e a opacidade das áreas inexploradas. Cancelar restaura a cor anterior.",
        invalid = "Valor inválido para esta configuração.", commands = "comandos: /atlasium %s",
        on = "ativado", off = "desativado", state = "%s %s (/atlasium %s %s)", submenu = "%s: %s",
        debugState = "depuração %s", version = "v%s",
        buttonClick = "|cffa6a6a6Clique esquerdo|r: Abrir ou fechar as configurações",
        buttonDrag = "|cffa6a6a6Arrastar|r: Mover este botão",
        buttonHide = "|cffa6a6a6/atlasium minimap button off|r: Ocultar este botão",
    },
}

--- Return the saved language, with English as the fallback.
function Localization.GetLanguage()
    local language = ns.db and ns.db.language
    return Localization.translations[language] and language or "enUS"
end

--- Return a translated string, optionally formatted. Missing keys fall back to English, then the key.
function Localization.Get(key, ...)
    local value = Localization.translations[Localization.GetLanguage()][key]
        or Localization.translations.enUS[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

--- Save a supported language and refresh Atlasium text without a reload.
function Localization.SetLanguage(language)
    if not ns.db or not Localization.translations[language] then
        return false, Localization.Get("invalid")
    end
    ns.db.language = language
    if ns.SettingsUI then ns.SettingsUI.Refresh() end
    if ns.MinimapButton then ns.MinimapButton.RefreshTooltip() end
    return true
end
