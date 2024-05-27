--------------------------------------------------------------------------------
--
-- Framework test module
--
--------------------------------------------------------------------------------

local FrameworkSupport = {}

FrameworkSupport.settings = function()
    Mod.logger:log('Settings stage for additional modules called!')
end

FrameworkSupport.data = function()
    Mod.logger:log('Data stage for additional modules called!')
end

FrameworkSupport.data_updates = function()
    Mod.logger:log('Data Updates stage for additional modules called!')
end

FrameworkSupport.data_final_fixes = function()
    Mod.logger:log('Data Final Fixes stage for additional modules called!')
end

FrameworkSupport.runtime = function()
    Mod.logger:log('Runtime stage for additional modules called!')
end

return FrameworkSupport
