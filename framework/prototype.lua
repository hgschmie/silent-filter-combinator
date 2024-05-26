---------------------------------------------------------------------------------------------------
-- a portable framework needs to know the root location of the mod
---------------------------------------------------------------------------------------------------

local FrameworkPrototype = {}

---@param mod_root string The module root
function FrameworkPrototype.init(mod_root)
    require('framework.prototypes.sprite').init(mod_root)
    require('framework.prototypes.style').init(mod_root)
    require('framework.prototypes.technology-slot-style').init(mod_root)
end

return FrameworkPrototype