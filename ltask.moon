-- ltask
-- set up paths
cfg = require "luarocks.cfg"
cfg.init_package_paths()
os = require "os"

-- logging module
logging = require "logging"
inspect = require "inspect"

-- command line arguments parser
cli = require 'cliargs'

appender = (obj, level, msg) ->
  io.write("#{level} #{string.rep(' ', 5 - #level)}")
  io.write("#{msg}\n")

taskmodules = {}
class TaskRunner
  new: () =>
    @taskmods = {}
    @depsdone = {}
    @taskpaths = {"./", "ltask"}
    @configpaths = {"./", "config"}
    @logger = logging.new(appender)
    @logger.level = nil
    @cmdline, msg = @_parse_args()
    if not @cmdline and msg
      print msg
    else
      -- Set log level
      if @cmdline.debug
        @logger\setLevel("DEBUG")
      else
        @logger\setLevel(@cmdline.loglevel or "WARN")
      @logger\debug("Command line: #{inspect(@cmdline, {newline: " ", indent: ""})}")

      -- set task search dir
      if @cmdline.libdir
        table.insert(@taskpaths, 1, @cmdline.libdir)
      @logger\debug("Task search path: #{inspect(@taskpaths)}")

      -- set config search dir
      if @cmdline.configdir
        table.insert(@configpaths, 1, @cmdline.configdir)
      @logger\debug("Config search path: #{inspect(@configpaths)}")
      @spec = @cmdline.SPEC
      @logger\info("Task spec: #{@spec}")
      @args = @cmdline.ARGS

  start: () =>
    @dotask(@spec, @args)

  _parse_args: () =>
    cli\argument("SPEC", "task spec", nil)
    cli\splat("ARGS", "task arguments", nil, 10)
    cli\option("-f, --file=FILE", "ltask file")
    cli\option("-c, --configdir=DIR", "path to search for config files")
    cli\option("-l, --libdir=DIR", "path to search for .ltask files")
    cli\option("-v, --loglevel=LEVEL", "log level, DEBUG, INFO, WARN, ERROR, FATAL")
    cli\flag("-h, --help", "print help text", false)
    cli\flag("-d, --debug", "set loglevel to DEBUG", false)
    cli\parse()

  dotask: (spec, args) =>
    -- determine module and task name
    mod, sep, task = string.match(spec, "(%w.*)(:?)(.*)")

    -- default task name fallback
    if not task or #task == 0
      task = "default"
    @logger\info("Processing spec: #{mod}:#{task}")
    -- load code from file or cache
    module = {}
    if not @taskmods[mod] or not @taskmods[mod][task]
      fname = @_findfile(mod)

      if fname
        module = dofile(fname)

      if not module or not module
        return nil, "unknown task module #{mod}"
      @taskmods[mod] = module
    else
      module = @taskmods[mod]

    -- get task spec
    taskspec = module[task]

    if not taskspec
      errmsg = "unknown task spec #{mod}:#{task}"
      @logger\error(errmsg)
      return nil, errmsg

    deps = module.depends or {} -- table of "module:task" strings

    for i, dspec in ipairs(deps)
      depmod, sep, deptask = string.match(dspec, "(%w.*)(:?)(.*)")
      depstate = @depsdone[depmod .. sep .. deptask]
      if depstate and not depstate.err -- dependency already done
        continue

      done, err = @dotask(dspec, {})
      table.insert(@depsdone, [depmod .. sep .. deptask]: {done: done, err: err})
      if err
        return nil, err

    if taskspec.done != nil and ((type(taskspec.done) == "function" and taskspec.done(specs)) or taskspec.done)
      return true, nil
    else
      done, err = taskspec.task(spec, args, self)
      table.insert(@depsdone, [mod .. ":" .. task]: {done: done, err: err})
      return done, err

  _findfile: (name) =>
    for i, dir in ipairs(@taskpaths)
      fname = (dir .. "/" .. name .. ".ltask")\gsub("//", "/")
      @logger\debug("Trying file #{fname}")
      f, err = io.open(fname, "r")
      if f
        f\close()
        return fname
    nil


tasker = TaskRunner()
if tasker.cmdline
  tasker\start()