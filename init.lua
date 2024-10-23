local Pane = {
  _id = "pane",
}

function Pane:new(area, tab, pane)
  local me = setmetatable({ _area = area }, { __index = self })
  me:layout()
  me:build(tab, pane)
  return me
end

function Pane:layout()
  self._chunks = ui.Layout()
    :direction(ui.Layout.VERTICAL)
    :constraints({
      ui.Constraint.Length(1),
      ui.Constraint.Fill(1),
    })
    :split(self._area)
end

function Pane:build(tab, pane)
  local header = Header:new(self._chunks[1], tab)
  header.pane = pane
  self._children = {
    header,
    Tab:new(self._chunks[2], tab),
  }
end

setmetatable(Pane, { __index = Root })

local Panes = {
  _id = "panes"
}

function Panes:new(area, tab_left, tab_right)
  local me = setmetatable({ _area = area }, { __index = self })
  me:layout()
  me:build(tab_left, tab_right)
  return me
end

function Panes:layout()
  self._chunks = ui.Layout()
    :direction(ui.Layout.VERTICAL)
    :constraints({
      ui.Constraint.Fill(1),
      ui.Constraint.Length(1),
    })
    :split(self._area)

  self._panes_chunks = ui.Layout()
    :direction(ui.Layout.HORIZONTAL)
    :constraints({
      ui.Constraint.Percentage(50),
      ui.Constraint.Percentage(50),
    })
    :split(self._chunks[1])
end

function Panes:build(tab_left, tab_right)
  self._children = {
    Pane:new(self._panes_chunks[1], tab_left, 1),
    Pane:new(self._panes_chunks[2], tab_right, 2),
    Status:new(self._chunks[2], cx.active),
  }
end

setmetatable(Panes, { __index = Root })

