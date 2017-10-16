runt
====

Lua task runner/command line user interface builder in the vein of [Thor][thor] for ruby projects

[thor]: http://whatisthor.com/

Installation
------------
    luarocks install runt

Usage
-----
`runt module:task` or just `runt module` in which case the `default` task is executed.

List module
-----------
`runt list` or `runt list:default` lists all task modules and the tasks they contain.

`runt list:modules` shows module files found.

`runt list:taskpaths` shows all search paths scanned for task module files. The default search path is the current directory as well as the `runt/` subdirectory, followed by the `luarocks` Lua library search path and it's `runt/` subdirectory.

E.g.
```
.
runt
/home/conrad/.luarocks/share/lua/5.1
/home/conrad/.luarocks/share/lua/5.1/runt
/usr/local/share/lua/5.1/runt
```

`runt list:configpaths` will do the same for configuration paths. The default is the subdirectory `config/`.

Task module files
-----------------

Module files are Lua source files returning a table with keys denoting a specific task, of the form
```
return {
  default =
    {
      desc = "Default task",
      task = function(spec, args, runt)
             end
    }
}
```
Module files should have the extension `.runt`. The arguments to the `task` key are the task spec, e.g. `list:paths`. The `args` are an array of command line arguments given after the module spec, and `runt` is the calling object.

E.g. a command line of ```runt list:paths onlycurrent```

would result in the path function called as ```task("list:paths", {"onlycurrent"}, <runt object>)```
