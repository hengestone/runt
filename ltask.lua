local cfg = require("luarocks.cfg")
cfg.init_package_paths()
local os = require("os")
local logging = require("logging")
local inspect = require("inspect")
local cli = require('cliargs')
local appender
appender = function(obj, level, msg)
  io.write(tostring(level) .. " " .. tostring(string.rep(' ', 5 - #level)))
  return io.write(tostring(msg) .. "\n")
end
local taskmodules = { }
local TaskRunner
do
  local _class_0
  local _base_0 = {
    start = function(self)
      return self:dotask(self.spec, self.args)
    end,
    _parse_args = function(self)
      cli:argument("SPEC", "task spec", nil)
      cli:splat("ARGS", "task arguments", nil, 10)
      cli:option("-f, --file=FILE", "ltask file")
      cli:option("-c, --configdir=DIR", "path to search for config files")
      cli:option("-l, --libdir=DIR", "path to search for .ltask files")
      cli:option("-v, --loglevel=LEVEL", "log level, DEBUG, INFO, WARN, ERROR, FATAL")
      cli:flag("-h, --help", "print help text", false)
      cli:flag("-d, --debug", "set loglevel to DEBUG", false)
      return cli:parse()
    end,
    dotask = function(self, spec, args)
      local mod, sep, task = string.match(spec, "(%w.*)(:?)(.*)")
      if not task or #task == 0 then
        task = "default"
      end
      self.logger:info("Processing spec: " .. tostring(mod) .. ":" .. tostring(task))
      local module = { }
      if not self.taskmods[mod] or not self.taskmods[mod][task] then
        local fname = self:_findfile(mod)
        if fname then
          module = dofile(fname)
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
        local errmsg = "unknown task spec " .. tostring(mod) .. ":" .. tostring(task)
        self.logger:error(errmsg)
        return nil, errmsg
      end
      local deps = module.depends or { }
      for i, dspec in ipairs(deps) do
        local _continue_0 = false
        repeat
          local depmod, deptask
          depmod, sep, deptask = string.match(dspec, "(%w.*)(:?)(.*)")
          local depstate = self.depsdone[depmod .. sep .. deptask]
          if depstate and not depstate.err then
            _continue_0 = true
            break
          end
          local done, err = self:dotask(dspec, { })
          table.insert(self.depsdone, {
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
        local done, err = taskspec.task(spec, args, self)
        table.insert(self.depsdone, {
          [mod .. ":" .. task] = {
            done = done,
            err = err
          }
        })
        return done, err
      end
    end,
    _findfile = function(self, name)
      for i, dir in ipairs(self.taskpaths) do
        local fname = (dir .. "/" .. name .. ".ltask"):gsub("//", "/")
        self.logger:debug("Trying file " .. tostring(fname))
        local f, err = io.open(fname, "r")
        if f then
          f:close()
          return fname
        end
      end
      return nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.taskmods = { }
      self.depsdone = { }
      self.taskpaths = {
        "./",
        "ltask"
      }
      self.configpaths = {
        "./",
        "config"
      }
      self.logger = logging.new(appender)
      self.logger.level = nil
      local msg
      self.cmdline, msg = self:_parse_args()
      if not self.cmdline and msg then
        return print(msg)
      else
        if self.cmdline.debug then
          self.logger:setLevel("DEBUG")
        else
          self.logger:setLevel(self.cmdline.loglevel or "WARN")
        end
        self.logger:debug("Command line: " .. tostring(inspect(self.cmdline, {
          newline = " ",
          indent = ""
        })))
        if self.cmdline.libdir then
          table.insert(self.taskpaths, 1, self.cmdline.libdir)
        end
        self.logger:debug("Task search path: " .. tostring(inspect(self.taskpaths)))
        if self.cmdline.configdir then
          table.insert(self.configpaths, 1, self.cmdline.configdir)
        end
        self.logger:debug("Config search path: " .. tostring(inspect(self.configpaths)))
        self.spec = self.cmdline.SPEC
        self.logger:info("Task spec: " .. tostring(self.spec))
        self.args = self.cmdline.ARGS
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
local tasker = TaskRunner()
if tasker.cmdline then
  return tasker:start()
end
