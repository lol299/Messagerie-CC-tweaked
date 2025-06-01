-- Fonction pour obtenir la couleur du signal selon la distance
local function getSignalColor(distance)
    if not distance then return colors.gray end
    
    if distance <= 512 then return colors.lime        -- VERT (proche)
    elseif distance <= 1024 then return colors.orange -- ORANGE (moyen)
    elseif distance <= 2048 then return colors.red    -- ROUGE (loin)
    else return colors.gray end                        -- GRIS (très loin)
end

-- Interface Messagerie Cliquable CC:Tweaked avec Distance Précise
-- Application de messagerie avec affichage de la distance exacte en blocs

local modem = peripheral.find("modem") or error("Modem sans fil requis!")
local monitor = peripheral.find("monitor") -- Optionnel
local screen = monitor or term

-- Configuration
local MESSAGE_CHANNEL = 2000
local myID = os.getComputerID()
local contacts = {}
local conversations = {}
local newMessages = {}

-- URL GitHub pour la mise à jour (remplacez par votre URL)
local GITHUB_URL = "https://raw.githubusercontent.com/VOTRE_USERNAME/VOTRE_REPO/main/messagerie.lua"

-- Variables d'interface
local currentScreen = "home"
local selectedConv = nil
local buttons = {}
local scrollOffset = 0
local maxLines = 0
local distances = {} -- Stockage des distances exactes par ID

-- Couleurs
local colors_bg = colors.black
local colors_primary = colors.blue
local colors_secondary = colors.lightBlue
local colors_text = colors.white
local colors_accent = colors.lime
local colors_danger = colors.red

-- Fonction pour calculer la force du signal basée sur la distance
local function getSignalStrength(distance)
    if not distance then return 0 end
    
    -- Signal excellent (5 barres) : 0-256 blocs - VERT
    -- Signal bon (4 barres) : 257-512 blocs - VERT
    -- Signal moyen (3 barres) : 513-1024 blocs - ORANGE
    -- Signal faible (2 barres) : 1025-1536 blocs - ORANGE  
    -- Signal très faible (1 barre) : 1537-2048 blocs - ROUGE
    -- Pas de signal (0 barre) : >2048 blocs - GRIS
    
    if distance <= 256 then return 5
    elseif distance <= 512 then return 4
    elseif distance <= 1024 then return 3
    elseif distance <= 1536 then return 2
    elseif distance <= 2048 then return 1
    else return 0 end
end

-- Fonction pour télécharger la mise à jour depuis GitHub
local function downloadUpdate()
    screen.setCursorPos(1, 3)
    screen.setBackgroundColor(colors_bg)
    screen.setTextColor(colors.yellow)
    screen.clearLine()
    screen.write("Téléchargement de la mise à jour...")
    
    -- Vérifier si HTTP est activé
    if not http then
        screen.setCursorPos(1, 4)
        screen.setTextColor(colors.red)
        screen.write("Erreur: HTTP désactivé dans la config!")
        screen.setCursorPos(1, 5)
        screen.write("Activez http_enable dans computercraft.cfg")
        sleep(3)
        return false
    end
    
    -- Télécharger le fichier
    local response = http.get(GITHUB_URL)
    if response then
        local content = response.readAll()
        response.close()
        
        if content and content ~= "" then
            -- Sauvegarder l'ancien fichier
            if fs.exists("messagerie.lua") then
                fs.copy("messagerie.lua", "messagerie_backup.lua")
            end
            
            -- Écrire le nouveau fichier
            local file = fs.open("messagerie.lua", "w")
            file.write(content)
            file.close()
            
            screen.setCursorPos(1, 4)
            screen.setTextColor(colors.lime)
            screen.write("Mise à jour téléchargée avec succès!")
            screen.setCursorPos(1, 5)
            screen.write("Redémarrez le programme pour appliquer.")
            screen.setCursorPos(1, 6)
            screen.write("Backup sauvé: messagerie_backup.lua")
            sleep(3)
            return true
        else
            screen.setCursorPos(1, 4)
            screen.setTextColor(colors.red)
            screen.write("Erreur: Fichier vide ou corrompu")
            sleep(2)
            return false
        end
    else
        screen.setCursorPos(1, 4)
        screen.setTextColor(colors.red)
        screen.write("Erreur: Impossible de télécharger")
        screen.setCursorPos(1, 5)
        screen.write("Vérifiez l'URL et la connexion")
        sleep(2)
        return false
    end
