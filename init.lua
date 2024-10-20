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
			ui.Constraint.Length(1),
		})
		:split(self._area)
end

function Pane:build(tab, pane)
  local header = Header:new(self._chunks[1], tab)
  header.pane = pane
	self._children = {
		header,
		Tab:new(self._chunks[2], tab),
		Status:new(self._chunks[3], tab),
	}
end

setmetatable(Pane, { __index = Root })

local DualPane = {
  pane = nil,
  left = 0,
  right = 0,
  view = nil,    -- 0 = dual, 1 = current zoomed 

  old_root_layout = nil,
  old_root_build = nil,
  old_tab_layout = nil,
  old_header_cwd = nil,
  old_header_tabs = nil,

  _create = function(self)
    self.pane = 0
    if #cx.tabs > 1 then
      self.right = 1
    end

    self.old_root_layout = Root.layout
    Root.layout = function(root)
      root._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
          ui.Constraint.Percentage(50),
          ui.Constraint.Percentage(50),
        })
        :split(root._area)
    end

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

      local active
      if header.pane == 0 then
        active = self.left + 1
      else
        active = self.right + 1
      end
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

    self.old_root_build = Root.build
    Root.build = function(root)
      root._children = {
        Pane:new(root._chunks[1], cx.tabs[self.left + 1], 0),
        Pane:new(root._chunks[2], cx.tabs[self.right + 1], 1),
      }
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

  _config_dual_pane = function(self)
    Root.layout = function(root)
      root._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
          ui.Constraint.Percentage(50),
          ui.Constraint.Percentage(50),
        })
        :split(root._area)
    end

    Root.build = function(root)
      root._children = {
        Pane:new(root._chunks[1], cx.tabs[self.left + 1], 0),
        Pane:new(root._chunks[2], cx.tabs[self.right + 1], 1),
      }
    end
  end,

  _config_single_pane = function(self)
    Root.layout = function(root)
      root._chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
          ui.Constraint.Percentage(100),
        })
        :split(root._area)
    end

    Root.build = function(root)
      local tab_idx, pane_idx
      if self.pane == 0 then
        tab_idx = self.left + 1
      else
        tab_idx = self.right + 1
      end
      root._children = {
        Pane:new(root._chunks[1], cx.tabs[tab_idx], self.pane),
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
    if self.pane then
      self.pane = (self.pane + 1) % 2
      local tab
      if self.pane == 0 then
        tab = self.left
      else
        tab = self.right
      end
      ya.manager_emit("tab_switch", { tab })
    end
  end,

  -- Copy selected files, or if there are none, the hovered item, to the
  -- destination directory
  copy_files = function(self, cut, force, follow)
    if self.view then
      local src_tab, dst_tab
      if self.pane == 0 then
        src_tab = self.left
        dst_tab = self.right
      else
        src_tab = self.right
        dst_tab = self.left
      end
      -- yank selected
      if cut then
        ya.manager_emit("yank", { cut = true })
      else
        ya.manager_emit("yank", {})
      end
      -- select dst tab
      ya.manager_emit("tab_switch", { dst_tab })
      -- paste
      ya.manager_emit("paste", { force = force, follow = follow })
      -- unyank
      ya.manager_emit("unyank", {})
      -- select src tab again
      ya.manager_emit("tab_switch", { src_tab })
      ya.app_emit("resize", {})
    end
  end,

  tab_switch = function(self, tab_number)
    if self.pane then
      if self.pane == 0 then
        self.left = tab_number
      else
        self.right = tab_number
      end
    end
    ya.manager_emit("tab_switch", { tab_number })
  end,
}

local function entry(_, args)
  local action = args[1]
  if not action then
    return
  end

  if action == "toggle" then
    DualPane:toggle()
    return
  end

  if action == "toggle_zoom" then
    DualPane:toggle_zoom()
    return
  end

  if action == "next_pane" then
    DualPane:focus_next()
    return
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

  if action == "copy_files" then
    local force, follow = get_copy_arguments(args)
    DualPane:copy_files(false, force, follow)
  end

  if action == "move_files" then
    local force, follow = get_copy_arguments(args)
    DualPane:copy_files(true, force, follow)
  end

  if action == "tab_switch" then
    if args[2] then
      local tab =  tonumber(args[2])
      if args[3] then
        if args[3] == "--relative" then
          if DualPane.pane then
            if DualPane.pane == 0 then
              tab = (DualPane.left + tab) % #cx.tabs
            else
              tab = (DualPane.right + tab) % #cx.tabs
            end
          else
            tab = (cx.tabs.idx - 1 + tab) % #cx.tabs
          end
        end
      end
      DualPane:tab_switch(tab)
    end
    return
  end

  if action == "tab_create" then
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
    if DualPane.pane == 0 then
      if DualPane.right > DualPane.left then
        DualPane.right = DualPane.right + 1
      end
    else
      if DualPane.left > DualPane.right then
        DualPane.left = DualPane.left + 1
      end
    end
    -- The new tab number is `cx.tabs.idx + 1`, but left and right are zero
    -- based, so substract 1
    DualPane:tab_switch(cx.tabs.idx)
    -- At this point, the new tab may have not been created yet, as
    -- ya.manager_emit() is not synchronous. So we have the "other" pane
    -- in a limbo state until we switch to it manually (ordering doesn't
    -- respect the global configuration)
  end
end

local function setup(_, opts)
end

return {
  entry = entry,
  setup = setup,
}
