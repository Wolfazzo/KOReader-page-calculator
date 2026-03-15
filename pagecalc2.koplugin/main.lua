local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Event = require("ui/event")

local PageCalc = WidgetContainer:extend{
    name = "pagecalc",
    is_doc_only = true,
}

-- Simple local i18n
local lang = "en"
if G_reader_settings and G_reader_settings.readSetting then
    lang = G_reader_settings:readSetting("language") or "en"
end

local i18n = {
    en = {
        menu_title = "Page Calculator (Physical)",
        no_doc = "No document open.",
        input_title = "Enter Physical Pages",
        input_hint = "Number of pages in the physical book",
        err_invalid = "Please enter a valid positive number.",
        confirm_title = "Apply New Setting?",
        confirm_desc = "Current KOReader Pages: %d\nPhysical Pages: %d\n\nCurrent Setting: %d\nCalculated Setting: %d\n\nApply this setting now?",
        warn_min = "\n(Value clamped to minimum 500)",
        warn_max = "\n(Value clamped to maximum 3000)",
        applied = "New configuration applied.\nClose and open the book if it doesn't update.",
        refine_title = "Step 2: Final Refinement",
        refine_desc = "With setting %d, KOReader shows %d pages.\nTarget is %d pages.\n\nRecommended adjustment: %d c/p.\n\nApply refinement?",
        stats_line = "Target: %d | Estimated: %d"
    },
    it = {
        menu_title = "Calcolatore Pagine (Cartaceo)",
        no_doc = "Nessun documento aperto.",
        input_title = "Inserisci Pagine Cartaceo",
        input_hint = "Numero di pagine del libro fisico",
        err_invalid = "Inserisci un numero positivo valido.",
        confirm_title = "Applicare nuova impostazione?",
        confirm_desc = "Pagine KOReader: %d\nPagine Cartaceo: %d\n\nImpostazione attuale: %d\nImpostazione calcolata: %d\n\nApplicare l'impostazione?",
        warn_min = "\n(Valore limitato al minimo di 500)",
        warn_max = "\n(Valore limitato al massimo di 3000)",
        applied = "Nuova impostazione applicata.\nRiapri il libro se la vista non si aggiorna subito.",
        refine_title = "Passo 2: Affinamento finale",
        refine_desc = "Con l'impostazione %d, KOReader mostra %d pagine.\nIl target è %d pagine.\n\nCorrezione consigliata: %d c/p.\n\nApplicare l'affinamento?",
        stats_line = "Target: %d | Stimato: %d"
    },
    es = {
        menu_title = "Calculadora de Páginas",
        no_doc = "No hay documento aperto.",
        input_title = "Páginas del Libro Físico",
        input_hint = "Introduce el número de páginas físicas",
        err_invalid = "Introduce un número positivo válido.",
        confirm_title = "¿Aplicar nuovo ajuste?",
        confirm_desc = "Páginas KOReader: %d\nPáginas físicas: %d\n\nAjuste actual: %d\nAjuste calculado: %d\n\n¿Aplicar ajuste ahora?",
        warn_min = "\n(Valor limitado al mínimo 500)",
        warn_max = "\n(Valor limitado al máximo 3000)",
        applied = "Ajuste aplicado.\nVuelve a abrir el libro si no se actualiza de inmediato.",
        refine_title = "Paso 2: Refinamiento final",
        refine_desc = "Con el ajuste %d, KOReader muestra %d pagine.\nEl objetivo es %d pagine.\n\nCorrección suggerida: %d c/p.\n\n¿Aplicar refinamiento?",
        stats_line = "Objetivo: %d | Estimado: %d"
    },
    pt = {
        menu_title = "Calculadora de Páginas",
        no_doc = "Nenhum documento aperto.",
        input_title = "Páginas Físicas do Livro",
        input_hint = "Número de páginas físicas",
        err_invalid = "Insira um número positivo válido.",
        confirm_title = "Aplicar nova configuração?",
        confirm_desc = "Páginas KOReader: %d\nPáginas físicas: %d\n\nConfig. atual: %d\nConfig. calculada: %d\n\nAplicar configuração agora?",
        warn_min = "\n(Valor limitado ao mínimo 500)",
        warn_max = "\n(Valor limitado ao massimo 3000)",
        applied = "Nova configuração aplicada.\nFeche e abra o libro se não atualizar.",
        refine_title = "Passo 2: Refinamento final",
        refine_desc = "Com a configuração %d, o KOReader mostra %d páginas.\nO alvo é %d páginas.\n\nAjuste recomendado: %d c/p.\n\nAplicar refinamento?",
        stats_line = "Alvo: %d | Estimado: %d"
    }
}

-- Fallback
local T = i18n[lang] or i18n["en"]
-- If ko language is something like en_US, try substring
if not i18n[lang] and lang and type(lang) == "string" then
    local short = string.sub(lang, 1, 2)
    T = i18n[short] or i18n["en"]
end