end

-- Fonction pour diviser un texte en lignes
local function wrapText(text, maxWidth)
    if not text or text == "" then
        return {""}
    end
    
    if maxWidth <= 0 then
        maxWidth = 10
    end
    
    local lines = {}
    local currentLine = ""
    local words = {}
    
    -- Diviser le texte en mots
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 0 then
        return {text}
    end
    
    for _, word in ipairs(words) do
        if #currentLine + #word + 1 <= maxWidth then
            if currentLine == "" then
                currentLine = word
            else
                currentLine = currentLine .. " " .. word
            end
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = word
            else
                -- Mot trop long, on le coupe
                table.insert(lines, word:sub(1, maxWidth))
                currentLine = ""
            end
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    if #lines == 0 then
        lines = {text:sub(1, maxWidth)}
    end
    
    return lines
end

-- Initialisation de l'écran
local function initScreen()
    if monitor then
        monitor.setTextScale(0.5)
    end
    local w, h = screen.getSize()
    maxLines = h - 4
    screen.setBackgroundColor(colors_bg)
    screen.setTextColor(colors_text)
    screen.clear()
end

-- Charger/Sauvegarder données
local function loadData()
    if fs.exists("contacts.txt") then
        local file = fs.open("contacts.txt", "r")
        local data = file.readAll()
        file.close()
        if data and data ~= "" then
            contacts = textutils.unserialize(data) or {}
        end
    end
    
    if fs.exists("conversations.txt") then
        local file = fs.open("conversations.txt", "r")
        local data = file.readAll()
        file.close()
        if data and data ~= "" then
            conversations = textutils.unserialize(data) or {}
        end
    end
    
    if fs.exists("distances.txt") then
        local file = fs.open("distances.txt", "r")
        local data = file.readAll()
        file.close()
        if data and data ~= "" then
            distances = textutils.unserialize(data) or {}
        end
    end
end

local function saveData()
    local file = fs.open("contacts.txt", "w")
    file.write(textutils.serialize(contacts))
    file.close()
    
    file = fs.open("conversations.txt", "w")
    file.write(textutils.serialize(conversations))
    file.close()
    
    file = fs.open("distances.txt", "w")
    file.write(textutils.serialize(distances))
    file.close()
end

-- Fonction pour dessiner la barre de signal avec couleurs
local function drawSignalBar(x, y, distance)
    screen.setCursorPos(x, y)
    local strength = getSignalStrength(distance)
    
    for i = 1, 5 do
        if i <= strength then
            screen.setTextColor(getSignalColor(distance))
        else
            screen.setTextColor(colors.gray)  -- GRIS (pas de signal)
        end
        screen.write("|")
    end
    
    screen.setTextColor(colors_text)  -- Remettre la couleur par défaut
end

