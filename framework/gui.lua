--
-- ported from flib/gui-lite
--

------------------------------------------------------------------------
-- Represents a single, open gui
------------------------------------------------------------------------

local Is = require('__stdlib__.stdlib.utils.is')

local FrameworkGui = {}

------------------------------------------------------------------------
-- helper methods
------------------------------------------------------------------------

function FrameworkGui:generate_name()
   local count = self.count
   self.count = count + 1
   return tostring(count)
end


--- Adds the internal prefix to the given name unless it is already prefixed.
--- @param name string
--- @return string prefixed name
function FrameworkGui:generate_gui_name(name)
   if name.sub(1, #self.prefix) == self.prefix then
      return name
   else
      return self.prefix .. name
   end
end


--- Registers all defined handlers after a LuaGuiElement has been created.
---@param gui_element LuaGuiElement
---@param extras FrameworkGuiElementExtras
function FrameworkGui:register_handlers(gui_element, extras)
   local handlers = extras.handler --[[@as table<defines.events, GuiElemHandler>]]
   if not Is.Table(extras.handler) then
      handlers = { handlers }
   end

   local handler_name = gui_element.name

   for event, handler in pairs(handlers) do
      local event_table = self.event_handlers[event]
      assert(event_table, "Handler for event " .. tostring(event) .. " is not supported!")
      assert(not event_table[handler_name], "Already registered a handler for " .. handler_name)
      event_table[handler_name] = handler --[[@as GuiElemHandler]]
   end
end

------------------------------------------------------------------------

local extra_fields = {
   'children',      -- gui elements attached as children to this element
   'elem_mods',     -- set of attributes that should be set on the created LuaGuiElement
   'style_mods',    -- set of attributes that should be set on the LuaStyle field of the LuaGuiElement
   'handler',       -- event handlers for this element
   'drag_target',   -- drag target reference (must be another Gui element) when dragging an element
}

--- Creates a new LuaGuiElement from a Framework element definition. Any defined children will recursively created and attached.
--- @param parent LuaGuiElement The parent element that this child will be attached to.
--- @param child FrameworkGuiElemDef A gui element definition. May have additional children.
--- @return LuaGuiElement gui_element The new gui element
function FrameworkGui:create_child_element(parent, child)

   ---@type FrameworkGuiElementExtras
   local extras = {}

   for _, key in pairs(extra_fields) do
      extras[key] = child[key]
      child[key] = nil
   end

   child.name = self:generate_gui_name(child.name or self:generate_name())
   assert(not self.ui_elements[child.name], "A UI element named '" .. child.name .. "' was already defined!")

   local gui_element = parent.add(child --[[@as table]]) -- [[@as LuaGuiElement ]]

   -- register with the FrameworkGui object
   self.ui_elements[child.name] = gui_element

   -- add tag for event dispatching
   local tags = gui_element.tags --[[@as Tags]]
   tags[self.prefix .. 'id'] = self.id
   gui_element.tags = tags

   -- process additional attributes

   if extras.style_mods then
      for key, value in pairs(extras.style_mods) do
         gui_element.style[key] = value
      end
   end

   if extras.elem_mods then
      for key, value in pairs(extras.elem_mods) do
         gui_element[key] = value
      end
   end

   if extras.drag_target then
      local drag_name = self:generate_gui_name(extras.drag_target)
      local target = self.ui_elements[drag_name]
      assert(target, "Drag target '" .. extras.drag_target .. "' not found.")

      gui_element.drag_target = target
   end

   if extras.handler then
      self:register_handlers(gui_element, extras)
   end

   if extras.children then
      self:add_child_elements(gui_element, extras.children)
   end

   return gui_element
end

--- Adds a child in a new tab to an existing tab group.
--- @param parent LuaGuiElement
--- @param child FrameworkGuiElemDef The elements that are added to the tab.
--- @return LuaGuiElement gui_element The content of the tab.
function FrameworkGui:add_tab(parent, child)
   local tab = self:create_child_element(parent, child.tab)
   local gui_element = self:create_child_element(parent, child.content)
   parent.add_tab(tab, gui_element)

   return gui_element
end

------------------------------------------------------------------------

--- Add a new child or children to the given GUI element.
--- @param parent LuaGuiElement
--- @param children FrameworkGuiElemDef|FrameworkGuiElemDef[] The element definition, or an array of element definitions.
--- @param existing_elements table<string, LuaGuiElement>? Optional set of existing GUI elements.
function FrameworkGui:add_child_elements(parent, children, existing_elements)
   assert(Is.Valid(parent), "Parent element is missing or invalid")
   assert(children, "new_elements can not be empty")

   if existing_elements then
      -- validate and move existing elements into the internal ui_elements array
      for _, element in existing_elements do
         assert(Is.Valid(element))
         assert(element.name, "Can not add an external element without name: " .. serpent.line(element))
         local gui_name = self:generate_gui_name(element.name)

         assert(not self.ui_elements[gui_name], "A UI element named '" .. gui_name .. "' was already defined!")
         self.ui_elements[gui_name] = element
      end
   end

   -- If a single def was passed, wrap it in an array
   children = #children > 0 and children or { children } --[[@as table<string, FrameworkGuiElemDef>]]

   local root
   for i = 1, #children do
      local child = children[i]
      assert(not child[1], 'children as arrays are not supported, use the children attribute!')

      local gui_element
      if child.type then
         gui_element = self:create_child_element(parent, child)
      elseif child.tab and child.content then
         gui_element = self:add_tab(parent, child)
      else
         assert(false, "Invalid element: " .. serpent(child))
      end
      root = root or gui_element
   end

   self.root = root
end

------------------------------------------------------------------------

--- Creates a new FrameworkGui instance and registers it with the manager.
--- @param gui_id number The manager assigned id for this gui.
--- @param prefix string The internal prefix for all elements in this gui
--- @return FrameworkGui gui A FrameworkGui instance that can be used for creating a Gui.
function FrameworkGui.create(gui_id, prefix)

   --- @class FrameworkGui
   --- @field id number The gui id for this instance
   --- @field prefix string The internal prefix for all names.
   --- @field count number A running count for autogenerated names.
   --- @field ui_elements table<string, LuaGuiElement> All known elements in the UI.
   --- @field root LuaGuiElement? Root element of the tree.
   --- @field event_handlers table<defines.events, table<string, GuiElemHandler>>
   local gui = {
      -- elements
      id = gui_id,
      prefix = prefix,
      count = 1,
      ui_elements = {},
      root = nil,
      event_handlers = {},
   }

   -- predefine arrays for all supported events
   for name, id in pairs(defines.events) do
      if name:sub(1, 7) == "on_gui_" then
         gui.event_handlers[id] = {}
      end
   end

   setmetatable(gui, { __index = FrameworkGui})
   return gui
end

--- Finds a registered element in this Gui by name.
--- @param name string
--- @return LuaGuiElement? gui_element A registered gui element or nil.
function FrameworkGui:find_element(name)
   local ui_name = self:generate_gui_name(name)
   return self.ui_elements[ui_name]
end

------------------------------------------------------------------------

--- Dispatch an event to the handler associated with this event and GUI element.
--- @param ev FrameworkGuiEventData
--- @return boolean handled True if an event handler was called, False otherwise.
function FrameworkGui:dispatch(ev)
   if not ev then return false end

   local elem = ev.element
   if not Is.Valid(elem) then return false end

   -- sanity check
   local tags = elem.tags --[[@as Tags]]
   local gui_id = tags[self.prefix .. 'id']
   assert(gui_id == self.id)

   local event_id = ev.name
   local handlers = self.event_handlers[event_id]
   assert(handlers)
   if not handlers[elem.name] then return false end

   handlers[elem.name](ev)
   return true
end


--- @class FrameworkGuiElementExtras
--- @field style_mods table<string, any>? Post-creation modifications to make to the element's style.
--- @field elem_mods table<string, any>? Post-creation modifications to make to the element itself.
--- @field drag_target string? Set the element's drag target to the element whose name matches this string. The drag target must be present in the UI component tree before assigning it.
--- @field handler (GuiElemHandler|table<defines.events, GuiElemHandler>)? Handler(s) to assign to this element. If assigned to a function, that function will be called for any GUI event on this element.
--- @field children FrameworkGuiElemDef[]? Children to add to this element.

--- A GUI element definition. This extends `LuaGuiElement.add_param` with several new attributes.
--- @class FrameworkGuiElemDef: LuaGuiElement
--- @field style_mods table<string, any>? Post-creation modifications to make to the element's style.
--- @field elem_mods table<string, any>? Post-creation modifications to make to the element itself.
--- @field drag_target string? Set the element's drag target to the element whose name matches this string. The drag target must be present in the UI component tree before assigning it.
--- @field handler (GuiElemHandler|table<defines.events, GuiElemHandler>)? Handler(s) to assign to this element. If assigned to a function, that function will be called for any GUI event on this element.
--- @field children FrameworkGuiElemDef[]? Children to add to this element.
--- @field tab FrameworkGuiElemDef? To add a tab, specify `tab` and `content` and leave all other fields unset.
--- @field content FrameworkGuiElemDef? To add a tab, specify `tab` and `content` and leave all other fields unset.

--- A handler function to invoke when receiving GUI events for this element.
--- @alias FrameworkGuiElemHandler fun(e: FrameworkGuiEventData)

--- Aggregate type of all possible GUI events.
--- @alias FrameworkGuiEventData EventData.on_gui_checked_state_changed|EventData.on_gui_click|EventData.on_gui_closed|EventData.on_gui_confirmed|EventData.on_gui_elem_changed|EventData.on_gui_location_changed|EventData.on_gui_opened|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_switch_state_changed|EventData.on_gui_text_changed|EventData.on_gui_value_changed

return FrameworkGui
