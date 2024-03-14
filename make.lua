local env = {

  name = "tbhss",
  version = "0.0.21-1",
  variable_prefix = "TBHSS",
  public = true,

  dependencies = {
    "lua == 5.1",
    "argparse >= 0.7.1-1",
    "santoku >= 0.0.203-1",
    "santoku-fs >= 0.0.30-1",
    "santoku-tsetlin >= 0.0.20-1",
    "santoku-bitmap >= 0.0.6-1",
    "santoku-matrix >= 0.0.5-1",
    "santoku-sqlite >= 0.0.13-1",
    "santoku-sqlite-migrate >= 0.0.13-1",
    "lsqlite3 >= 0.9.5-1"
  },

  test = {
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
