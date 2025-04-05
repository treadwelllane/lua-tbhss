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
local migrate = require("santoku.sqlite.migrate")
local varg = require("santoku.varg")
local cjson = require("cjson")
local sqlite = require("lsqlite3")
local open = sqlite.open

return function (db_file, skip_init)

  local db = sql(open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")
  db.exec("pragma busy_timeout = 30000")

  if not skip_init then

    -- luacheck: push ignore
    migrate(db, <%
      return serialize(tabulate(map(function (fp)
        return basename(fp), readfile(fp)
      end, files("res/migrations")))), false
    %>)
    -- luacheck: pop

  end

  local M = { db = db, file = db_file }

  local encode_tables = function (inserter)
    return function (...)
      return inserter(varg.map(function (t)
        if type(t) == "table" then
          return cjson.encode(t)
        else
          return t
        end
      end, ...))
    end
  end

  local decode_args = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.args then
        model.args = cjson.decode(model.args)
        return model
      end
    end
  end

  M.add_words_model = db.inserter([[
    insert into words_model (name, total, dimensions, embeddings)
    values (?1, ?2, ?3, ?4)
  ]])

  M.add_clusters_model = encode_tables(db.inserter([[
    insert into clusters_model (name, id_words_model, args)
    values (?1, ?2, ?3)
  ]]))

  M.add_modeler = db.inserter([[
    insert into modeler (name, visible, hidden, tokenizer, compressor)
    values (?, ?, ?, ?, ?)
  ]])

  M.add_classifier = db.inserter([[
    insert into classifier (name, modeler, labels, classifier)
    values (?, ?, ?, ?)
  ]])

  M.add_encoder = db.inserter([[
    insert into encoder (name, modeler, encoder)
    values (?, ?, ?)
  ]])

  M.get_modeler = db.getter([[
    select * from modeler where name = ?1
  ]])

  M.get_classifier = db.getter([[
    select * from classifier where name = ?1
  ]])

  M.get_encoder = db.getter([[
    select * from encoder where name = ?1
  ]])

  M.set_words_loaded = db.runner([[
    update words_model
    set loaded = true
    where id = ?
  ]])

  M.modeler_exists = db.getter([[
    select 1 from modeler where name = ?1
  ]])

  M.classifier_exists = db.getter([[
    select 1 from classifier where name = ?1
  ]])

  M.encoder_exists = db.getter([[
    select 1 from encoder where name = ?1
  ]])

  M.set_words_clustered = db.runner([[
    update clusters_model
    set clustered = true
    where id = ?1
  ]])

  M.get_words_model_by_name = db.getter([[
    select id, name, loaded, total, dimensions
    from words_model
    where name = ?
  ]])

  M.get_word_embeddings = db.getter([[
    select embeddings
    from words_model
    where id = ?1
  ]], "embeddings")

  M.get_clusters_model_by_name = decode_args(db.getter([[
    select *
    from clusters_model
    where name = ?
  ]]))

  M.get_words_model_by_id = db.getter([[
    select id, name, loaded, total, dimensions
    from words_model
    where id = ?
  ]])

  M.get_clusters_model_by_id = decode_args(db.getter([[
    select *
    from clusters_model
    where id = ?
  ]]))

  M.set_word_cluster_similarity = db.inserter([[
    insert into clusters (id_clusters_model, id_words, id, similarity)
    values (?, ?, ?, ?)
  ]])

  M.get_word_id = db.getter([[
    select id from words
    where id_words_model = ?1
    and word = ?2
  ]], "id")

  M.add_word = db.inserter([[
    insert into words (id, id_words_model, word)
    values (?, ?, ?)
    on conflict (id_words_model, word) do nothing
  ]])

  return M

end
