-- this is the main benefit of using metatables, you can define the derived class without having to redefine the methods, properties or create a new function
-- Create an instance of Painkiller
Drug = {}
Drug.__index = Drug

function Drug:new(name, amount, last, effect, sideEffects)
    local obj = {}
    setmetatable(obj, Drug)
    obj.name = name
    obj.amount = amount
    obj.last = last
    obj.effect = effect
    obj.sideEffects = sideEffects
    return obj
end

function Drug:consume()
    return "Consuming " .. self.amount .. " of " .. self.name .. ". Lasts for " .. self.last .. " hours and has an effect of " .. self.effect .. ". Side effects: " .. self.sideEffects
end

-- Define the derived class Painkiller
Painkiller = setmetatable({}, Drug)
Painkiller.__index = Painkiller

Painkiller = setmetatable({}, Drug)
Painkiller.__index = Painkiller

-- Define the derived class Painkiller then add 2 new properties
function Painkiller:new(name, amount, last, effect, sideEffects, dosage, frequency)
    local obj = Drug:new(name, amount, last, effect, sideEffects)  -- Call the base class constructor
    setmetatable(obj, Painkiller)
    obj.dosage = dosage
    obj.frequency = frequency
    return obj
end

Stimulant = setmetatable({}, Drug)
Stimulant.__index = Stimulant

Depressant = setmetatable({}, Drug)
Depressant.__index = Depressant

function Painkiller:consume()
    return "Consuming " .. self.amount .. " of " .. self.name .. ". Lasts for " .. self.last .. " hours and has an effect of " .. self.effect .. ". Side effects: " .. self.sideEffects .. ". Recommended dosage: " .. self.dosage .. ". Frequency: " .. self.frequency
end

-- Create an instance of Painkiller
local myPainkiller = Painkiller:new("Morphine", 10, 5, "Pain relief", "Drowsiness, nausea", 2, "Every 4 hours")
print(myPainkiller:consume())  -- Outputs: "Consuming 10 of Morphine. Lasts for 5 hours and has an effect of Pain relief. Side effects: Drowsiness, nausea. Recommended dosage: 2. Frequency: Every 4 hours"


-- Create another instance of Stimulant
local myStimulant2 = Stimulant:new("myStimulant2",15, 3, "Increased focus", "Insomnia, anxiety")
print(myStimulant2:consume())  -- Outputs: "Consuming 15 of stimulant. Lasts for 3 and has an effect of Increased focus"

-- Create another instance of Depressant
local myDepressant2 = Depressant:new("myDepressant2", 25, 8, "Sleep aid", "Drowsiness, fatigue")
print(myDepressant2:consume())  -- Outputs: "Consuming 25 of depressant. Lasts for 8 and has an effect of Sleep aid"