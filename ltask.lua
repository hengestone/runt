local cfg = require("luarocks.cfg")
cfg.init_package_paths()
local os = require("os")
local serpent = require("serpent")
local logging = require("logging")
require("logging.console")
local taskmodules = { }
local TaskRunner
do
  local _class_0
  local _base_0 = {
    start = function(self)
      return self:dotask(self.spec)
    end,
    dotask = function(self, spec)
      self.logger:debug(serpent.serialize(spec))
      local mod, task = string.match(spec, "(%w.*):?(.*)")
      if not task or #task == 0 then
        task = "default"
      end
      local module = { }
      if not self.taskmods[mod] or not self.taskmods[mod][task] then
        local fname = self:_findfile(mod)
        if fname then
          module = dofile(mod .. ".ltask")
        end
        if not module or not module then
          return nil, "unknown task module " .. tostring(mod)
        end
        self.taskmods[mod] = module
      else
        module = self.taskmods[mod]
      end
      local taskspec = module[task]
      if not taskspec then
        return nil, "unknown task spec " .. tostring(mod) .. ":" .. tostring(task)
      end
      local deps = module.depends or { }
      for i, dspec in ipairs(deps) do
        local _continue_0 = false
        repeat
          local depmod, sep, deptask = string.match(dspec, "(%w.*)(:?)(.*)")
          local depstate = self.depsdone[depmod .. sep .. deptask]
          if depstate and not depstate.err then
            _continue_0 = true
            break
          end
          local done, err = self:dotask(dspec, { })
          self.depsdone.insert({
            [depmod .. sep .. deptask] = {
              done = done,
              err = err
            }
          })
          if err then
            return nil, err
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if taskspec.done ~= nil and ((type(taskspec.done) == "function" and taskspec.done(specs)) or taskspec.done) then
        return true, nil
      else
        return taskspec.task(specs, self)
      end
    end,
    _findfile = function(self, name)
      for i, dir in ipairs(self.paths) do
        local fname = dir .. name .. ".ltask"
        self.logger:debug("trying file " .. tostring(fname))
        local f, err = io.open(dir .. name .. ".ltask")
        if f({
          f = close()
        }) then
          return fname
        end
      end
      return nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, arglist)
      self.taskmods = { }
      self.depsdone = { }
      self.paths = {
        "./",
        "ltask"
      }
      self.logger = logging.new(function(obj, level, msg)
        return print(msg)
      end)
      self.spec = arglist[1]
      self.logger:debug(self.spec)
      self.args = { }
      for i, v in pairs(arglist) do
        if i > 1 then
          table.insert(self.args, v)
        end
      end
    end,
    __base = _base_0,
    __name = "TaskRunner"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  TaskRunner = _class_0
end
local tasker = TaskRunner(arg)
return tasker:start()
