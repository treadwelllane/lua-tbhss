<%
    fs = require("santoku.fs")
    files = fs.files
    basename = fs.basename

    iter = require("santoku.iter")
    tabulate = iter.tabulate
    map = iter.map

    serialize = require("santoku.serialize")
%>

local sql = require("santoku.sqlite")
local sqlite = require("lsqlite3")
local open = sqlite.open

local migrate = require("santoku.sqlite.migrate")

return function (db_file)

  local db = sql(open(db_file))
  local exec = db.exec
  local inserter = db.inserter
  local runner = db.runner
  local getter = db.getter
  local iter = db.iter
  local begin = db.begin
  local commit = db.commit
  local rollback = db.rollback

  exec("pragma journal_mode = WAL")
  exec("pragma synchronous = NORMAL")

  -- luacheck: push ignore
  migrate(db, <%
    return serialize(tabulate(map(function (fp)
      return basename(fp), readfile(fp)
    end, files("res/migrations")))), false
  %>)
  -- luacheck: pop

  return {

    begin = begin,
    commit = commit,
    rollback = rollback,

    add_model = inserter([[
      insert into models (tag, dimensions)
      values (?, ?)
    ]]),

    add_clustering = inserter([[
      insert into clusterings (id_model, clusters)
      values (?, ?)
    ]]),

    set_words_loaded = runner([[
      update models
      set words_loaded = true
      where id = ?
    ]]),

    set_words_clustered = runner([[
      update clusterings
      set words_clustered = true,
          iterations = ?2
      where id = ?1
    ]]),

    get_model_by_tag = getter([[
      select *
      from models
      where tag = ?
    ]]),

    get_model_by_id = getter([[
      select *
      from models
      where id = ?
    ]]),

    get_clustering = getter([[
      select *
      from clusterings
      where id_model = ?
      and clusters = ?
    ]]),

    add_word = inserter([[
      insert into words (id_model, name, id, vector)
      values (?, ?, ?, ?)
    ]]),

    set_word_cluster_similarity = inserter([[
      insert into clusters (id_clustering, id_word, id_cluster, similarity)
      values (?, ?, ?, ?)
    ]]),

    get_words = iter([[
      select id, name, vector from words
      where id_model = ?
      order by id asc
    ]]),

    get_total_words = getter([[
      select count(*) as n
      from words
      where id_model = ?
    ]], "n"),

    get_word_clusters = iter([[
      select c.id_word, c.id_cluster, c.similarity
      from clusters c
      where c.id_clustering = ?
    ]]),

    delete_model_by_tag = runner([[
      delete from models
      where tag = ?
    ]]),

  }
end
