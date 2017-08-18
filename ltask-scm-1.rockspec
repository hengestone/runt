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
  "lua ~> 5.1"
}

build = {
  type = "builtin",
  modules = {
    ["ltask"] = "ltask.lua",
  },
  install = {
    bin = {
      ["ltask"] = "ltask",
    }
  }
}