local DualPane = {
  pane = nil,
  tabs = {},
  view = nil, -- 0 = dual, 1 = current zoomed

  old_root_layout = nil,
  old_root_build = nil,
  old_tab_layout = nil,
  old_header_cwd = nil,
  old_header_tabs = nil,

  _create = function(self)
    self.pane = 1
    if cx then
      self.tabs[1] = cx.tabs.idx
      if #cx.tabs > 1 then
        self.tabs[2] = cx.tabs.idx % #cx.tabs + 1
      else
        self.tabs[2] = self.tabs[1]
      end
    else
      self.tabs[1] = 1
      self.tabs[2] = 1
    end

    self.old_root_layout = Root.layout
    self.old_root_build = Root.build
    self._config_dual_pane(self)

    self.old_header_cwd = Header.cwd
    Header.cwd = function(header)
      local max = header._area.w - header._right_width
      if max <= 0 then
        return ui.Span("")
      end

      local s = ya.readable_path(tostring(header._tab.current.cwd)) .. header:flags()
      if header.pane == self.pane then
        return ui.Span(ya.truncate(s, { max = max, rtl = true })):style(THEME.manager.tab_active)
      else
        return ui.Span(ya.truncate(s, { max = max, rtl = true })):style(THEME.manager.tab_inactive)
      end
    end

    self.old_header_tabs = Header.tabs
    Header.tabs = function(header)
      local tabs = #cx.tabs
      if tabs == 1 then
        return ui.Line {}
      end

      local active = self.tabs[header.pane]
      local spans = {}
      for i = 1, tabs do
        local text = i
        if THEME.manager.tab_width > 2 then
          text = ya.truncate(text .. " " .. cx.tabs[i]:name(), { max = THEME.manager.tab_width })
        end
        if i == active then
          spans[#spans + 1] = ui.Span(" " .. text .. " "):style(THEME.manager.tab_active)
        else
          spans[#spans + 1] = ui.Span(" " .. text .. " "):style(THEME.manager.tab_inactive)
        end
      end
      return ui.Line(spans)
    end

    self.old_tab_layout = Tab.layout
    Tab.layout = function(self)
      self._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
          ui.Constraint.Percentage(0),
          ui.Constraint.Percentage(100),
          ui.Constraint.Percentage(0),
        })
        :split(self._area)
    end
  end,

  _destroy = function(self)
    Root.layout = self.old_root_layout
    self.old_root_layout = nil
    Root.build = self.old_root_build
    self.old_root_build = nil
    Tab.layout = self.old_tab_layout
    self.old_tab_layout = nil
    Header.cwd = self.old_header_cwd
    self.old_header_cwd = nil
    Header.tabs = self.old_header_tabs
    self.old_header_tabs = nil
  end,

  -- This function tests all the tabs in self.tabs are still valid. Some could
  -- have been deleted and we wouldn't get notified because tab_close is not
  -- a dual-pane command. If any is invalid, choose another one.
  _verify_update_tabs = function(self)
    for i = 1, #self.tabs do
      if cx.tabs[self.tabs[i]] == nil then
        self.tabs[i] = cx.tabs.idx
      end
    end
  end,

  _config_dual_pane = function(self)
    Root.layout = function(root)
      root._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
          ui.Constraint.Percentage(100),
        })
        :split(root._area)
    end

    Root.build = function(root)
      self._verify_update_tabs(self)
      root._children = {
        Panes:new(root._chunks[1], cx.tabs[self.tabs[1]], cx.tabs[self.tabs[2]]),
      }
    end
  end,

  _config_single_pane = function(self)
    Root.layout = function(root)
      root._chunks = ui.Layout()
        :direction(ui.Layout.VERTICAL)
        :constraints({
          ui.Constraint.Fill(1),
          ui.Constraint.Length(1),
        })
        :split(root._area)
    end

    Root.build = function(root)
      self._verify_update_tabs(self)
      local tab = cx.tabs[self.tabs[self.pane]]
      root._children = {
        Pane:new(root._chunks[1], tab, self.pane),
        Status:new(root._chunks[2], tab),
      }
    end
  end,

  toggle = function(self)
    if self.view == nil then
      self._create(self)
      self.view = 0
    else
      self._destroy(self)
      self.view = nil
    end
    ya.app_emit("resize", {})
  end,

  toggle_zoom = function(self)
    if self.view then
      if self.view == 0 then
        self._config_single_pane(self)
        self.view = 1
      else
        self._config_dual_pane(self)
        self.view = 0
      end
      ya.app_emit("resize", {})
    end
  end,

  focus_next = function(self)
    if self.view and self.pane then
      self.pane = self.pane % 2 + 1
      local tab = self.tabs[self.pane]
      ya.manager_emit("tab_switch", { tab - 1 })
    end
  end,

  -- Copy selected files, or if there are none, the hovered item, to the
  -- destination directory
  copy_files = function(self, cut, force, follow)
    if self.view then
      local src_tab = self.tabs[self.pane]
      local dst_tab = self.tabs[self.pane % 2 + 1]
      -- yank selected
      if cut then
        ya.manager_emit("yank", { cut = true })
      else
        ya.manager_emit("yank", {})
      end
      -- select dst tab
      ya.manager_emit("tab_switch", { dst_tab - 1 })
      -- paste
      ya.manager_emit("paste", { force = force, follow = follow })
      -- unyank
      ya.manager_emit("unyank", {})
      -- select src tab again
      ya.manager_emit("tab_switch", { src_tab - 1 })
      ya.app_emit("resize", {})
    end
  end,

  tab_switch = function(self, tab_number)
    if self.pane then
      self.tabs[self.pane] = tab_number
    end
    ya.manager_emit("tab_switch", { tab_number - 1 })
  end,

  load_config = function(self, state)
    if self.view == nil then
      return
    end
    local len = #cx.tabs
    for _, path in ipairs(state.paths) do
      -- Create each tab
      ya.manager_emit("tab_create", { path })
    end
    -- Now delete the old ones
    for i = 1, len do
      ya.manager_emit("tab_close", { i - 1 })
    end
    self.tabs = { state.tabs[1], state.tabs[2] }
    self.pane = state.pane
    ya.manager_emit("tab_switch", { self.tabs[self.pane] - 1 })
  end,

  save_config = function(self, state)
    if self.view == nil then
      return
    end
    state = {}
    state.pane = self.pane
    state.tabs = { self.tabs[1], self.tabs[2] }
    state.paths = {}
    for i = 1, #cx.tabs do
      table.insert(state.paths, tostring(cx.tabs[i].current.cwd))
    end
    ps.pub_to(0, "@dual-pane", state)
  end,

  reset_config = function(self, state)
    if self.view == nil then
      return
    end
    state = nil
    ps.pub_to(0, "@dual-pane", state)
  end
}

