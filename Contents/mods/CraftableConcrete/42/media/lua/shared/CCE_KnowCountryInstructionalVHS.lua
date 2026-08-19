local MOD_DATA_KEY = "MD_RM_CCE_VHS_1";
local BOREDOM_PER_LINE = -5;

local Tapes = {
    {
        id = "RM_CCE_6-0c97-47b9-811b-b4ff4157618e",
        name = "RM_CCE_VHS_NAME",
        perk = { id = "Masonry", xp = 75 },
        volume = 1,
        recipesToLearn = {
            "CraftConcretePowder",
        },
        recipeLearnedText = "RM_CCE_RECIPE_LEARNED",
        requiredLines = {
            49,
            { 51, 58 },
        },
        lines = (function()
            local generated = {};
            for i = 1, 74 do
                generated[i] = "RM_CCE_VHS_LINE" .. i;
            end
            return generated;
        end)(),
    },
};

local TapeById = {};
for _, tape in ipairs(Tapes) do
    TapeById[tape.id] = tape;
end

local function buildRequiredLineSet(spec)
    local set = {};
    if not spec then
        return set;
    end
    for _, entry in ipairs(spec) do
        if type(entry) == "table" then
            for i = entry[1], entry[2] do
                set[i] = true;
            end
        else
            set[entry] = true;
        end
    end
    return set;
end

for _, tape in ipairs(Tapes) do
    tape.requiredSet = buildRequiredLineSet(tape.requiredLines);
end

local function registerTapes(recordedMedia)
    for _, tape in ipairs(Tapes) do
        local data = recordedMedia:register("Retail-VHS", tape.id, tape.name, 2);
        data:setTitle(tape.name);
        data:setSubtitle("RM_CCE_SUBTITLE");
        data:setAuthor("RM_CCE_AUTHOR");
        data:setExtra("RM_CCE_EXTRA_V" .. tostring(tape.volume));

        for lineNumber, lineKey in ipairs(tape.lines) do
            local codes = "RMB-1";

            if tape.requiredSet[lineNumber] then
                codes = codes .. ",RMR=" .. tape.id .. ":" .. tostring(lineNumber);
            end

            if lineNumber == #tape.lines and tape.perk then
                codes = codes .. ",RMP=" .. tape.id;
            end

            local r, g, b = 0.00, 0.69, 0.94;
            if tape.volume == 2 then
                r, g, b = 1.00, 0.75, 0.00;
            end
            data:addLine(lineKey, r, g, b, codes);
        end
    end
end

local function playerCanHear(player, x, y, z)
    if not player or player:isDead() or player:isAsleep() then
        return false;
    end
    if x == -1 and y == -1 and z == -1 then
        return true;
    end
    if math.floor(player:getZ()) ~= math.floor(z) then
        return false;
    end
    if player:getX() < x - 5 or player:getX() > x + 5 or player:getY() < y - 5 or player:getY() > y + 5 then
        return false;
    end

    local source = getCell():getGridSquare(x, y, z);
    local playerSquare = player:getSquare();
    if source and playerSquare and source:isOutside() ~= playerSquare:isOutside() then
        return false;
    end
    return true;
end

local function applyTapeLine(player, codes)
    local modData = player:getModData()[MOD_DATA_KEY];
    if type(modData) ~= "table" then
        modData = { perksWatched = {}, recipeProgress = {} };
        player:getModData()[MOD_DATA_KEY] = modData;
    end

    local changed = false;

    if string.find(codes, "RMB-1", 1, true) then
        local stats = player:getStats();
        if stats then
            stats:add(CharacterStat.BOREDOM, BOREDOM_PER_LINE);
        end
    end

    local rmpTapeId = string.match(codes, "RMP=([%w_%-]+)");
    if rmpTapeId then
        local tape = TapeById[rmpTapeId];
        if tape and tape.perk then
            local watchedKey = tape.perk.id .. ":V" .. tostring(tape.volume);
            if not modData.perksWatched[watchedKey] then
                modData.perksWatched[watchedKey] = true;
                changed = true;

                local perk = Perks.FromString(tape.perk.id);
                if perk and perk ~= Perks.None then
                    player:getXp():AddXP(perk, tape.perk.xp);
                end
            end
        end
    end

    local milestoneTapeId, milestoneLine = string.match(codes, "RMR=([%w_%-]+):(%d+)");
    if milestoneTapeId then
        local tape = TapeById[milestoneTapeId];
        if tape and tape.recipesToLearn and #tape.recipesToLearn > 0 then
            local progress = modData.recipeProgress[milestoneTapeId];
            if type(progress) ~= "table" then
                progress = { seen = {}, learned = false };
                modData.recipeProgress[milestoneTapeId] = progress;
            end

            if not progress.learned then
                local lineIndex = tonumber(milestoneLine);
                if not progress.seen[lineIndex] then
                    progress.seen[lineIndex] = true;
                    changed = true;
                end

                local allRequiredLinesSeen = true;
                for requiredIndex in pairs(tape.requiredSet) do
                    if not progress.seen[requiredIndex] then
                        allRequiredLinesSeen = false;
                        break;
                    end
                end

                if allRequiredLinesSeen then
                    local knownRecipes = player:getKnownRecipes();
                    for _, recipeName in ipairs(tape.recipesToLearn) do
                        if not knownRecipes:contains(recipeName) then
                            knownRecipes:add(recipeName);
                        end
                    end
                    progress.learned = true;
                    changed = true;

                    if tape.recipeLearnedText then
                        HaloTextHelper.addTextWithArrow(player, getText(tape.recipeLearnedText), true, HaloTextHelper.getColorGreen());
                    end
                end
            end
        end
    end

    if changed and isServer() then
        player:transmitModData();
    end
end

local function onDeviceText(guid, codes, x, y, z, line)
    if isClient() or not codes then
        return;
    end
    if not string.find(codes, "RMB-1", 1, true)
        and not string.find(codes, "RMP=", 1, true)
        and not string.find(codes, "RMR=", 1, true) then
        return;
    end

    if isServer() then
        local players = getOnlinePlayers();
        for index = 0, players:size() - 1 do
            local player = players:get(index);
            if playerCanHear(player, x, y, z) then
                applyTapeLine(player, codes);
            end
        end
    else
        for playerNumber = 0, 3 do
            local player = getSpecificPlayer(playerNumber);
            if playerCanHear(player, x, y, z) then
                applyTapeLine(player, codes);
            end
        end
    end
end

if (isDebugEnabled()) then

CCE_DEBUG = CCE_DEBUG or {};

function CCE_DEBUG.addStarterTape(player, tapeId)
    player = player or getSpecificPlayer(0);
    local tape = tapeId and TapeById[tapeId] or Tapes[1];
    if not tape then
        return;
    end

    local recordedMedia = getZomboidRadio() and getZomboidRadio():getRecordedMedia();
    local mediaData = recordedMedia and recordedMedia:getMediaData(tape.id);
    if not mediaData then
        return;
    end

    local container = player:getInventory();
    local item = container:AddItem("Base.VHS_Retail");
    if not item then
        return;
    end
    item:setRecordedMediaData(mediaData);

    if isServer() then
        player:transmitModData();
    end
end

end

Events.OnInitRecordedMedia.Add(registerTapes);
Events.OnDeviceText.Add(onDeviceText);