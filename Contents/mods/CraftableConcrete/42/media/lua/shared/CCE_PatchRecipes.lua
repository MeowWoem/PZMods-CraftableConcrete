local recipesToPatch = {
    Base = {
        CraftConcretePowder = {
            ["Base.Sandbag"] = 2,
            ["Base.Gravelbag"] = 3,
        },
    },
};

local CraftableConcreteMod = {};
CraftableConcreteMod.useDeltas = {};

local buildItemLines = function(patch)
    local itemLines = "";
    for itemType, qty in pairs(patch) do
        local count = math.floor(((qty) / CraftableConcreteMod.useDeltas[itemType]) + 0.5);
        itemLines = itemLines .. string.format("item %d [%s],\n", count, itemType);
    end
    return itemLines;
end

local patchRecipeVariant = function(recipeName, patch, namespace)
    local fullName = recipeName;
    local recipe = ScriptManager.instance:getCraftRecipe(namespace .. "." .. fullName);

    if not recipe then return; end

    recipe:getInputs():clear();

    local itemLines = buildItemLines(patch);
    local staticLines = "item 1 [Base.Bucket;Base.BucketForged;Base.BucketEmpty;Base.BucketCarved] mode:keep,\n"
        .. "item 1 [Base.Quicklime] mode:destroy,";

    local patchString = string.format([[{
        inputs {
            %s%s
        }
    }]], staticLines, itemLines);

    recipe:Load(fullName, patchString);
end

CraftableConcreteMod.patchRecipe = function(recipeName, patch, namespace)
    namespace = namespace or "Base";
    patchRecipeVariant(recipeName, patch, namespace);

end

CraftableConcreteMod.onGameBoot = function()
    print("CraftableConcreteMod : Patch concrete recipe");
    local itemSandbag = ScriptManager.instance:getItem("Base.Sandbag");
    local itemGravelbag = ScriptManager.instance:getItem("Base.Gravelbag");
    if not itemSandbag or not itemGravelbag then return; end
    CraftableConcreteMod.useDeltas["Base.Sandbag"] = itemSandbag:getUseDelta();
    CraftableConcreteMod.useDeltas["Base.Gravelbag"] = itemGravelbag:getUseDelta();

    for namespace, patches in pairs(recipesToPatch) do
        for recipeName, patch in pairs(patches) do
            CraftableConcreteMod.patchRecipe(recipeName, patch, namespace);
        end
    end
    
end

Events.OnGameBoot.Add(CraftableConcreteMod.onGameBoot);