local function load_state(state)
  ps.sub_remote("@dual-pane", function(body)
    if body then
      state.pane = 1
      state.tabs = {}
      state.paths = {}
      for key, value in pairs(body) do
        if key == "pane" then
          state.pane = value
        elseif key == "tabs" then
          for _, tab in ipairs(value) do
            table.insert(state.tabs, tab)
          end
        elseif key == "paths" then
          for _, path in ipairs(value) do
            table.insert(state.paths, path)
          end
        end
      end
    end
  end)
end

local function get_copy_arguments(args)
  local force = false
  local follow = false
  if args[2] then
    if args[2] == "--force" then
      force = true
    elseif args[2] == "--follow" then
      follow = true
    end
    if args[3] then
      if args[3] == "--force" then
        force = true
      elseif args[3] == "--follow" then
        follow = true
      end
    end
  end
  return force, follow
end

local function entry(state, args)
  local action = args[1]
  if not action then
    return
  end

  if action == "toggle" then
    DualPane:toggle()
  elseif action == "toggle_zoom" then
    DualPane:toggle_zoom()
  elseif action == "next_pane" then
    DualPane:focus_next()
  elseif action == "copy_files" then
    local force, follow = get_copy_arguments(args)
    DualPane:copy_files(false, force, follow)
  elseif action == "move_files" then
    local force, follow = get_copy_arguments(args)
    DualPane:copy_files(true, force, follow)
  elseif action == "tab_switch" then
    if args[2] then
      local tab = tonumber(args[2])
      if args[3] then
        if args[3] == "--relative" then
          if DualPane.pane then
            tab = (DualPane.tabs[DualPane.pane] - 1 + tab) % #cx.tabs
          else
            tab = (cx.tabs.idx - 1 + tab) % #cx.tabs
          end
        end
      end
      DualPane:tab_switch(tab + 1)
    end
  elseif action == "tab_create" then
    if args[2] then
      local dir
      if args[2] == "--current" then
        dir = cx.active.current.cwd
      else
        dir = args[2]
      end
      ya.manager_emit("tab_create", { dir })
    else
      ya.manager_emit("tab_create", {})
    end
    -- The new tab is cx.tabs.idx + 1, so we need to correct the non-active
    -- pane if its tab number is higher than the one in the non-active
    local this = DualPane.pane
    local other = DualPane.pane % 2 + 1
    if DualPane.tabs[other] > DualPane.tabs[this] then
      DualPane.tabs[other] = DualPane.tabs[other] + 1
    end
    DualPane:tab_switch(cx.tabs.idx + 1)
    -- At this point, the new tab may have not been created yet, as
    -- ya.manager_emit() is not synchronous. So we have the "other" pane
    -- in a limbo state until we switch to it manually (ordering doesn't
    -- respect the global configuration)
  elseif action == "load_config" then
    DualPane:load_config(state)
  elseif action == "save_config" then
    DualPane:save_config(state)
  elseif action == "reset_config" then
    DualPane:reset_config(state)
  end
end

local function setup(state, opts)
  -- Start listener
  load_state(state)

  if opts then
    if opts.enabled then
      DualPane:toggle()
    end
  end
end

return {
  entry = entry,
  setup = setup,
}
