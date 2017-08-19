-- ltask
-- set up paths
cfg = require "luarocks.cfg"
cfg.init_package_paths()

os = require "os"
serpent = require "serpent"

-- logging module
logging = require "logging"
require "logging.console"

taskmodules = {}
class TaskRunner
  new: (arglist) =>
    @taskmods = {}
    @depsdone = {}
    @paths = {"./", "ltask"}
    @logger = logging.new((obj, level, msg) -> print(msg))
    @spec = arglist[1]
    @logger\debug(@spec)
    @args = {}
    for i, v in pairs(arglist)
      if i > 1
        table.insert(@args, v)


  start: () =>
    @dotask(@spec)

  dotask: (spec) =>
    -- determine module and task name
    @logger\debug(serpent.serialize(spec))
    mod, task = string.match(spec, "(%w.*):?(.*)")

    -- default task name fallback
    if not task or #task == 0
      task = "default"

    -- load code from file or cache
    module = {}
    if not @taskmods[mod] or not @taskmods[mod][task]
      fname = @_findfile(mod)

      if fname
        module = dofile(mod .. ".ltask")

      if not module or not module
        return nil, "unknown task module #{mod}"
      @taskmods[mod] = module
    else
      module = @taskmods[mod]

    -- get task spec
    taskspec = module[task]

    if not taskspec
      return nil, "unknown task spec #{mod}:#{task}"

    deps = module.depends or {} -- table of "module:task" strings

    for i, dspec in ipairs(deps)
      depmod, sep, deptask = string.match(dspec, "(%w.*)(:?)(.*)")
      depstate = @depsdone[depmod .. sep .. deptask]
      if depstate and not depstate.err -- dependency already done
        continue

      done, err = @dotask(dspec, {})
      @depsdone.insert([depmod .. sep .. deptask]: {done: done, err: err})
      if err
        return nil, err

    if taskspec.done != nil and ((type(taskspec.done) == "function" and taskspec.done(specs)) or taskspec.done)
      return true, nil
    else
      return taskspec.task(specs, self)

  _findfile: (name) =>
    for i, dir in ipairs(@paths)
      fname = dir .. name .. ".ltask"
      @logger\debug("trying file #{fname}")
      f, err = io.open(dir .. name .. ".ltask")
      if f
        f:close()
        return fname
    nil


tasker = TaskRunner(arg)
tasker\start()