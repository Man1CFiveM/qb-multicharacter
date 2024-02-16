-- Encapsulation: 
-- Classes and methods allow you to bundle related data and functionality together. 
-- This makes your code easier to understand and maintain, 
-- as it's clear which functions are intended to operate on which data.

-- Inheritance: 
-- Metatables allow you to implement inheritance, 
-- where one class can inherit the properties and methods of another. 
-- This can reduce code duplication and make your code more flexible.

-- Operator Overloading: 
-- Metatables also allow you to define custom behavior for standard Lua operators
-- when they're used with your objects. This can make your code more intuitive and easier to read.

-- Control Over Global Variables: Global variables can be accessed and modified from anywhere in your code, 
-- which can lead to bugs that are difficult to track down. By using classes and methods, 
-- you can control access to your data and prevent it from being accidentally modified.

-- Polymorphism: 
-- With the use of metatables and classes, you can create methods that behave differently 
-- depending on the type of the object it's being used with. 
-- This allows you to write more flexible and reusable code.

-- Data Hiding: 
-- Classes and methods can be used to implement private properties and methods, 
-- which can prevent external code from directly accessing and modifying the internal state of your objects.

local QBCore = exports['qb-core']:GetCoreObject()
local character
-- Define the Character class
CharacterClass = {}
CharacterClass.__index = function(self, key)
    -- Look for the method in the CharacterClass table
    local method = rawget(CharacterClass, key)
    -- If the method exists, wrap it in a pcall to catch any errors
    if method then
        -- Return a new function that calls the method with pcall
        return function(...)
            -- Call the method with pcall
            local status, result = pcall(method, ...)
            -- If the call was successful, return the result
            if not status then
                -- If the call failed, print the error message
                print("^2: "..key..' - ^5'..result) -- print the error message
            end
            return result
        end
    end
end

-- This is the constructor for the CharacterClass. It initializes a new instance of the class with default values for its properties.
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
--- func desc
---@param model any -- model to load
function CharacterClass:loadModel(model) -- should be using the core loadmodel function
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

--render a preview of the players ped, if not model is provided, a random model will be loaded
---@param model any -- model to load
---@param data any -- appearance data
function CharacterClass:initializePedModel(model, data)
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
end

-- Function to control the sky camera
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

-- Function to open the character selection menu
function CharacterClass:openCharMenu(bool)
    -- Wrap the body of the function in a pcall
    -- CREATE ERROR
    -- undefinedFunction() -- Call an undefined function to trigger an error 
    if bool then
        SetNuiFocus(false, false)
        DoScreenFadeOut(10)
        Wait(1000)
        local interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z - 18.9)
        -- LoadInterior(interior) -- old name
        PinInteriorInMemory(interior)
        while not IsInteriorReady(interior) do
            Wait(100)
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
end

-- Function to select a character slot
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

-- Function to select a character
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

-- Function to setup the character selection menu
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
    -- CREATE ERROR
    -- local a = nil
    -- print(a.someField) -- This will cause an error because 'a' is nil
end

-- Function to create a new character
function CharacterClass:createNewCharacter(payload, cb)
    -- CREATE ERROR
    -- error("Error in errorMethod1!")
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

-- Function to spawn the player at the last location
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

-- Function to remove a character
function CharacterClass:removeCharacter(payload, cb)
    TriggerServerEvent('qb-multicharacter:server:deleteCharacter', payload.citizenid)
    DeletePed(self.charPed)
    TriggerEvent('qb-multicharacter:client:chooseChar')
    cb("ok")
end

-- Function to close the character selection menu
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
			-- character:errorMethod1() -- This will print "Error in errorMethod1!" to the console
            -- character:errorMethod2() -- This will print "attempt to index a nil value" to the console
			return
		end
	end
end)

-- Events, we could create 1 singl event for qb-multicharacter, and then use the payload to determine what to do
RegisterNetEvent('qb-multicharacter:client:closeNUI', function(toggle)
    character:closeNUI(toggle)
end)

RegisterNetEvent('qb-multicharacter:client:spawnLastLocation', function(coords, cData)
    character:spawnLastLocation(coords, cData)
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function() -- need to rework this properly
    character:openCharMenu(false)
end)