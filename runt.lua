local cfg = require("luarocks.cfg")
cfg.init_package_paths()
local util = require("luarocks.util")
local dir = require("path")
local lfs = require("lfs")
local debug = require("debug")
local os = require("os")
local logging = require("logging")
local inspect = require("inspect")
local cli = require("cliargs")
local cliconfig = require("cliargs.config_loader")
local appender
appender = function(obj, level, msg)
  io.write(tostring(level) .. " " .. tostring(string.rep(' ', 5 - #level)))
  return io.write(tostring(msg) .. "\n")
end
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
      cli:option("-c, --configdir=DIR", "path to search for config files")
      cli:option("-l, --libdir=DIR", "path to search for .ltask files")
      cli:option("-v, --loglevel=LEVEL", "log level, DEBUG, INFO, WARN, ERROR, FATAL")
      cli:flag("-h, --help", "print help text", false)
      cli:flag("-n, --nosystem", "don't look for runt scripts in system paths", false)
      cli:flag("-d, --debug", "set loglevel to DEBUG", false)
      return cli:parse()
    end,
    dotask = function(self, spec, args)
      local mod, sep, task = string.match(spec, "(%w*)(:?)(.*)")
      if not task or #task == 0 then
        task = "default"
      end
      self.logger:info("Processing spec: " .. tostring(mod) .. ":" .. tostring(task))
      local module = { }
      if not self.tasks[mod] or not self.tasks[mod][task] then
        local fname = self:_findfile(mod, self.taskpaths, {
          "runt"
        })
        if fname then
          module = dofile(fname)
          self.logger:debug(inspect(module))
        end
        if not module or not module then
          return nil, "unknown task module " .. tostring(mod)
        end
        self.tasks[mod] = module
      else
        module = self.tasks[mod]
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
    show_module = function(self, name, module)
      print(name)
      for i = 1, #name do
        io.stdout:write("-")
      end
      io.stdout:write("\n")
      for task_name, task_info in pairs(module) do
        io.stdout:write(tostring(task_name))
        for i = 1, 16 - #task_name do
          io.stdout:write(" ")
        end
        if task_info.desc then
          print(tostring(task_info.desc))
        else
          print("no description")
        end
      end
    end,
    _config_lookup = function(configtable, name)
      local value = rawget(configtable, name)
      if value then
        return value
      end
      local _parent = configtable._parent
      _parent.logger:debug("_config_lookup: " .. tostring(name))
      local fname = _parent:_findfile(name, _parent.configpaths, _parent.config_exts)
      if fname then
        local ext = string.match(fname, ".*%.(%w+)")
        return cliconfig["from_" .. ext](fname)
      end
      return nil
    end,
    _setup_config = function(self)
      self.config._parent = self
      self.config_exts = { }
      for ext, method in pairs(cliconfig.FORMAT_LOADERS) do
        table.insert(self.config_exts, ext)
      end
      table.sort(self.config_exts)
      return setmetatable(self.config, {
        __index = self._config_lookup
      })
    end,
    _findfile = function(self, name, paths, exts)
      self.logger:debug("_findfile:\npaths: " .. tostring(inspect(paths, {
        newline = " ",
        indent = ""
      })) .. "\nexts : " .. tostring(inspect(exts, {
        newline = " ",
        indent = ""
      })))
      for i, dir in ipairs(paths) do
        for j, ext in ipairs(exts) do
          local fname = (dir .. "/" .. name .. "." .. ext):gsub("//", "/")
          local f, err = io.open(fname, "r")
          if f then
            self.logger:info("Found file " .. tostring(fname))
            f:close()
            return fname
          end
        end
      end
      self.logger:debug("_findfile returning nil")
      return nil
    end,
    _setup_paths = function(self, paths)
      local newpaths = { }
      local pmap = { }
      for i, path in ipairs(paths) do
        pmap[path] = true
        table.insert(newpaths, dir.normalize(path))
      end
      local script_path = dir.dirname(debug.getinfo(appender).source:sub(2))
      self.logger:debug("Script path " .. tostring(script_path))
      if not pmap[script_path] then
        table.insert(newpaths, script_path)
        pmap[script_path] = true
      end
      local package_paths = util.split_string(cfg.package_paths(), ";")
      for i, path in ipairs(package_paths) do
        local ppath = dir.normalize(util.split_string(path, "?")[1])
        local npath = ppath .. "/runt"
        if not pmap[npath] then
          pmap[npath] = true
          table.insert(newpaths, npath)
        end
      end
      return newpaths
    end,
    _list_files_sorted = function(self, path)
      local ndir = dir.normalize(path)
      local fullpath, err = dir.isdir(ndir)
      if err or not fullpath then
        return nil, "No such directory " .. tostring(ndir)
      end
      local dirs = { }
      for fname in lfs.dir(ndir) do
        table.insert(dirs, fname)
      end
      table.sort(dirs)
      return dirs
    end,
    _relpath = function(self, dir, fname)
      local fullpath = path.fullpath(fname)
      print("fullpath = " .. tostring(fullpath))
      local s, e = string.find(fullpath, dir, 1, true)
      local res = string.sub(fullpath, e + 2)
      print("res = " .. tostring(res))
      return res
    end,
    list_files = function(self, path)
      local fnames, err = self:_list_files_sorted(path)
      if not err then
        self.logger:debug("list_files in " .. tostring(path) .. ":\n" .. inspect(fnames))
        local result = { }
        for i, fname in ipairs(fnames) do
          local name = string.match(fname, "(.*)%.runt")
          local fullpath = dir.join(path, fname)
          if name and dir.isfile(fullpath) then
            result[name] = fullpath
          end
        end
        return result, nil
      else
        self.logger:debug("list_files: " .. err)
        return { }, err
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, islib)
      self.tasks = { }
      self.config = { }
      self.depsdone = { }
      self.taskpaths = {
        ".",
        "runt"
      }
      self.configpaths = {
        "config"
      }
      self:_setup_config()
      self.logger = logging.new(appender)
      self.logger.level = nil
      local msg
      self.cmdline, msg = self:_parse_args()
      if not self.cmdline and msg then
        if not islib then
          return print("FATAL: " .. tostring(msg))
        end
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
          local libdirs_semi = util.split_string(path, ";")
          local libdirs_comma = util.split_string(path, ",")
          local libdirs = libdirs_comma
          if #libdirs_semi > #libdirs then
            libdirs = libdirs_semi
          end
          for i, path in ipairs(libdirs) do
            table.insert(self.taskpaths, 1, path)
          end
        end
        if not self.cmdline.nosystem then
          self.taskpaths = self:_setup_paths(self.taskpaths)
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
  return _class_0
end
