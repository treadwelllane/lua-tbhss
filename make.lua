local env = {

  name = "tbhss",
  version = "0.0.48-1",
  variable_prefix = "TBHSS",
  public = true,

  cflags = { "-march=native", "-O3", "-Wall", "-Wextra", "-Wno-unused-function", "-Wno-sign-conversion", "-Wsign-compare", "-Wstrict-overflow", "-Wpointer-sign", },
  ldflags = { "-march=native", "-O3", "-lm", },


  dependencies = {
    "lua == 5.1",
    "lua-cjson >= 2.1.0.10-1",
    "argparse >= 0.7.1-1",
    "santoku == 0.0.256-1",
    "santoku-fs == 0.0.33-1",
    "santoku-system == 0.0.46-1",
    "santoku-tsetlin == 0.0.71-1",
    "santoku-bitmap == 0.0.40-1",
    "santoku-matrix == 0.0.13-1",
    "santoku-sqlite == 0.0.22-1",
    "santoku-sqlite-migrate == 0.0.13-1",
    "lsqlite3 >= 0.9.5-1",
    "lpeg == 1.1.0-2"
  },

  test = {
    cflags = { "-g3" },
    ldflags = { "-g3" },
    dependencies = {
      "luacov == 0.15.0-1",
    }
  },

}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  type = "lib",
  env = env,
}
