-- Metatables: 
-- In Lua, metatables are used to define behavior that is not directly supported by tables. 
-- This includes operations like addition and subtraction on tables, comparison between tables, 
-- and defining what happens when a table is accessed with a key that it does not contain. 
-- In the context of your code, metatables are used to implement object-oriented programming. 
-- The setmetatable function is used to set the metatable for the new object, 
-- which allows you to use the : operator to call methods on the object.

-- Classes: Classes are a fundamental concept in object-oriented programming. 
-- They allow you to define objects that contain both data (fields) and operations on that data (methods). 
-- This can make your code more organized and easier to understand, as related data and operations are grouped together. 
-- In your code, the CharacterClass is used to define a type of object that represents a character, 
-- with methods for loading models, initializing the character model, and controlling the sky camera.

-- File-scoped variables: File-scoped variables are variables that are declared outside of any function 
-- and are accessible from anywhere within the same file. They are used to store data that needs to be shared 
-- between multiple functions in the file. In your code, the character variable is file-scoped, 
-- which allows it to be accessed from any function in the file. 
--     This is useful because many different functions need to operate on the current character.

-- Using these concepts can make your code more organized, more reusable, and easier to understand and maintain. 
-- However, they also add a level of complexity, 
-- so it's important to use them judiciously and only when they provide a clear benefit.

local QBCore = exports['qb-core']:GetCoreObject()
local character
-- Define the Character class
CharacterClass = {}
CharacterClass.__index = CharacterClass

-- Constructor
function CharacterClass.new()
    local self = setmetatable({}, CharacterClass)
    self.randomModels = { -- models possible to load when choosing empty slot
        'mp_m_freemode_01',
        'mp_f_freemode_01',
    }
    self.charPed = nil
    self.cam = nil
    self.loadScreenCheckState = false
    self.cached_player_skins = {}
    return self
end

function CharacterClass:loadModel(model) -- should be using the core loadmodel function
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

function CharacterClass:initializePedModel(model, data)
    CreateThread(function()
        if not model then -- all thise should be a core function to load a model
            model = joaat(self.randomModels[math.random(#self.randomModels)])
        end
        character:loadModel(model)
        self.charPed = CreatePed(2, model, Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 0.98, Config.PedCoords.w, false, true)
        SetPedComponentVariation(self.charPed, 0, 0, 0, 2)
        FreezeEntityPosition(self.charPed, false)
        SetEntityInvincible(self.charPed, true)
        PlaceObjectOnGroundProperly(self.charPed)
        SetBlockingOfNonTemporaryEvents(self.charPed, true)
        if data then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', data, self.charPed)
        end
    end)
end

function CharacterClass:skyCam(bool)
    TriggerEvent('qb-weathersync:client:DisableSync')
    if not bool then
        SetTimecycleModifier('default')
        SetCamActive(self.cam, false)
        DestroyCam(self.cam, true)
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
    end
    DoScreenFadeIn(1000)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(1.0)
    FreezeEntityPosition(PlayerPedId(), false)
    self.cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", Config.CamCoords.x, Config.CamCoords.y, Config.CamCoords.z, 0.0 ,0.0, Config.CamCoords.w, 60.00, false, 0)
    SetCamActive(self.cam , true)
    RenderScriptCams(true, false, 1, true, true)
end

function CharacterClass:openCharMenu(bool)
    -- Wrap the body of the function in a pcall
    local status, error = pcall(function()
        if bool then
            SetNuiFocus(false, false)
            DoScreenFadeOut(10)
            Wait(1000)
            local interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z - 18.9)
            LoadInterior(interior)
            while not IsInteriorReady(interior) do
                Wait(1000)
            end
            FreezeEntityPosition(PlayerPedId(), true)
            SetEntityCoords(PlayerPedId(), Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z, true, false, false, false)
            Wait(1500)
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
        end
        QBCore.Functions.TriggerCallback("qb-multicharacter:server:GetNumberOfCharacters", function(result)
            local translations = {}
            for k in pairs(Lang.fallback and Lang.fallback.phrases or Lang.phrases) do
                if k:sub(0, ('ui.'):len()) then
                    translations[k:sub(('ui.'):len() + 1)] = Lang:t(k)
                end
            end
            SetNuiFocus(bool, bool)
            SendNUIMessage({
                action = "ui",
                customNationality = Config.customNationality,
                toggle = bool,
                nChar = result,
                enableDeleteButton = Config.EnableDeleteButton,
                translations = translations
            })
            character:skyCam(bool)
            if not self.loadScreenCheckState then
                ShutdownLoadingScreenNui()
                self.loadScreenCheckState = true
            end
        end)
    end)

    -- If the pcall returned false, an error occurred
    if not status then return print(status, error) end
    -- Call your error handling function with the error message
    -- QBCore.Functions.handle_error(error) core error handling
end

function CharacterClass:selectSlot(payload, cb)
    if self.charPed then -- delete the ped if it exist
        SetEntityAsMissionEntity(self.charPed, true, true)
        DeleteEntity(self.charPed)
    end
    if not payload.cData then
        character:initializePedModel()
        return cb("ok")
    end
    local cData = payload.cData
    if self.cached_player_skins[cData.citizenid] == nil then
        local temp_model = promise.new()
        local temp_data = promise.new()

        QBCore.Functions.TriggerCallback('qb-multicharacter:server:getSkin', function(model, data)
            if model == nil then print('qb-multicharacter:server:getSkin: model is nil') end
            if data == nil then print('qb-multicharacter:server:getSkin: data is nil') end
            temp_model:resolve(model)
            temp_data:resolve(data)
        end, cData.citizenid)

        local resolved_model = Citizen.Await(temp_model)
        local resolved_data = Citizen.Await(temp_data)

        self.cached_player_skins[cData.citizenid] = {model = resolved_model, data = resolved_data}
    end

    local model = self.cached_player_skins[cData.citizenid].model
    local data = self.cached_player_skins[cData.citizenid].data

    model = model ~= nil and tonumber(model) or false

    if not model then character:initializePedModel() end
    character:initializePedModel(model, json.decode(data))
    cb("ok")
end

function CharacterClass:selectCharacter(payload, cb)
    DoScreenFadeOut(10)
    TriggerServerEvent('qb-multicharacter:server:loadUserData', payload.cData)
    character:openCharMenu(false)
    SetEntityAsMissionEntity(self.charPed, true, true)
    DeleteEntity(self.charPed)
    cb("ok")
    Wait(2000) -- TODO need to resolve this
    SetTimecycleModifier('default')
end

function CharacterClass:setupCharacters(cb)
    QBCore.Functions.TriggerCallback("qb-multicharacter:server:setupCharacters", function(result)
        -- self.cached_player_skins = {} not needed
            SendNUIMessage({
                action = "setupCharacters",
                characters = result
            })
        cb("ok")
    end)
    SetTimecycleModifier('default')
end

function CharacterClass:createNewCharacter(payload, cb)
    DoScreenFadeOut(150)
    if payload.gender == Lang:t("ui.male") then
        payload.gender = 0
    elseif payload.gender == Lang:t("ui.female") then
        payload.gender = 1
    end
    TriggerServerEvent('qb-multicharacter:server:createCharacter', payload)
    Wait(500)
    cb("ok")
end

function CharacterClass:spawnLastLocation(coords, payload)
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent("apartments:client:SetHomeBlip", result.type)
            local ped = PlayerPedId()
            SetEntityCoords(ped, coords.x, coords.y, coords.z, true, false, false, false)
            SetEntityHeading(ped, coords.w)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, 0) --unk: Always 0 in scripts
            local PlayerData = QBCore.Functions.GetPlayerData()
            local insideMeta = PlayerData.metadata["inside"]
            DoScreenFadeOut(500)

            if insideMeta.house then
                TriggerEvent('qb-houses:client:LastLocationHouse', insideMeta.house)
            elseif insideMeta.apartment.apartmentType and insideMeta.apartment.apartmentId then
                TriggerEvent('qb-apartments:client:LastLocationHouse', insideMeta.apartment.apartmentType, insideMeta.apartment.apartmentId)
            -- else --BUG why was this here, we set the player already in the top
            --     SetEntityCoords(ped, coords.x, coords.y, coords.z, true, false, false, false)
            --     SetEntityHeading(ped, coords.w)
            --     FreezeEntityPosition(ped, false)
            --     SetEntityVisible(ped, true, 0) --unk: Always 0 in scripts
            end

            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            Wait(2000)
            DoScreenFadeIn(250)
        end
    end, payload.citizenid)
