local sqlite = require("santoku.sqlite")
local migrate = require("santoku.sqlite.migrate")
local err = require("santoku.err")

return function (db_file)
  return err.pwrap(function (check)

    local db = check(sqlite.open(db_file))

    check(db:exec("pragma journal_mode = WAL"))
    check(db:exec("pragma synchronous = NORMAL"))

    check(migrate.migrate(db, <%
      local fs = require("santoku.fs")
      local str = require("santoku.string")
      local serialize = require("santoku.serialize")
      return serialize(fs.files("res/migrations")
        :map(check)
        :map(function (fp)
          template.deps:append(fp)
          return fs.basename(fp), check(fs.readfile(fp))
        end)
        :tabulate()), { prefix = false }
    %>)) -- luacheck: ignore

    local M = { db = db }

    M.add_model = check(db:inserter([[
      insert into models (tag, dimensions)
      values (?, ?)
    ]]))

    M.add_clustering = check(db:inserter([[
      insert into clusterings (id_model, clusters)
      values (?, ?)
    ]]))

    M.set_words_loaded = check(db:runner([[
      update models
      set words_loaded = true
      where id = ?
    ]]))

    M.set_words_clustered = check(db:runner([[
      update clusterings
      set words_clustered = true,
          iterations = ?2
      where id = ?1
    ]]))

    M.get_model_by_tag = check(db:getter([[
      select *
      from models
      where tag = ?
    ]]))

    M.get_model_by_id = check(db:getter([[
      select *
      from models
      where id = ?
    ]]))

    M.get_clustering = check(db:getter([[
      select *
      from clusterings
      where id_model = ?
      and clusters = ?
    ]]))

    M.add_word = check(db:inserter([[
      insert into words (id_model, name, id, vector)
      values (?, ?, ?, ?)
    ]]))

    M.set_word_cluster_similarity = check(db:inserter([[
      insert into clusters (id_clustering, id_word, id_cluster, similarity)
      values (?, ?, ?, ?)
    ]]))

    M.get_words = check(db:iter([[
      select id, name, vector from words
      where id_model = ?
      order by id asc
    ]]))

    M.get_total_words = check(db:getter([[
      select count(*) as n
      from words
      where id_model = ?
    ]], "n"))

    M.get_word_clusters = check(db:iter([[
      select w.name, w.id, c.id_cluster, c.similarity
      from models m, words w, clusters c
      where m.tag = ?
      and w.id_model = m.id
      and c.id_word = w.id
    ]]))

    M.delete_model_by_tag = check(db:runner([[
      delete from models
      where tag = ?
    ]]))

    return M

  end)
end
