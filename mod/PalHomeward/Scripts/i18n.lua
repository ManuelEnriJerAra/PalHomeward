local messages = {
    en = {
        ["mod.loaded"] = "[PalHomeward] LOADED mode={mode} version={version}",
        ["mode.observe.notice"] = "PalHomeward is in OBSERVE mode: diagnostics only, it does not protect or move Pals.",
        ["deny.unknown_owner"] = "The Pal's owner could not be identified.",
        ["deny.destination_full"] = "The owner's Palbox is full.",
        ["deny.owner_storage_unavailable"] = "The owner's Palbox could not be accessed.",
        ["ok.returned_to_owner"] = "{pal} was returned to {owner}.",
    },
    es = {
        ["mod.loaded"] = "[PalHomeward] LOADED mode={mode} version={version}",
        ["mode.observe.notice"] = "PalHomeward está en modo OBSERVE: solo realiza tareas de diagnóstico, no protege ni mueve a los Pals.",
        ["deny.unknown_owner"] = "No se ha podido identificar al propietario del Pal.",
        ["deny.destination_full"] = "La caja de Pals del propietario está llena.",
        ["deny.owner_storage_unavailable"] = "No se ha podido acceder a la caja de Pals del propietario.",
        ["ok.returned_to_owner"] = "{pal} ha vuelto con {owner}.",
    },
}

local i18n = { messages = messages }

function i18n.t(key, params, locale)
    local translations = messages[locale] or messages.en
    local message = translations[key] or messages.en[key]
    if not message then
        return key
    end
    return (message:gsub("{([%w_]+)}", function(name)
        local value = params and params[name]
        if value ~= nil then
            return tostring(value)
        end
    end))
end

return i18n
