local env = {

  name = "tbhss",
  version = "0.0.5-1",
  variable_prefix = "TBHSS",
  public = true,

  dependencies = {
    "lua == 5.1",
    "argparse >= 0.7.1-1",
  },

  test = {
    dependencies = {
      "santoku-test == 0.0.7-1",
      "santoku-fs == 0.0.13-1",
      "inspect == 3.1.3-0",
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