local function drawButton(x, y, width, height, text, color, textColor)
    screen.setBackgroundColor(color or colors_primary)
    screen.setTextColor(textColor or colors_text)
    
    for row = y, y + height - 1 do
        screen.setCursorPos(x, row)
        screen.write(string.rep(" ", width))
    end
    
    local textX = x + math.floor((width - #text) / 2)
    local textY = y + math.floor(height / 2)
    screen.setCursorPos(textX, textY)
    screen.write(text)
    
    return {x = x, y = y, width = width, height = height, text = text}
end

-- Affichage de l'en-tête avec signal et distance précise
local function drawHeader(title)
    local w, h = screen.getSize()
    screen.setBackgroundColor(colors_primary)
    screen.setTextColor(colors_text)
    screen.setCursorPos(1, 1)
    screen.clearLine()
    
    local titleX = math.floor((w - #title) / 2)
    screen.setCursorPos(titleX, 1)
    screen.write(title)
    
    -- Afficher le signal et la distance exacte pour la conversation active
    if currentScreen == "conversation" and selectedConv then
        local distance = distances[selectedConv]
        if distance then
            -- Barre de signal
            drawSignalBar(w - 6, 1, distance)
        else
            -- Hors ligne
            screen.setCursorPos(w - 10, 1)
            screen.setTextColor(colors.gray)
            screen.write("Hors ligne")
            screen.setTextColor(colors_text)
        end
    end
    
    -- Ligne de séparation
    screen.setBackgroundColor(colors_secondary)
    screen.setCursorPos(1, 2)
    screen.clearLine()
end

local function drawConversationItem(x, y, width, conv, isNew)
    local bgColor = isNew and colors_accent or colors_secondary
    local textColor = isNew and colors.black or colors_text
    
    screen.setBackgroundColor(bgColor)
    screen.setTextColor(textColor)
    screen.setCursorPos(x, y)
    screen.write(string.rep(" ", width))
    
    -- Nom du contact
    local name = "ID " .. conv.id
    for contactName, id in pairs(contacts) do
        if id == conv.id then
            name = contactName
            break
        end
    end
    
    screen.setCursorPos(x + 1, y)
    screen.write(name:sub(1, width - 25))
    
    -- Distance exacte et barre de signal
    local distance = distances[conv.id]
    if distance then
        local distanceText = math.floor(distance) .. "b"
        screen.setCursorPos(width - 15, y)
        screen.setTextColor(getSignalColor(distance))
        screen.write(distanceText)
        
        drawSignalBar(width - 7, y, distance)
    else
        screen.setCursorPos(width - 10, y)
        screen.setTextColor(colors.gray)
        screen.write("Hors ligne")
    end
    
    -- Indicateur de nouveaux messages
    if conv.newCount > 0 then
        local indicator = "(" .. conv.newCount .. ")"
        screen.setCursorPos(x + width - #indicator - 20, y)
        screen.setTextColor(textColor)
        screen.write(indicator)
    end
    
    -- Aperçu du message
    if y + 1 <= maxLines + 2 then
        screen.setCursorPos(x, y + 1)
        screen.setTextColor(textColor)
        screen.write(string.rep(" ", width))
        screen.setCursorPos(x + 2, y + 1)
        local preview = conv.preview:sub(1, width - 4)
        screen.write(preview)
    end
    
    return {x = x, y = y, width = width, height = 2, convId = conv.id}
end

-- Écrans de l'application  
local function drawHomeScreen()
    local w, h = screen.getSize()
    screen.setBackgroundColor(colors_bg)
    screen.clear()
    
    drawHeader("Messagerie - ID: " .. myID)
    buttons = {}
    
    -- Compter les nouveaux messages
    local totalNew = 0
    for id, count in pairs(newMessages) do
        totalNew = totalNew + count
    end
    
    -- Notification de nouveaux messages
    local startY = 4
    
    if totalNew > 0 then
        screen.setBackgroundColor(colors_danger)
        screen.setTextColor(colors_text)
        screen.setCursorPos(1, startY)
        screen.clearLine()
        local notifText = totalNew .. " nouveau(x) message(s)"
        local notifX = math.floor((w - #notifText) / 2)
        screen.setCursorPos(notifX, startY)
        screen.write(notifText)
        startY = startY + 1
    end
    
    -- Liste des conversations
    local convList = {}
    for id, msgs in pairs(conversations) do
        if #msgs > 0 then
            local lastMsg = msgs[#msgs]
            local preview = lastMsg.text:sub(1, 30)
            if #lastMsg.text > 30 then preview = preview .. "..." end
            
            table.insert(convList, {
                id = id,
                preview = preview,
                newCount = newMessages[id] or 0,
                timestamp = lastMsg.timestamp
            })
        end
    end
    
    -- Trier par timestamp
    table.sort(convList, function(a, b) return a.timestamp > b.timestamp end)
    
    local currentY = startY + 1
    
    for i, conv in ipairs(convList) do
        if currentY <= h - 3 then
            local convButton = drawConversationItem(1, currentY, w, conv, conv.newCount > 0)
            table.insert(buttons, convButton)
            currentY = currentY + 3
        end
    end
    
    -- Boutons du bas
    local buttonY = h - 1
    local buttonWidth = math.floor(w / 4)
    
    table.insert(buttons, drawButton(1, buttonY, buttonWidth, 1, "Nouveau", colors_accent, colors.black))
    table.insert(buttons, drawButton(buttonWidth + 1, buttonY, buttonWidth, 1, "Contacts", colors_secondary))
    table.insert(buttons, drawButton(buttonWidth * 2 + 1, buttonY, buttonWidth, 1, "MAJ", colors.purple))
    table.insert(buttons, drawButton(buttonWidth * 3 + 1, buttonY, w - buttonWidth * 3, 1, "Quitter", colors_danger))
end

local function drawConversationScreen(convId)
    local w, h = screen.getSize()
    screen.setBackgroundColor(colors_bg)
    screen.clear()
    
    local contactName = "ID " .. convId
    for name, id in pairs(contacts) do
        if id == convId then
            contactName = name
            break
        end
    end
    
    drawHeader("Chat - " .. contactName)
    buttons = {}
    
    -- Messages avec retour à la ligne (plus d'affichage de distance)
    local msgs = conversations[convId] or {}
    local displayLines = {}
    
    -- Préparer toutes les lignes d'affichage
    for _, msg in ipairs(msgs) do
        local sender = msg.sent and "Vous" or contactName:sub(1, 8)
        local time = os.date("%H:%M", msg.timestamp / 1000)
        -- Format compact: [heure] nom: message
        local prefix = "[" .. time .. "] " .. sender .. ": "
        
        -- Calculer l'espace disponible pour le message
        local maxMsgWidth = math.max(10, w - 2 - #prefix)
        local msgLines = wrapText(msg.text, maxMsgWidth)
        
        -- Première ligne avec préfixe
        table.insert(displayLines, {
            text = prefix .. msgLines[1],
            bgColor = msg.sent and colors_primary or colors_secondary
        })
        
        -- Lignes suivantes avec indentation
        for i = 2, #msgLines do
            local indent = string.rep(" ", #prefix)
            table.insert(displayLines, {
                text = indent .. msgLines[i],
                bgColor = msg.sent and colors_primary or colors_secondary
            })
        end
    end
    
    -- Afficher les lignes (scroll automatique vers le bas)
    local availableLines = h - 4  -- Plus de lignes disponibles car pas d'affichage de distance
    local startIdx = math.max(1, #displayLines - availableLines + 1)
    local currentY = 3  -- Commencer directement à la ligne 3
    
    for i = startIdx, #displayLines do
        if currentY <= h - 2 then
            local line = displayLines[i]
            screen.setBackgroundColor(line.bgColor)
            screen.setTextColor(colors_text)
            screen.setCursorPos(1, currentY)
            screen.clearLine()
            screen.setCursorPos(2, currentY)
            screen.write(line.text:sub(1, w - 2))
            currentY = currentY + 1
        end
    end
    
    -- Marquer comme lu
    newMessages[convId] = 0
    
    -- Boutons du bas
    local buttonY = h - 1
    local buttonWidth = math.floor(w / 3)
    
    table.insert(buttons, drawButton(1, buttonY, buttonWidth, 1, "Repondre", colors_accent, colors.black))
    table.insert(buttons, drawButton(buttonWidth + 1, buttonY, buttonWidth, 1, "Actualiser", colors_secondary))
    table.insert(buttons, drawButton(buttonWidth * 2 + 1, buttonY, w - buttonWidth, 1, "Retour", colors_danger))
end

local function drawContactsScreen()
    local w, h = screen.getSize()
    screen.setBackgroundColor(colors_bg)
    screen.clear()
    
    drawHeader("Contacts")
    buttons = {}
    
    local currentY = 4
    for name, id in pairs(contacts) do
        if currentY <= h - 3 then
            screen.setBackgroundColor(colors_secondary)
            screen.setTextColor(colors_text)
            screen.setCursorPos(1, currentY)
            screen.clearLine()
            screen.setCursorPos(2, currentY)
            
            local distance = distances[id]
            local statusText = ""
            if distance then
                statusText = " [" .. math.floor(distance) .. " blocs]"
                screen.write(name .. " - ID: " .. id)
                screen.setTextColor(getSignalColor(distance))
                screen.write(statusText)
            else
                statusText = " [Hors ligne]"
                screen.write(name .. " - ID: " .. id)
                screen.setTextColor(colors.gray)
                screen.write(statusText)
            end
            
            screen.setTextColor(colors_text)
            currentY = currentY + 1
        end
    end
    
    if currentY == 4 then
        screen.setCursorPos(2, 4)
        screen.write("Aucun contact")
    end
    
    -- Boutons
    local buttonY = h - 1
    local buttonWidth = math.floor(w / 2)
    
    table.insert(buttons, drawButton(1, buttonY, buttonWidth, 1, "Ajouter", colors_accent, colors.black))
    table.insert(buttons, drawButton(buttonWidth + 1, buttonY, w - buttonWidth, 1, "Retour", colors_danger))
end

-- Fonctions de messagerie
local function sendPing(targetID)
    local message = {
        from = myID,
        to = targetID,
        type = "PING",
        timestamp = os.epoch("utc")
    }
    
    modem.transmit(MESSAGE_CHANNEL, MESSAGE_CHANNEL, message)
end

local function sendPingReply(targetID)
    local message = {
        from = myID,
        to = targetID,
        type = "PING_REPLY",
        timestamp = os.epoch("utc")
    }
    
    modem.transmit(MESSAGE_CHANNEL, MESSAGE_CHANNEL, message)
end

local function sendMessage(targetID, messageText)
    local timestamp = os.epoch("utc")
    local message = {
        from = myID,
        to = targetID,
        text = messageText,
        timestamp = timestamp,
        type = "MESSAGE"
    }
    
    modem.transmit(MESSAGE_CHANNEL, MESSAGE_CHANNEL, message)
    
    if not conversations[targetID] then
        conversations[targetID] = {}
    end
    
    table.insert(conversations[targetID], {
        from = myID,
        text = messageText,
        timestamp = timestamp,
        sent = true
    })
    
    saveData()
end

local function receiveMessage(message, distance)
    local senderID = message.from
    
    -- Enregistrer la distance exacte
    if distance then
        distances[senderID] = distance
        saveData()
    end
    
    if not conversations[senderID] then
        conversations[senderID] = {}
    end
    
    table.insert(conversations[senderID], {
        from = senderID,
        text = message.text,
        timestamp = message.timestamp,
        sent = false
    })
    
    newMessages[senderID] = (newMessages[senderID] or 0) + 1
    saveData()
    
    -- Rafraîchir l'affichage
    if currentScreen == "home" then
        drawHomeScreen()
    elseif currentScreen == "conversation" and selectedConv == senderID then
        drawConversationScreen(selectedConv)
    end
end

local function handlePing(senderID, distance)
    -- Enregistrer la distance exacte
    if distance then
        distances[senderID] = distance
        saveData()
    end
    
    -- Répondre automatiquement au ping
    sendPingReply(senderID)
    
    -- Rafraîchir l'affichage
    if currentScreen == "conversation" and selectedConv == senderID then
        drawConversationScreen(selectedConv)
    elseif currentScreen == "home" then
        drawHomeScreen()
    end
end

local function handlePingReply(senderID, distance)
    -- Enregistrer la distance exacte
    if distance then
        distances[senderID] = distance
        saveData()
    end
    
    -- Rafraîchir l'affichage
    if currentScreen == "conversation" and selectedConv == senderID then
        drawConversationScreen(selectedConv)
    elseif currentScreen == "home" then
        drawHomeScreen()
    end
end

-- Gestion des clics
local function handleClick(x, y)
    for _, button in ipairs(buttons) do
        if x >= button.x and x < button.x + button.width and
           y >= button.y and y < button.y + button.height then
            
            if currentScreen == "home" then
                if button.text == "Nouveau" then
                    screen.setCursorPos(1, 3)
                    screen.setBackgroundColor(colors_bg)
                    screen.clearLine()
                    screen.write("ID destinataire: ")
                    local targetID = tonumber(read())
                    if targetID and targetID ~= myID then
                        screen.setCursorPos(1, 4)
                        screen.clearLine()
                        screen.write("Message: ")
                        local msg = read()
                        if msg and msg ~= "" then
                            sendMessage(targetID, msg)
                            sendPing(targetID)
                            drawHomeScreen()
                        end
                    end
                elseif button.text == "Contacts" then
                    currentScreen = "contacts"
                    drawContactsScreen()
                elseif button.text == "MAJ" then
                    downloadUpdate()
                    drawHomeScreen()
                elseif button.text == "Quitter" then
                    return false
                elseif button.convId then
                    selectedConv = button.convId
                    currentScreen = "conversation"
                    sendPing(button.convId)
                    drawConversationScreen(button.convId)
                end
                
            elseif currentScreen == "conversation" then
                if button.text == "Repondre" then
                    screen.setCursorPos(1, 3)
                    screen.setBackgroundColor(colors_bg)
                    screen.clearLine()
                    screen.write("Message: ")
                    local msg = read()
                    if msg and msg ~= "" then
                        sendMessage(selectedConv, msg)
                        sendPing(selectedConv)
                        drawConversationScreen(selectedConv)
                    end
                elseif button.text == "Actualiser" then
                    sendPing(selectedConv)
                    drawConversationScreen(selectedConv)
                elseif button.text == "Retour" then
                    currentScreen = "home"
                    drawHomeScreen()
                end
                
            elseif currentScreen == "contacts" then
                if button.text == "Ajouter" then
                    screen.setCursorPos(1, 3)
                    screen.setBackgroundColor(colors_bg)
                    screen.clearLine()
                    screen.write("Nom: ")
                    local name = read()
                    if name and name ~= "" then
                        screen.setCursorPos(1, 4)
                        screen.clearLine()
                        screen.write("ID: ")
                        local id = tonumber(read())
                        if id and id ~= myID then
                            contacts[name] = id
                            saveData()
                            drawContactsSearch()
                        end
                    end
                elseif button.text == "Retour" then
                    currentScreen = "home"
                    drawHomeScreen()
                end
            end
            
            return true
        end
    end
    return true
end

-- Gestionnaire d'événements principal
local function messageListener()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if channel == MESSAGE_CHANNEL and type(message) == "table" then
            if message.to == myID then
                if message.type == "MESSAGE" then
                    receiveMessage(message, distance)
                elseif message.type == "PING" then
                    handlePing(message.from, distance)
                elseif message.type == "PING_REPLY" then
                    handlePingReply(message.from, distance)
                end
            end
        end
    end
end

local function inputHandler()
    while true do
        local event, button, x, y = os.pullEvent()
        
        if event == "monitor_touch" or event == "mouse_click" then
            if not handleClick(x, y) then
                break
            end
        end
    end
end

-- Programme principal
local function main()
    -- Ouvrir le modem sur le bon canal
    if not modem.isOpen(MESSAGE_CHANNEL) then
        modem.open(MESSAGE_CHANNEL)
    end
    
    loadData()
    initScreen()
    drawHomeScreen()
    
    -- Lancer les threads parallèles
    parallel.waitForAny(messageListener, inputHandler)
    
    screen.setBackgroundColor(colors.black)
    screen.setTextColor(colors.white)
    screen.clear()
    screen.setCursorPos(1, 1)
    print("Messagerie fermée.")
    
    modem.close(MESSAGE_CHANNEL)
end

-- Démarrage
main()