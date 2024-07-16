local NitroVeh = {}
local Framework = GetFramework()
Citizen.Await(Framework)

local Callback = (Config.Framework == "ESX" or Config.Framework == "NewESX") and Framework.RegisterServerCallback or Framework.Functions.CreateCallback

local function saveNitroData()
    SaveResourceFile(GetCurrentResourceName(), "nitro_data.json", json.encode(NitroVeh), -1)
end

Callback('Owner', function(source, cb, plate)
    local Player = Framework.Functions.GetPlayer(source)
    local citizen = Player and Player.PlayerData.citizenid
    local result = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizen})
    cb(result ~= nil)
end)

local function loadNitroData()
    local nitroData = LoadResourceFile(GetCurrentResourceName(), "nitro_data.json")
    if nitroData then
        NitroVeh = json.decode(nitroData)
    end
end

local function sendNitroDataToClients()
    TriggerClientEvent('UpdateData', -1, NitroVeh)
end

loadNitroData()

Citizen.CreateThread(function()
    Citizen.Wait(3500)
    while not Framework do Citizen.Wait(72) end
    local UsableItem = (Config.Framework == "ESX" or Config.Framework == "NewESX") and Framework.RegisterUsableItem or Framework.Functions.CreateUseableItem
    UsableItem('nitrous', function(source)
        TriggerClientEvent('SetupNitro', source)
    end)
end)

RegisterServerEvent('RemoveNitroItem')
AddEventHandler('RemoveNitroItem', function(Plate)
    local Player = Framework.Functions.GetPlayer(source)
    if Config.Framework == "ESX" or Config.Framework == "NewESX" then
        Player.removeInventoryItem(Config.NitroItem, 1)
    else
        Player.Functions.RemoveItem(Config.NitroItem, 1)
    end
    if Plate then
        NitroVeh[Plate] = 100
        saveNitroData()
        sendNitroDataToClients()
    end
end)

RegisterServerEvent('UpdateNitro')
AddEventHandler('UpdateNitro', function(Plate, amount)
    if Plate and NitroVeh[Plate] then
        NitroVeh[Plate] = math.max(0, NitroVeh[Plate] - amount)
        saveNitroData()
        sendNitroDataToClients()
    end
end)

RegisterNetEvent('RequestNitroData')
AddEventHandler('RequestNitroData', function()
    TriggerClientEvent('UpdateData', source, NitroVeh)
end)

AddEventHandler('playerConnecting', function()
    sendNitroDataToClients()
end)
