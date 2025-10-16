ESX = exports['es_extended']:getSharedObject()

local npcPed = nil
local currentPumpkin = nil
local currentPumpkinCoords = nil
local pumpkinBlip = nil
local zombies = {}
local inHalloweenZone = false
local savedHour = nil
local savedMinute = nil
local missionActive = false
local pumpkinsCollected = 0
local usedLocations = {}
local missionStartTime = 0
local attackStarted = false
local eventVehicle = nil
local canOpenMenu = true
local originalClothing = nil
local backgroundMusicId = nil
local lastDamageTime = 0
local hasRewardPending = false
local currentLobby = nil
local isLobbyLeader = false
local lobbyPlayers = {}
local syncedZombies = {}

function CreateNPC()
    local model = GetHashKey(Config.NPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end
    
    npcPed = CreatePed(4, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1.0, Config.NPC.coords.w, false, true)
    SetEntityHeading(npcPed, Config.NPC.coords.w)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    
    if Config.NPC.blip.enabled then
        local blip = AddBlipForCoord(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)
        SetBlipSprite(blip, Config.NPC.blip.sprite)
        SetBlipColour(blip, Config.NPC.blip.color)
        SetBlipScale(blip, Config.NPC.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.NPC.blip.name)
        EndTextCommandSetBlipName(blip)
    end
end

function SpawnPumpkin()
    if currentLobby then
        TriggerServerEvent('halloween:requestPumpkinSpawn', currentLobby, usedLocations)
    else
        local availableLocations = {}
        for i, location in ipairs(Config.PumpkinLocations) do
            if not usedLocations[i] then
                table.insert(availableLocations, {index = i, coords = location})
            end
        end
        
        if #availableLocations == 0 then
            return false
        end
        
        local selected = availableLocations[math.random(#availableLocations)]
        CreatePumpkinAtLocation(selected.index, selected.coords)
        return true
    end
end

function CreatePumpkinAtLocation(locationIndex, coords)
    currentPumpkinCoords = coords
    usedLocations[locationIndex] = true
    
    currentPumpkin = CreateObject(GetHashKey("prop_veg_crop_03_pump"), currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z - 1.0, true, true, true)
    PlaceObjectOnGroundProperly(currentPumpkin)
    SetEntityHeading(currentPumpkin, math.random(0, 360))
    
    pumpkinBlip = AddBlipForCoord(currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z)
    SetBlipSprite(pumpkinBlip, 484)
    SetBlipColour(pumpkinBlip, 47)
    SetBlipScale(pumpkinBlip, 0.9)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Calabaza " .. (pumpkinsCollected + 1) .. "/" .. Config.Mission.pumpkinsToCollect)
    EndTextCommandSetBlipName(pumpkinBlip)
    
    SpawnZombies()
    attackStarted = false
end

function SpawnZombies()
    DeleteZombies()
    
    RequestAnimSet("move_m@drunk@verydrunk")
    while not HasAnimSetLoaded("move_m@drunk@verydrunk") do
        Citizen.Wait(100)
    end
    
    for i = 1, Config.Zombies.amount do
        local zombieModel = GetHashKey(Config.Zombies.models[math.random(#Config.Zombies.models)])
        RequestModel(zombieModel)
        while not HasModelLoaded(zombieModel) do
            Citizen.Wait(100)
        end
        
        local offset = vector3(math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), 0)
        local spawnCoords = currentPumpkinCoords + offset
        local groundZ = spawnCoords.z
        local found, zCoord = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 999.0, false)
        if found then
            groundZ = zCoord
        end
        
        local zombie = CreatePed(4, zombieModel, spawnCoords.x, spawnCoords.y, groundZ, 0.0, false, true)
        
        SetEntityAsMissionEntity(zombie, true, true)
        SetEntityVisible(zombie, true, false)
        SetEntityAlpha(zombie, 255, false)
        SetEntityCollision(zombie, true, true)
        SetPedCanBeTargetted(zombie, true)
        SetPedCanBeTargettedByPlayer(zombie, PlayerId(), true)
        SetEntityHealth(zombie, 200)
        SetPedMaxHealth(zombie, 200)
        SetPedArmour(zombie, 0)
        
        if not Config.Zombies.useWeapons then
            SetPedMovementClipset(zombie, "move_m@drunk@verydrunk", 1.0)
        end
        
        SetPedRelationshipGroupHash(zombie, GetHashKey("MISSION2"))
        SetPedFleeAttributes(zombie, 0, false)
        SetPedCombatAttributes(zombie, 46, true)
        SetPedCombatAttributes(zombie, 5, true)
        SetPedCombatMovement(zombie, 2)
        SetPedSeeingRange(zombie, 100.0)
        SetPedHearingRange(zombie, 100.0)
        SetPedAlertness(zombie, 3)
        SetBlockingOfNonTemporaryEvents(zombie, true)
        SetPedPathCanUseClimbovers(zombie, false)
        SetPedPathCanUseLadders(zombie, false)
        SetPedConfigFlag(zombie, 208, true)
        SetPedConfigFlag(zombie, 281, true)
        SetCanAttackFriendly(zombie, false, false)
        
        if Config.Zombies.useWeapons then
            local weapon = Config.Zombies.weapons[math.random(#Config.Zombies.weapons)]
            GiveWeaponToPed(zombie, GetHashKey(weapon), 250, false, true)
            SetCurrentPedWeapon(zombie, GetHashKey(weapon), true)
            SetPedCombatAbility(zombie, 100)
            SetPedCombatRange(zombie, 2)
            SetPedAccuracy(zombie, Config.Zombies.accuracy)
        else
            SetPedCombatAbility(zombie, 100)
            SetPedCombatRange(zombie, 0)
        end
        
        ApplyPedDamagePack(zombie, "BigHitByVehicle", 0.0, 9.0)
        SetPedCanRagdoll(zombie, true)
        
        DisablePedPainAudio(zombie, false)
        local voices = {"PAIN_VOICE_1_MALE", "SCREAM_VOICE_1_MALE", "DEATH_VOICE_1_MALE"}
        SetAmbientVoiceName(zombie, voices[math.random(#voices)])
        
        SetPedEyeColor(zombie, 2)
        
        SetEntityDrawOutline(zombie, false)
        FreezeEntityPosition(zombie, false)
        
        TaskWanderInArea(zombie, currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z, 10.0, 0.5, 0.5)
        
        table.insert(zombies, zombie)
    end
    
    attackStarted = false
end


function FollowPlayer()
    local player = PlayerPedId()
    
    for _, zombie in ipairs(zombies) do
        if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
            TaskCombatPed(zombie, player, -1, 0)
        end
    end
end

function DeleteZombies()
    for _, zombie in ipairs(zombies) do
        if DoesEntityExist(zombie) then
            ClearPedTasksImmediately(zombie)
            SetEntityAsMissionEntity(zombie, false, true)
            DeletePed(zombie)
            DeleteEntity(zombie)
        end
    end
    
    zombies = {}
    syncedZombies = {}
end

function StopHalloweenEffects()
    inHalloweenZone = false
end

function StartMission()
    if missionActive then
        ESX.ShowNotification("Ya tienes una misión activa")
        return
    end
    
    
    missionActive = true
    pumpkinsCollected = 0
    usedLocations = {}
    missionStartTime = GetGameTimer()
    
    savedHour = GetClockHours()
    savedMinute = GetClockMinutes()
    
    StartBackgroundMusic()
    
    TriggerEvent('chat:addMessage', { 
        args = {"Halloween", "Misión iniciada! Recolecta " .. Config.Mission.pumpkinsToCollect .. " calabazas antes de que se acabe el tiempo!"} 
    })
    
    Citizen.Wait(500)
    SpawnPumpkin()
end

function StartBackgroundMusic()
    backgroundMusicId = GetSoundId()
    PlaySoundFrontend(backgroundMusicId, "DISTANT_TRAIN", "TRAIN_SOUNDS", true)
end

function StopBackgroundMusic()
    if backgroundMusicId then
        StopSound(backgroundMusicId)
        ReleaseSoundId(backgroundMusicId)
        backgroundMusicId = nil
    end
end

function EndMission(completed, isDeath)
    if not missionActive then return end
    
    missionActive = false
    attackStarted = false
    
    if currentPumpkin and DoesEntityExist(currentPumpkin) then
        SetEntityAsMissionEntity(currentPumpkin, false, true)
        DeleteObject(currentPumpkin)
        DeleteEntity(currentPumpkin)
        currentPumpkin = nil
    end
    
    if pumpkinBlip and DoesBlipExist(pumpkinBlip) then
        RemoveBlip(pumpkinBlip)
        pumpkinBlip = nil
    end
    
    DeleteZombies()
    
    StopHalloweenEffects()
    StopBackgroundMusic()
    
    AnimpostfxStop("DrugsMichaelAliensFight")
    StopScreenEffect("DeathFailMPIn")
    AnimpostfxStop("DeathFailNeutralIn")
    StopScreenEffect("ExplosionJosh3")
    
    if completed then
        TriggerServerEvent('halloween:completeMission', pumpkinsCollected)
        hasRewardPending = true
        if eventVehicle and DoesEntityExist(eventVehicle) then
            TriggerEvent('chat:addMessage', { 
                args = {"Halloween", "Misión completada! Vuelve al NPC para devolver el vehículo y recibir tu recompensa"} 
            })
        else
            TriggerEvent('chat:addMessage', { 
                args = {"Halloween", "Misión completada! Vuelve a hablar con el NPC para recibir tu recompensa"} 
            })
        end
    else
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        SetTimecycleModifierStrength(0.0)
        
        ClearWeatherTypePersist()
        ClearOverrideWeather()
        SetWeatherTypeNow('CLEAR')
        SetWeatherTypeNowPersist('CLEAR')
        
        if savedHour and savedMinute then
            NetworkOverrideClockTime(savedHour, savedMinute, 0)
        end
        
        if eventVehicle and DoesEntityExist(eventVehicle) then
            ESX.Game.DeleteVehicle(eventVehicle)
            eventVehicle = nil
        end
        RestoreOriginalClothing()
        
        if isDeath then
            TriggerEvent('chat:addMessage', { 
                args = {"Halloween", "Moriste durante la misión. Los demás jugadores continúan."} 
            })
        else
            TriggerEvent('chat:addMessage', { 
                args = {"Halloween", "Misión fallida. Solo recolectaste " .. pumpkinsCollected .. "/" .. Config.Mission.pumpkinsToCollect .. " calabazas"} 
            })
        end
    end
    
    pumpkinsCollected = 0
    usedLocations = {}
end

function CleanupHalloweenEffects()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetTimecycleModifierStrength(0.0)
    
    ClearWeatherTypePersist()
    ClearOverrideWeather()
    SetWeatherTypeNow('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    
    if savedHour and savedMinute then
        NetworkOverrideClockTime(savedHour, savedMinute, 0)
        savedHour = nil
        savedMinute = nil
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    
    AddRelationshipGroup("MISSION2")
    SetRelationshipBetweenGroups(0, GetHashKey("MISSION2"), GetHashKey("MISSION2"))
    SetRelationshipBetweenGroups(5, GetHashKey("MISSION2"), GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("MISSION2"))
    
    CreateNPC()
end)

function OpenMainMenu()
    local pumpkinCount = exports.ox_inventory:Search('count', 'pumpkin')
    
    local menuOptions = {}
    
    if hasRewardPending then
        if eventVehicle and DoesEntityExist(eventVehicle) then
            table.insert(menuOptions, {
                title = 'Devolver Vehículo y Reclamar Recompensa',
                description = 'Debes devolver el vehículo para recibir tu recompensa',
                icon = 'fas fa-motorcycle',
                iconColor = '#e67e22',
                onSelect = function()
                    ESX.Game.DeleteVehicle(eventVehicle)
                    eventVehicle = nil
                    RestoreOriginalClothing()
                    CleanupHalloweenEffects()
                    TriggerServerEvent('halloween:claimReward')
                    hasRewardPending = false
                    ESX.ShowNotification('Vehículo devuelto. Recompensa reclamada')
                end
            })
        else
            table.insert(menuOptions, {
                title = 'Reclamar Recompensa',
                description = 'Completaste la misión! Reclama tu recompensa',
                icon = 'fas fa-gift',
                iconColor = '#f1c40f',
                onSelect = function()
                    RestoreOriginalClothing()
                    CleanupHalloweenEffects()
                    TriggerServerEvent('halloween:claimReward')
                    hasRewardPending = false
                    ESX.ShowNotification('Recompensa reclamada')
                end
            })
        end
    end
    
    if Config.Mission.multiplayerMode then
        table.insert(menuOptions, {
            title = currentLobby and 'Lobby Activo (' .. #lobbyPlayers .. '/' .. Config.Mission.maxPlayersInLobby .. ')' or 'Gestionar Lobby',
            description = currentLobby and 'Administrar tu lobby actual' or 'Crear o unirse a un lobby para jugar en grupo',
            icon = 'fas fa-users',
            iconColor = currentLobby and '#3498db' or '#95a5a6',
            onSelect = function()
                OpenLobbyMenu()
            end
        })
    end
    
    table.insert(menuOptions, {
        title = 'Iniciar Misión',
        description = missionActive and 'Ya tienes una misión activa' or (currentLobby and isLobbyLeader and 'Iniciar misión para todo el lobby' or (currentLobby and not isLobbyLeader and 'Solo el líder puede iniciar' or 'Recolecta ' .. Config.Mission.pumpkinsToCollect .. ' calabazas')),
        icon = 'fas fa-play',
        iconColor = missionActive and '#95a5a6' or (currentLobby and not isLobbyLeader and '#95a5a6' or '#2ecc71'),
        onSelect = function()
            if missionActive then
                ESX.ShowNotification('Ya tienes una misión activa. Termínala primero.')
            elseif currentLobby and not isLobbyLeader then
                ESX.ShowNotification('Solo el líder del lobby puede iniciar la misión')
            else
                if currentLobby then
                    TriggerServerEvent('halloween:startLobbyMission', currentLobby)
                else
                    StartMission()
                end
            end
        end
    })
    
    table.insert(menuOptions, {
        title = 'Detener Misión',
        description = not missionActive and 'No hay misión activa' or 'Cancelar la misión actual',
        icon = 'fas fa-stop',
        iconColor = not missionActive and '#95a5a6' or '#e74c3c',
        onSelect = function()
            if not missionActive then
                ESX.ShowNotification('No hay ninguna misión activa para detener.')
            elseif hasRewardPending then
                ESX.ShowNotification('Debes reclamar tu recompensa primero')
            else
                EndMission(false)
                ESX.ShowNotification('Misión cancelada')
            end
        end
    })
    
    table.insert(menuOptions, {
        title = 'Intercambiar Calabazas',
        description = pumpkinCount == 0 and 'No tienes calabazas' or 'Tienes: ' .. pumpkinCount .. ' calabazas',
        icon = 'fas fa-exchange-alt',
        iconColor = pumpkinCount == 0 and '#95a5a6' or '#f39c12',
        onSelect = function()
            if pumpkinCount == 0 then
                ESX.ShowNotification('No tienes calabazas para intercambiar. Completa misiones para obtenerlas.')
            else
                OpenExchangeMenu()
            end
        end
    })
    
    table.insert(menuOptions, {
        title = 'Vehículo de Evento',
        description = not missionActive and 'Requiere misión activa' or 'Solicitar vehículo especial',
        icon = 'fas fa-motorcycle',
        iconColor = not missionActive and '#95a5a6' or '#9b59b6',
        onSelect = function()
            if not missionActive then
                ESX.ShowNotification('Necesitas tener una misión activa para obtener el vehículo.')
            else
                SpawnEventVehicle()
            end
        end
    })
    
    table.insert(menuOptions, {
        title = 'Ropa de Evento',
        description = not missionActive and 'Requiere misión activa' or 'Obtener outfit de Halloween',
        icon = 'fas fa-tshirt',
        iconColor = not missionActive and '#95a5a6' or '#e67e22',
        onSelect = function()
            if not missionActive then
                ESX.ShowNotification('Necesitas tener una misión activa para obtener la ropa.')
            else
                ApplyEventClothing()
            end
        end
    })
    
    lib.registerContext({
        id = 'halloween_main_menu',
        title = 'Evento Halloween',
        options = menuOptions
    })
    
    lib.showContext('halloween_main_menu')
end

function OpenExchangeMenu()
    local pumpkinCount = exports.ox_inventory:Search('count', 'pumpkin')
    
    local exchangeOptions = {}
    
    for i, exchange in ipairs(Config.Exchange) do
        local canExchange = pumpkinCount >= exchange.pumpkinsRequired
        local missing = exchange.pumpkinsRequired - pumpkinCount
        
        table.insert(exchangeOptions, {
            title = exchange.label,
            description = canExchange and 'Requiere: ' .. exchange.pumpkinsRequired .. ' calabazas | Tienes: ' .. pumpkinCount or 'Te faltan ' .. missing .. ' calabazas (Tienes: ' .. pumpkinCount .. ')',
            icon = exchange.icon,
            iconColor = canExchange and exchange.iconColor or '#95a5a6',
            onSelect = function()
                if not canExchange then
                    ESX.ShowNotification('Te faltan ' .. missing .. ' calabazas para este intercambio.')
                else
                    TriggerServerEvent('halloween:exchange', i)
                    lib.hideContext()
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'exchange_menu',
        title = 'Intercambiar Calabazas',
        menu = 'halloween_main_menu',
        options = exchangeOptions
    })
    
    lib.showContext('exchange_menu')
end

function OpenLobbyMenu()
    if currentLobby then
        local lobbyOptions = {}
        
        table.insert(lobbyOptions, {
            title = 'Jugadores en el Lobby',
            description = #lobbyPlayers .. ' jugadores conectados',
            icon = 'fas fa-users',
            iconColor = '#3498db',
            disabled = true
        })
        
        for _, playerId in ipairs(lobbyPlayers) do
            table.insert(lobbyOptions, {
                title = 'Jugador ID: ' .. playerId,
                icon = playerId == GetPlayerServerId(PlayerId()) and 'fas fa-crown' or 'fas fa-user',
                iconColor = playerId == GetPlayerServerId(PlayerId()) and '#f1c40f' or '#95a5a6',
                disabled = true
            })
        end
        
        if isLobbyLeader then
            if missionActive then
                table.insert(lobbyOptions, {
                    title = 'Cancelar Misión del Lobby',
                    description = 'Cancelar la misión para todos los jugadores',
                    icon = 'fas fa-ban',
                    iconColor = '#e74c3c',
                    onSelect = function()
                        TriggerServerEvent('halloween:cancelLobbyMission', currentLobby)
                        ESX.ShowNotification('Misión cancelada para todos')
                        lib.hideContext()
                    end
                })
            end
            
            table.insert(lobbyOptions, {
                title = 'Disolver Lobby',
                description = 'Cerrar el lobby actual',
                icon = 'fas fa-times-circle',
                iconColor = '#e74c3c',
                onSelect = function()
                    TriggerServerEvent('halloween:dissolveLobby', currentLobby)
                    currentLobby = nil
                    isLobbyLeader = false
                    lobbyPlayers = {}
                    
                    local playerPed = PlayerPedId()
                    SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
                    SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
                    
                    ESX.ShowNotification('Lobby disuelto')
                    lib.hideContext()
                end
            })
        else
            table.insert(lobbyOptions, {
                title = 'Salir del Lobby',
                description = 'Abandonar el lobby actual',
                icon = 'fas fa-sign-out-alt',
                iconColor = '#e67e22',
                onSelect = function()
                    TriggerServerEvent('halloween:leaveLobby', currentLobby)
                    currentLobby = nil
                    isLobbyLeader = false
                    lobbyPlayers = {}
                    
                    local playerPed = PlayerPedId()
                    SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
                    SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
                    
                    ESX.ShowNotification('Saliste del lobby')
                    lib.hideContext()
                end
            })
        end
        
        lib.registerContext({
            id = 'lobby_menu',
            title = 'Lobby Halloween',
            menu = 'halloween_main_menu',
            options = lobbyOptions
        })
        
        lib.showContext('lobby_menu')
    else
        local lobbyOptions = {
            {
                title = 'Crear Lobby',
                description = 'Crear un nuevo lobby para jugar con amigos',
                icon = 'fas fa-plus-circle',
                iconColor = '#2ecc71',
                onSelect = function()
                    TriggerServerEvent('halloween:createLobby')
                    lib.hideContext()
                end
            },
            {
                title = 'Unirse a Lobby Cercano',
                description = 'Buscar lobbies de jugadores cercanos',
                icon = 'fas fa-search',
                iconColor = '#3498db',
                onSelect = function()
                    TriggerServerEvent('halloween:findNearbyLobbies')
                    lib.hideContext()
                end
            },
            {
                title = 'Jugar Solo',
                description = 'Iniciar misión individual sin lobby',
                icon = 'fas fa-user',
                iconColor = '#95a5a6',
                onSelect = function()
                    lib.hideContext()
                end
            }
        }
        
        lib.registerContext({
            id = 'lobby_menu',
            title = 'Lobby Halloween',
            menu = 'halloween_main_menu',
            options = lobbyOptions
        })
        
        lib.showContext('lobby_menu')
    end
end

function SpawnEventVehicle()
    if eventVehicle and DoesEntityExist(eventVehicle) then
        ESX.Game.DeleteVehicle(eventVehicle)
        Citizen.Wait(100)
    end
    
    if currentLobby then
        TriggerServerEvent('halloween:requestVehicleSpawn', currentLobby)
    else
        local playerPed = PlayerPedId()
        local spawnCoords = Config.Vehicle.baseCoords
        
        ESX.Game.SpawnVehicle(Config.Vehicle.model, spawnCoords, spawnCoords.w, function(vehicle)
            eventVehicle = vehicle
            SetVehicleNumberPlateText(vehicle, Config.Vehicle.plate)
            
            if Config.Vehicle.autoWarp then
                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                ESX.ShowNotification('Vehículo de Halloween spawneado')
            else
                TaskEnterVehicle(playerPed, vehicle, -1, -1, 1.0, 1, 0)
                ESX.ShowNotification('Caminando hacia el vehículo...')
            end
        end)
    end
end

RegisterNetEvent('halloween:spawnVehicleAtPosition')
AddEventHandler('halloween:spawnVehicleAtPosition', function(spawnCoords)
    if eventVehicle and DoesEntityExist(eventVehicle) then
        ESX.Game.DeleteVehicle(eventVehicle)
        Citizen.Wait(100)
    end
    
    local playerPed = PlayerPedId()
    
    ESX.Game.SpawnVehicle(Config.Vehicle.model, spawnCoords, spawnCoords.w, function(vehicle)
        eventVehicle = vehicle
        SetVehicleNumberPlateText(vehicle, Config.Vehicle.plate)
        
        if Config.Vehicle.autoWarp then
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            ESX.ShowNotification('Vehículo de Halloween spawneado')
        else
            TaskEnterVehicle(playerPed, vehicle, -1, -1, 1.0, 1, 0)
            ESX.ShowNotification('Caminando hacia el vehículo...')
        end
    end)
end)

function SaveOriginalClothing()
    local playerPed = PlayerPedId()
    originalClothing = {
        mask = {drawable = GetPedDrawableVariation(playerPed, 1), texture = GetPedTextureVariation(playerPed, 1)},
        torso = {drawable = GetPedDrawableVariation(playerPed, 3), texture = GetPedTextureVariation(playerPed, 3)},
        legs = {drawable = GetPedDrawableVariation(playerPed, 4), texture = GetPedTextureVariation(playerPed, 4)},
        bag = {drawable = GetPedDrawableVariation(playerPed, 5), texture = GetPedTextureVariation(playerPed, 5)},
        shoes = {drawable = GetPedDrawableVariation(playerPed, 6), texture = GetPedTextureVariation(playerPed, 6)},
        accessory = {drawable = GetPedDrawableVariation(playerPed, 7), texture = GetPedTextureVariation(playerPed, 7)},
        undershirt = {drawable = GetPedDrawableVariation(playerPed, 8), texture = GetPedTextureVariation(playerPed, 8)},
        kevlar = {drawable = GetPedDrawableVariation(playerPed, 9), texture = GetPedTextureVariation(playerPed, 9)},
        torso2 = {drawable = GetPedDrawableVariation(playerPed, 11), texture = GetPedTextureVariation(playerPed, 11)}
    }
end

function RestoreOriginalClothing()
    if not originalClothing then return end
    
    local playerPed = PlayerPedId()
    SetPedComponentVariation(playerPed, 1, originalClothing.mask.drawable, originalClothing.mask.texture, 0)
    SetPedComponentVariation(playerPed, 3, originalClothing.torso.drawable, originalClothing.torso.texture, 0)
    SetPedComponentVariation(playerPed, 4, originalClothing.legs.drawable, originalClothing.legs.texture, 0)
    SetPedComponentVariation(playerPed, 5, originalClothing.bag.drawable, originalClothing.bag.texture, 0)
    SetPedComponentVariation(playerPed, 6, originalClothing.shoes.drawable, originalClothing.shoes.texture, 0)
    SetPedComponentVariation(playerPed, 7, originalClothing.accessory.drawable, originalClothing.accessory.texture, 0)
    SetPedComponentVariation(playerPed, 8, originalClothing.undershirt.drawable, originalClothing.undershirt.texture, 0)
    SetPedComponentVariation(playerPed, 9, originalClothing.kevlar.drawable, originalClothing.kevlar.texture, 0)
    SetPedComponentVariation(playerPed, 11, originalClothing.torso2.drawable, originalClothing.torso2.texture, 0)
    
    originalClothing = nil
end

function ApplyEventClothing()
    SaveOriginalClothing()
    
    local playerPed = PlayerPedId()
    local sex = GetEntityModel(playerPed) == GetHashKey("mp_f_freemode_01") and "female" or "male"
    local clothing = Config.Clothing[sex]
    
    SetPedComponentVariation(playerPed, 1, clothing.mask.drawable, clothing.mask.texture, 0)
    SetPedComponentVariation(playerPed, 3, clothing.torso.drawable, clothing.torso.texture, 0)
    SetPedComponentVariation(playerPed, 4, clothing.legs.drawable, clothing.legs.texture, 0)
    SetPedComponentVariation(playerPed, 5, clothing.bag.drawable, clothing.bag.texture, 0)
    SetPedComponentVariation(playerPed, 6, clothing.shoes.drawable, clothing.shoes.texture, 0)
    SetPedComponentVariation(playerPed, 7, clothing.accessory.drawable, clothing.accessory.texture, 0)
    SetPedComponentVariation(playerPed, 8, clothing.undershirt.drawable, clothing.undershirt.texture, 0)
    SetPedComponentVariation(playerPed, 9, clothing.kevlar.drawable, clothing.kevlar.texture, 0)
    SetPedComponentVariation(playerPed, 11, clothing.torso2.drawable, clothing.torso2.texture, 0)
    
    ESX.ShowNotification('Ropa de Halloween aplicada')
end

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local npcCoords = Config.NPC.coords
        local distToNPC = #(playerCoords - vector3(npcCoords.x, npcCoords.y, npcCoords.z))
        
        if distToNPC < 2.5 then
            sleep = 0
            ESX.ShowHelpNotification("Presiona ~INPUT_CONTEXT~ para abrir el menú de Halloween")
            if IsControlJustPressed(0, 38) and canOpenMenu then
                canOpenMenu = false
                OpenMainMenu()
                Citizen.SetTimeout(500, function()
                    canOpenMenu = true
                end)
            end
        end
        
        if missionActive and currentPumpkin then
            local dist = #(playerCoords - currentPumpkinCoords)
            
            if dist < 100.0 then
                sleep = 0
                
                if dist < Config.Effects.zoneRadius then
                    DrawLightWithRange(currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z + 2.0, Config.Effects.lightColor[1], Config.Effects.lightColor[2], Config.Effects.lightColor[3], Config.Effects.lightRange, Config.Effects.lightIntensity)
                    
                    if dist < 30.0 then
                        if not AnimpostfxIsRunning("DrugsMichaelAliensFight") then
                            AnimpostfxPlay("DrugsMichaelAliensFight", 0, false)
                        end
                    else
                        AnimpostfxStop("DrugsMichaelAliensFight")
                    end
                end
                
            if dist < Config.Zombies.attackDistance and not attackStarted then
                if currentLobby then
                    TriggerServerEvent('halloween:activateZombieAttack', currentLobby)
                else
                    FollowPlayer()
                    attackStarted = true
                end
            end
                
                if dist < 15.0 then
                    DrawMarker(20, currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z + 0.5, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 255, 100, 0, 150, false, true, 2, nil, nil, false)
                end
                
            if dist < 2.0 then
                    ESX.ShowHelpNotification("~INPUT_CONTEXT~ Recolectar calabaza (" .. (pumpkinsCollected + 1) .. "/" .. Config.Mission.pumpkinsToCollect .. ")")
                if IsControlJustPressed(0, 38) then
                        if currentLobby then
                            TriggerServerEvent('halloween:collectPumpkinLobby', currentLobby)
                        else
                            TriggerServerEvent('halloween:collectPumpkin')
                            
                            DeleteObject(currentPumpkin)
                            RemoveBlip(pumpkinBlip)
                            
                            currentPumpkin = nil
                            pumpkinBlip = nil
                            
                            pumpkinsCollected = pumpkinsCollected + 1
                            
                            TriggerEvent('chat:addMessage', { 
                                args = {"Halloween", "Calabaza recolectada " .. pumpkinsCollected .. "/" .. Config.Mission.pumpkinsToCollect} 
                            })
                            
                            if pumpkinsCollected >= Config.Mission.pumpkinsToCollect then
                                EndMission(true)
                            else
                                SpawnPumpkin()
                            end
                        end
                    end
                end
            end
        else
            AnimpostfxStop("DrugsMichaelAliensFight")
        end
        
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 5000 + math.random(3000, 7000)
        
        if missionActive and currentPumpkin then
            local coords = GetEntityCoords(PlayerPedId())
            local dist = #(coords - currentPumpkinCoords)
            if dist < Config.Effects.zoneRadius then
                ForceLightningFlash()
                Citizen.Wait(100)
                local x, y, z = table.unpack(currentPumpkinCoords)
                AddExplosion(x + math.random(-15, 15), y + math.random(-15, 15), z + 50.0, 'EXPLOSION_FLARE', 0.0, true, true, 0.0, false)
            end
        else
            wait = 10000
        end
        
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    while true do
        if missionActive then
            NetworkOverrideClockTime(0, 0, 0)
            SetWeatherTypePersist('THUNDER')
            SetWeatherTypeNowPersist('THUNDER')
            SetRainLevel(0.5)
            SetWindSpeed(15.0)
            SetTimecycleModifier('MP_Celeb_Lose')
            SetTimecycleModifierStrength(0.8)
            SetExtraTimecycleModifier('cinema')
            SetExtraTimecycleModifierStrength(0.5)
            Citizen.Wait(1000)
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if missionActive then
            local elapsed = (GetGameTimer() - missionStartTime) / 1000
            if elapsed >= Config.Mission.timeLimit then
                EndMission(false)
            end
            Citizen.Wait(1000)
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 1000
        
        if missionActive and #zombies > 0 and not Config.Zombies.useWeapons then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local currentHealth = GetEntityHealth(playerPed)
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
                    local zombieCoords = GetEntityCoords(zombie)
                    local dist = #(playerCoords - zombieCoords)
                    
                    if dist < Config.Zombies.damageDistanceWithoutWeapons then
                        wait = 500
                        if currentHealth > 100 then
                            SetEntityHealth(playerPed, currentHealth - Config.Zombies.damagePerSecond)
                            lastDamageTime = GetGameTimer()
                            
                            StartScreenEffect("ExplosionJosh3", 0, false)
                            Citizen.SetTimeout(500, function()
                                StopScreenEffect("ExplosionJosh3")
                            end)
                        end
                    end
                end
            end
            
            if currentHealth < 150 then
                local intensity = 1.0 - (currentHealth / 200)
                StartScreenEffect("DeathFailMPIn", 0, false)
                AnimpostfxPlay("DeathFailNeutralIn", 0, false)
            else
                StopScreenEffect("DeathFailMPIn")
                AnimpostfxStop("DeathFailNeutralIn")
            end
        else
            wait = 5000
        end
        
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000 + math.random(2000, 4000))
        
        if missionActive and #zombies > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
                    local zombieCoords = GetEntityCoords(zombie)
                    local dist = #(playerCoords - zombieCoords)
                    
                    if dist < 25.0 then
                        local zombieSounds = {"PAIN", "COWER", "FLEE_SHOCKED", "WHIMPER", "DYING"}
                        PlayPain(zombie, math.random(1, 25), 0)
                        
                        if math.random(1, 3) == 1 then
                            local soundId = GetSoundId()
                            PlaySoundFromEntity(soundId, "TIMER_STOP", zombie, "HUD_MINI_GAME_SOUNDSET", false, 0)
                            Citizen.SetTimeout(800, function()
                                StopSound(soundId)
                                ReleaseSoundId(soundId)
                            end)
                        end
                    end
                end
            end
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000 + math.random(5000, 10000))
        
        if missionActive then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, "DISTANT_SIREN", playerCoords.x, playerCoords.y, playerCoords.z, "PROLOGUE_2_SOUNDS", false, 50.0, false)
            Citizen.SetTimeout(3000, function()
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end)
        else
            Citizen.Wait(10000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(15000 + math.random(5000, 10000))
        
        if missionActive then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, "Retro_Explosion", playerCoords.x + math.random(-20, 20), playerCoords.y + math.random(-20, 20), playerCoords.z, "MP_LOBBY_SOUNDS", false, 30.0, false)
            ReleaseSoundId(soundId)
        else
            Citizen.Wait(10000)
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        
        if not missionActive then
            if currentPumpkin and DoesEntityExist(currentPumpkin) then
                SetEntityAsMissionEntity(currentPumpkin, false, true)
                DeleteObject(currentPumpkin)
                DeleteEntity(currentPumpkin)
                currentPumpkin = nil
            end
            
            if pumpkinBlip and DoesBlipExist(pumpkinBlip) then
                RemoveBlip(pumpkinBlip)
                pumpkinBlip = nil
            end
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) then
                    ClearPedTasksImmediately(zombie)
                    SetEntityAsMissionEntity(zombie, false, true)
                    DeletePed(zombie)
                    DeleteEntity(zombie)
                end
            end
            zombies = {}
            syncedZombies = {}
        end
        
        Citizen.Wait(3000)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        
        if missionActive and attackStarted then
            local playerPed = PlayerPedId()
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
                    TaskCombatPed(zombie, playerPed, -1, 0)
                end
            end
        else
            Citizen.Wait(2000)
        end
    end
end)

RegisterNetEvent('halloween:lobbyCreated')
AddEventHandler('halloween:lobbyCreated', function(lobbyId, players)
    currentLobby = lobbyId
    isLobbyLeader = true
    lobbyPlayers = players
    ESX.ShowNotification('Lobby creado exitosamente')
end)

RegisterNetEvent('halloween:becomeLeader')
AddEventHandler('halloween:becomeLeader', function()
    isLobbyLeader = true
    ESX.ShowNotification('Ahora eres el líder del lobby')
    
    if missionActive and currentPumpkinCoords then
        TriggerServerEvent('halloween:requestZombieSpawn', currentLobby, currentPumpkinCoords)
    end
end)

RegisterNetEvent('halloween:activateAttack')
AddEventHandler('halloween:activateAttack', function()
    if not attackStarted then
        attackStarted = true
        FollowPlayer()
    end
end)

RegisterNetEvent('halloween:joinedLobby')
AddEventHandler('halloween:joinedLobby', function(lobbyId, players)
    currentLobby = lobbyId
    isLobbyLeader = false
    lobbyPlayers = players
    ESX.ShowNotification('Te uniste al lobby')
end)

RegisterNetEvent('halloween:lobbyUpdated')
AddEventHandler('halloween:lobbyUpdated', function(players, newPlayerName)
    lobbyPlayers = players
    if newPlayerName then
        TriggerEvent('chat:addMessage', { 
            args = {"Lobby", newPlayerName .. " se unió al lobby"} 
        })
    end
    
    if #players == 0 then
        currentLobby = nil
        isLobbyLeader = false
        lobbyPlayers = {}
        
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
        SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
    end
end)

RegisterNetEvent('halloween:lobbyCancelMission')
AddEventHandler('halloween:lobbyCancelMission', function()
    if missionActive then
        missionActive = false
        attackStarted = false
        
        if currentPumpkin and DoesEntityExist(currentPumpkin) then
            SetEntityAsMissionEntity(currentPumpkin, false, true)
            DeleteObject(currentPumpkin)
            DeleteEntity(currentPumpkin)
            currentPumpkin = nil
        end
        
        if pumpkinBlip and DoesBlipExist(pumpkinBlip) then
            RemoveBlip(pumpkinBlip)
            pumpkinBlip = nil
        end
        
        DeleteZombies()
        
        StopHalloweenEffects()
        StopBackgroundMusic()
        
        AnimpostfxStop("DrugsMichaelAliensFight")
        StopScreenEffect("DeathFailMPIn")
        AnimpostfxStop("DeathFailNeutralIn")
        StopScreenEffect("ExplosionJosh3")
        
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        SetTimecycleModifierStrength(0.0)
        
        ClearWeatherTypePersist()
        ClearOverrideWeather()
        SetWeatherTypeNow('CLEAR')
        SetWeatherTypeNowPersist('CLEAR')
        
        if savedHour and savedMinute then
            NetworkOverrideClockTime(savedHour, savedMinute, 0)
        end
        
        if eventVehicle and DoesEntityExist(eventVehicle) then
            ESX.Game.DeleteVehicle(eventVehicle)
            eventVehicle = nil
        end
        
        RestoreOriginalClothing()
        
        ESX.ShowNotification('El líder canceló la misión')
        
        Citizen.Wait(500)
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
        SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
        
        pumpkinsCollected = 0
        usedLocations = {}
    end
end)

RegisterNetEvent('halloween:lobbyStartMission')
AddEventHandler('halloween:lobbyStartMission', function()
    StartMission()
end)

RegisterNetEvent('halloween:syncPumpkinSpawn')
AddEventHandler('halloween:syncPumpkinSpawn', function(locationIndex, coords)
    CreatePumpkinAtLocation(locationIndex, coords)
end)


RegisterNetEvent('halloween:syncPumpkinCollect')
AddEventHandler('halloween:syncPumpkinCollect', function()
    if currentPumpkin and DoesEntityExist(currentPumpkin) then
        SetEntityAsMissionEntity(currentPumpkin, false, true)
        DeleteObject(currentPumpkin)
        DeleteEntity(currentPumpkin)
        currentPumpkin = nil
    end
    
    if pumpkinBlip and DoesBlipExist(pumpkinBlip) then
        RemoveBlip(pumpkinBlip)
        pumpkinBlip = nil
    end
    
    DeleteZombies()
    
    pumpkinsCollected = pumpkinsCollected + 1
    
    TriggerEvent('chat:addMessage', { 
        args = {"Halloween", "Calabaza recolectada " .. pumpkinsCollected .. "/" .. Config.Mission.pumpkinsToCollect} 
    })
    
    if pumpkinsCollected >= Config.Mission.pumpkinsToCollect then
        EndMission(true)
    else
        Citizen.Wait(500)
        SpawnPumpkin()
    end
end)

RegisterNetEvent('halloween:showNearbyLobbies')
AddEventHandler('halloween:showNearbyLobbies', function(lobbies)
    if #lobbies == 0 then
        ESX.ShowNotification('No hay lobbies cercanos disponibles')
        return
    end
    
    local lobbyOptions = {}
    
    for _, lobby in ipairs(lobbies) do
        table.insert(lobbyOptions, {
            title = 'Lobby de ' .. lobby.leaderName,
            description = lobby.playerCount .. '/' .. Config.Mission.maxPlayersInLobby .. ' jugadores',
            icon = 'fas fa-users',
            iconColor = '#3498db',
            onSelect = function()
                TriggerServerEvent('halloween:joinLobby', lobby.id)
                lib.hideContext()
            end
        })
    end
    
    lib.registerContext({
        id = 'nearby_lobbies',
        title = 'Lobbies Disponibles',
        menu = 'lobby_menu',
        options = lobbyOptions
    })
    
    lib.showContext('nearby_lobbies')
end)

AddEventHandler('esx:onPlayerDeath', function()
    if missionActive and Config.Mission.respawnOnDeath then
        if currentLobby and isLobbyLeader then
            TriggerServerEvent('halloween:transferLobbyLeadership', currentLobby)
        end
        
        Citizen.Wait(2000)
        
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
        SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
        
        TriggerEvent('esx_ambulancejob:revive')
        
        if not currentLobby then
            Citizen.Wait(1000)
            EndMission(false, true)
        else
            ESX.ShowNotification('Moriste. Continúa ayudando a tu equipo!')
        end
    end
end)

AddEventHandler('baseevents:onPlayerDied', function()
    if missionActive and Config.Mission.respawnOnDeath then
        if currentLobby and isLobbyLeader then
            TriggerServerEvent('halloween:transferLobbyLeadership', currentLobby)
        end
        
        Citizen.Wait(2000)
        
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
        SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
        
        TriggerEvent('esx_ambulancejob:revive')
        
        if not currentLobby then
            Citizen.Wait(1000)
            EndMission(false, true)
        else
            ESX.ShowNotification('Moriste. Continúa ayudando a tu equipo!')
        end
    end
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    if missionActive and Config.Mission.respawnOnDeath then
        if currentLobby and isLobbyLeader then
            TriggerServerEvent('halloween:transferLobbyLeadership', currentLobby)
        end
        
        Citizen.Wait(2000)
        
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, Config.Mission.respawnCoords.x, Config.Mission.respawnCoords.y, Config.Mission.respawnCoords.z)
        SetEntityHeading(playerPed, Config.Mission.respawnCoords.w)
        
        TriggerEvent('esx_ambulancejob:revive')
        
        if not currentLobby then
            Citizen.Wait(1000)
            EndMission(false, true)
        else
            ESX.ShowNotification('Moriste. Continúa ayudando a tu equipo!')
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if npcPed then
        DeleteEntity(npcPed)
    end
    
    if currentPumpkin and DoesEntityExist(currentPumpkin) then
        SetEntityAsMissionEntity(currentPumpkin, false, true)
        DeleteObject(currentPumpkin)
        DeleteEntity(currentPumpkin)
    end
    
    if pumpkinBlip and DoesBlipExist(pumpkinBlip) then
        RemoveBlip(pumpkinBlip)
    end
    
    if eventVehicle and DoesEntityExist(eventVehicle) then
        ESX.Game.DeleteVehicle(eventVehicle)
        DeleteEntity(eventVehicle)
    end
    
    DeleteZombies()
    RestoreOriginalClothing()
    CleanupHalloweenEffects()
    StopBackgroundMusic()
    
    AnimpostfxStop("DrugsMichaelAliensFight")
    StopScreenEffect("DeathFailMPIn")
    AnimpostfxStop("DeathFailNeutralIn")
    StopScreenEffect("ExplosionJosh3")
    
    if currentLobby then
        TriggerServerEvent('halloween:leaveLobby', currentLobby)
    end
end)
