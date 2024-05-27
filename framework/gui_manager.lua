--
-- Manage GUIs and GUI state
--

local Events = require('__stdlib__.stdlib.event.event')
local Is = require('__stdlib__.stdlib.utils.is')

local FrameworkGui = require('framework.gui')

------------------------------------------------------------------------

--- @class FrameworkGuiManager
--- @field prefix string The prefix for all registered handlers and other global information.
--- @field guis table<number, FrameworkGui> All registered and known guis for this manager.
local FrameworkGuiManager = {
    prefix = '__unset_please_fix__',
}

------------------------------------------------------------------------

--- Creates a new id for the guis.
--- @return number A unique gui id.
local function create_id()
    local count = FrameworkGuiManager.state.count
    FrameworkGuiManager.state.count = FrameworkGuiManager.state.count + 1
    return count
end

------------------------------------------------------------------------

--- Dispatch an event to a registered gui.
--- @param ev FrameworkGuiEventData
--- @return boolean handled True if an event handler was called, False otherwise.
local function dispatch(ev)
    if not ev then return false end

    local elem = ev.element
    if not Is.Valid(elem) then return false end

    -- see if this has the right tags
    local tags = elem.tags --[[@as Tags]]
    local gui_id = tags[FrameworkGuiManager.prefix .. 'id']
    if not (gui_id and FrameworkGuiManager.state.guis[gui_id]) then return false end

    -- dispatch to the UI instance
    return FrameworkGuiManager.state.guis[gui_id]:dispatch(ev)
end

------------------------------------------------------------------------

--- Finds a gui.
--- @param gui_id number?
--- @return FrameworkGui? framework_gui
function FrameworkGuiManager.find_gui(gui_id)
    if not gui_id then return nil end
    return FrameworkGuiManager.state.guis[gui_id]
end

------------------------------------------------------------------------

--- Creates a new GUI instance.
--- @param parent LuaGuiElement
--- @param children FrameworkGuiElemDef|FrameworkGuiElemDef[] The element definition, or an array of element definitions.
--- @param existing_elements table<string, LuaGuiElement>? Optional set of existing GUI elements.
--- @return FrameworkGui framework_gui A framework gui instance
function FrameworkGuiManager.create_gui(parent, children, existing_elements)
    local gui_id = create_id()
    local gui = FrameworkGui.create(gui_id, FrameworkGuiManager.prefix)
    FrameworkGuiManager.state.guis[gui_id] = gui

    gui:add_child_elements(parent, children, existing_elements)

    return gui
end

------------------------------------------------------------------------

--- Destroys a GUI instance.
--- @param gui (FrameworkGui|number)? The gui to destroy
function FrameworkGuiManager.destroy_gui(gui)
    if not gui then return end
    if Is.Number(gui) then
        gui = FrameworkGuiManager.find_gui(gui --[[@as number?]]) --[[@as FrameworkGui?]]
        if not gui then return end
    end
    local gui_id = gui.id
    FrameworkGuiManager.state.guis[gui_id] = nil
    gui.root.destroy()
end

------------------------------------------------------------------------

FrameworkGuiManager.prefix = Mod.PREFIX .. 'gui-'

local storage = Mod.runtime:storage()
if not storage.gui_manager then
    storage.gui_manager = {
        count = 1,
        guis = {},
    }
end

FrameworkGuiManager.state = storage.gui_manager

-- register all gui events with the framework
for name, id in pairs(defines.events) do
    if name:sub(1, 7) == 'on_gui_' then
        Events.on_event(id, function(ev)
            dispatch(ev)
        end)
    end
end

------------------------------------------------------------------------

return FrameworkGuiManager