function PageCalc:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function PageCalc:addToMainMenu(menu_items)
    menu_items.page_calc = {
        text = T.menu_title,
        sorting_hint = "more_tools",
        callback = function()
            self:showCalculator()
        end,
    }
end

function PageCalc:showCalculator()
    if not self.ui or not self.ui.document then
        UIManager:show(InfoMessage:new{ text = T.no_doc })
        return
    end

    local dialog
    dialog = InputDialog:new{
        title = T.input_title,
        input = "",
        input_type = "number",
        description = T.input_hint,
        buttons = {
            {
                {
                    text = "Cancel",
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = "Calculate",
                    is_enter_default = true,
                    callback = function()
                        local input_text = dialog:getInputValue()
                        local physical_pages = tonumber(input_text)
                        
                        if not physical_pages or physical_pages <= 0 then
                            UIManager:show(InfoMessage:new{ text = T.err_invalid })
                            return
                        end
                        
                        UIManager:close(dialog)
                        self:performCalculation(physical_pages)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function PageCalc:performCalculation(physical_pages)
    local current_setting
    if self.ui and self.ui.doc_settings then
        current_setting = self.ui.doc_settings:readSetting("pagemap_chars_per_synthetic_page")
    end
    if not current_setting and G_reader_settings then
        current_setting = G_reader_settings:readSetting("pagemap_chars_per_synthetic_page")
    end
    
    local default_setting = 1500
    if not current_setting or current_setting <= 0 then
        current_setting = default_setting
        -- FORCE building the synthetic pagemap temporarily.
        if self.ui and self.ui.document and self.ui.document.buildSyntheticPageMap then
            self.ui.document:buildSyntheticPageMap(current_setting)
        end
    end

    local koreader_pages
    local pm = self.ui and self.ui.pagemap
    if pm and pm.has_pagemap then
        koreader_pages = pm:getPageLabelProps()
    end

    if not koreader_pages or koreader_pages <= 0 then
        if self.ui and self.ui.document then
            koreader_pages = self.ui.document:getPageCount()
        end
    end
    
    if not koreader_pages or koreader_pages <= 0 then
        UIManager:show(InfoMessage:new{ text = T.no_doc })
        return
    end
    
    local calculated = math.floor((current_setting * koreader_pages / physical_pages) + 0.5)
    
    local clamped = calculated
    local warn_msg = ""
    if clamped < 500 then
        clamped = 500
        warn_msg = T.warn_min
    elseif clamped > 3000 then
        clamped = 3000
        warn_msg = T.warn_max
    end
    
    local estimated_pages = math.floor((koreader_pages * current_setting / clamped) + 0.5)
    local stats = string.format("\n" .. T.stats_line, physical_pages, estimated_pages)
    local desc = string.format(T.confirm_desc, koreader_pages, physical_pages, current_setting, clamped) .. stats .. warn_msg

    local confirm
    confirm = ConfirmBox:new{
        text = desc,
        title = T.confirm_title,
        ok_text = "Apply",
        cancel_text = "Cancel",
        ok_callback = function()
            self:applySetting(clamped, physical_pages)
        end,
    }
    UIManager:show(confirm)
end

function PageCalc:applySetting(value, target_pages)
    if self.ui and self.ui.doc_settings then
        self.ui.doc_settings:saveSetting("pagemap_chars_per_synthetic_page", value)
    end
    
    local pm = self.ui and self.ui.pagemap
    if pm then
        pm.chars_per_synthetic_page = value
        if not pm.has_pagemap then
            pm.has_pagemap = true
            pm:resetLayout()
            pm.view:registerViewModule("pagemap", pm)
        end
        pm.page_labels_cache = nil
    end
    
    if self.ui and self.ui.document and self.ui.document.buildSyntheticPageMap then
        self.ui.document:buildSyntheticPageMap(value)
    end
    
    if pm then
        pm:updateVisibleLabels()
    end
    
    UIManager:broadcastEvent(Event:new("UsePageLabelsUpdated"))
    if self.ui then
        self.ui:handleEvent(Event:new("UpdateConfig"))
        self.ui:handleEvent(Event:new("SetupShowPage"))
    end

    local new_pages
    if pm and pm.has_pagemap then
        new_pages = pm:getPageLabelProps()
    elseif self.ui and self.ui.document then
        new_pages = self.ui.document:getPageCount()
    end

    if new_pages and new_pages ~= target_pages then
        local refinement_val = math.floor((value * new_pages / target_pages) + 0.5)
        if refinement_val < 500 then refinement_val = 500 end
        if refinement_val > 3000 then refinement_val = 3000 end

        if refinement_val ~= value then
            local refine_confirm
            refine_confirm = ConfirmBox:new{
                title = T.refine_title,
                text = string.format(T.refine_desc, value, new_pages, target_pages, refinement_val),
                ok_text = "Refine",
                cancel_text = "Finish",
                ok_callback = function()
                    self:applySetting(refinement_val, target_pages)
                end,
            }
            UIManager:show(refine_confirm)
            return
        end
    end

    UIManager:show(InfoMessage:new{ text = T.applied })
end

return PageCalc
