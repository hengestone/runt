package = "ltask"
version = "scm-1"

source = {
  url = "git://github.com/hengestone/ltask.git",
  branch = "master"
}

description = {
  summary = "Task runner in Lua",
  homepage = "https://github.com/hengestone/ltask",
  maintainer = "Conrad Steenberg <conrad.steenberg@gmail.com>",
  license = "MPLv2"
}

dependencies = {
  "lua ~> 5.1",
  "luarocks ~> 2.4.2",
  "lualogging ~> 1.3.0",
  "lua_cliargs ~> 3.0",
  "inspect ~> 3.1.0"
}

build = {
  type = "none",
  install = {
    bin = {
      ["ltask"] = "ltask",
    }
  }
}

