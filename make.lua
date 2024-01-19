return {
  type = "lib",
  env = {

    name = "tbhss",
    version = "0.0.1-1",
    variable_prefix = "TBHSS",

    dependencies = {
      "lua == 5.1"
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
}
