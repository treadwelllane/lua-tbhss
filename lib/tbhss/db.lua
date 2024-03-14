<%
    fs = require("santoku.fs")
    it = require("santoku.iter")
    serialize = require("santoku.serialize")
%>

local sql = require("santoku.sqlite")
local sqlite = require("lsqlite3")
local tbl = require("santoku.table")

local migrate = require("santoku.sqlite.migrate")

return function (db_file)

  local db = sql(sqlite.open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")

  -- luacheck: push ignore
  migrate(db, <%
    return serialize(it.tabulate(it.map(function (fp)
      return fs.basename(fp), fs.readfile(fp)
    end, fs.files("res/migrations")))), false
  %>)
  -- luacheck: pop

  return tbl.merge({

    add_model = db.inserter([[
      insert into models (tag, dimensions)
      values (?, ?)
    ]]),

    add_clustering = db.inserter([[
      insert into clusterings (id_model, clusters)
      values (?, ?)
    ]]),

    set_words_loaded = db.runner([[
      update models
      set words_loaded = true
      where id = ?
    ]]),

    set_words_clustered = db.runner([[
      update clusterings
      set words_clustered = true,
          iterations = ?2
      where id = ?1
    ]]),

    get_model_by_tag = db.getter([[
      select *
      from models
      where tag = ?
    ]]),

    get_model_by_id = db.getter([[
      select *
      from models
      where id = ?
    ]]),

    get_clustering = db.getter([[
      select *
      from clusterings
      where id_model = ?
      and clusters = ?
    ]]),

    add_word = db.inserter([[
      insert into words (id_model, name, id, vector)
      values (?, ?, ?, ?)
    ]]),

    set_word_cluster_similarity = db.inserter([[
      insert into clusters (id_clustering, id_word, id_cluster, similarity)
      values (?, ?, ?, ?)
    ]]),

    get_words = db.iter([[
      select id, name, vector from words
      where id_model = ?
      order by id asc
    ]]),

    get_total_words = db.getter([[
      select count(*) as n
      from words
      where id_model = ?
    ]], "n"),

    get_word_clusters = db.iter([[
      select c.id_word, c.id_cluster, c.similarity
      from clusters c
      where c.id_clustering = ?
    ]]),

    delete_model_by_tag = db.runner([[
      delete from models
      where tag = ?
    ]]),

  }, db)
end