end

function CharacterClass:removeCharacter(payload, cb)
    TriggerServerEvent('qb-multicharacter:server:deleteCharacter', payload.citizenid)
    DeletePed(self.charPed)
    TriggerEvent('qb-multicharacter:client:chooseChar')
    cb("ok")
end

function CharacterClass:closeNUI(apartment)
    if not apartment then
        DeleteEntity(self.charPed)
        SetNuiFocus(false, false)
        DoScreenFadeOut(500)
        Wait(2000)
        SetEntityCoords(PlayerPedId(), Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z, true, false, false, false)
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
        Wait(500)
        character:openCharMenu()
        SetEntityVisible(PlayerPedId(), true, 0) --unk: Always 0 in scripts
        Wait(500)
        DoScreenFadeIn(250)
        TriggerEvent('qb-weathersync:client:EnableSync')
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
        return
    end
    DeleteEntity(self.charPed)
    SetNuiFocus(false, false)
end

-- NUI Callbacks
RegisterNUICallback('characterAction', function(data, cb)
    if data.option == 'selectSlot' then
        return character:selectSlot(data, cb)
    end
    if data.option == 'selectCharacter' then
        return character:selectCharacter(data, cb)
    end
    if data.option == 'setupCharacters' then
        return character:setupCharacters(cb)
    end
    if data.option == 'createNewCharacter' then
        return character:createNewCharacter(data, cb)
    end
    if data.option == 'removeCharacter' then
        return character:removeCharacter(data, cb)
    end
end)

-- Main Thread
CreateThread(function()
	while true do
		Wait(0)
		if NetworkIsSessionStarted() then
            character = CharacterClass.new() -- create a new instance of the Character class
            character:openCharMenu(true)
			-- TriggerEvent('qb-multicharacter:client:chooseChar')
			return
		end
	end
end)

-- Events
RegisterNetEvent('qb-multicharacter:client:closeNUI', function(toggle)
    character:closeNUI(toggle)
end)

RegisterNetEvent('qb-multicharacter:client:spawnLastLocation', function(coords, cData)
    print('qb-multicharacter:client:spawnLastLocation')
    character:spawnLastLocation(coords, cData)
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function() -- need to rework this properly
    character:openCharMenu(false)
end)