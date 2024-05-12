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
local bitmap = require("santoku.bitmap")
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local cjson = require("cjson")
local sqlite = require("lsqlite3")
local open = sqlite.open

return function (db_file)

  local db = sql(open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")

  -- luacheck: push ignore
  migrate(db, <%
    return serialize(tabulate(map(function (fp)
      return basename(fp), readfile(fp)
    end, files("res/migrations")))), false
  %>)
  -- luacheck: pop

  local M = { db = db }

  M.add_words_model = db.inserter([[
    insert into words_model (name, dimensions)
    values (?, ?)
  ]])

  M.add_sentences_model = db.inserter([[
    insert into sentences_model (name)
    values (?)
  ]])

  M.add_clusters_model = db.inserter([[
    insert into clusters_model (name, id_words_model, clusters)
    values (?, ?, ?)
  ]])

  local encode_bitmaps_model = function (inserter)
    return function (n, i, p)
      return inserter(n, i, cjson.encode(p))
    end
  end

  local decode_bitmaps_model = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.params then
        model.params = cjson.decode(model.params)
        return model
      end
    end
  end

  local encode_encoder_model = function (inserter)
    return function (n, e, p)
      return inserter(n, e, cjson.encode(p))
    end
  end

  local decode_encoder_model = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.params then
        model.params = cjson.decode(model.params)
        return model
      end
    end
  end

  local decode_encoder = function (getter)
    return function (...)
      local model = getter(...)
      -- TODO: read directly from sqlite without temporary file
      local fp = fs.tmpname()
      fs.writefile(fp, model)
      local t = tm.load(fp)
      fs.rm(fp)
      return t
    end
  end

  M.add_bitmaps_model = encode_bitmaps_model(db.inserter([[
    insert into bitmaps_model (name, id_clusters_model, params)
    values (?, ?, ?)
  ]]))

  M.add_encoder_model = encode_encoder_model(db.inserter([[
    insert into encoder_model (name, id_bitmaps_model, params)
    values (?, ?, ?)
  ]]))

  M.set_words_loaded = db.runner([[
    update words_model
    set loaded = true
    where id = ?
  ]])

  M.set_sentences_loaded = db.runner([[
    update sentences_model
    set loaded = true
    where id = ?
  ]])

  M.set_encoder_trained = db.runner([[
    update encoder_model
    set trained = true, model = ?2
    where id = ?1
  ]])

  M.get_encoder = decode_encoder(db.getter([[
    select model from encoder_model where id = ?1
  ]], "model"))

  M.set_words_clustered = db.runner([[
    update clusters_model
    set clustered = true,
        iterations = ?2
    where id = ?1
  ]])

  M.set_bitmaps_created = db.runner([[
    update bitmaps_model
    set created = true
    where id = ?
  ]])

  M.get_words_model_by_name = db.getter([[
    select *
    from words_model
    where name = ?
  ]])

  M.get_sentences_model_by_name = db.getter([[
    select *
    from sentences_model
    where name = ?
  ]])

  M.get_clusters_model_by_name = db.getter([[
    select *
    from clusters_model
    where name = ?
  ]])

  M.get_bitmaps_model_by_name = decode_bitmaps_model(db.getter([[
    select *
    from bitmaps_model
    where name = ?
  ]]))

  M.get_encoder_model_by_name = decode_encoder_model(db.getter([[
    select *
    from encoder_model
    where name = ?
  ]]))

  M.get_words_model_by_id = db.getter([[
    select *
    from words_model
    where id = ?
  ]])

  M.get_sentences_model_by_id = db.getter([[
    select *
    from sentences_model
    where id = ?
  ]])

  M.get_clusters_model_by_id = db.getter([[
    select *
    from clusters_model
    where id = ?
  ]])

  M.get_bitmaps_model_by_id = decode_bitmaps_model(db.getter([[
    select *
    from bitmaps_model
    where id = ?
  ]]))

  M.get_encoder_model_by_id = decode_encoder_model(db.getter([[
    select *
    from encoder_model
    where id = ?
  ]]))

  M.add_word = db.inserter([[
    insert into words (id, id_words_model, name, embedding)
    values (?, ?, ?, ?)
  ]])

  M.add_sentence = db.inserter([[
    insert into sentences (id, id_sentences_model, label, a, b)
    values (?, ?, ?, ?, ?)
  ]])

  M.add_bitmap = db.inserter([[
    insert into bitmaps (id_bitmaps_model, id_words, bitmap)
    values (?, ?, ?)
  ]])

  M.set_word_cluster_similarity = db.inserter([[
    insert into clusters (id_clusters_model, id_words, id, similarity)
    values (?, ?, ?, ?)
  ]])

  M.get_words = db.iter([[
    select id, name, embedding from words
    where id_words_model = ?
    order by id asc
  ]])

  M.get_total_words = db.getter([[
    select count(*) as n
    from words
    where id_words_model = ?
  ]], "n")

  M.get_word_name = db.getter([[
    select name from words
    where id_words_model = ?1
    and id = ?2
  ]], "name")

  M.get_word_embedding = db.getter([[
    select embedding from words
    where id_words_model = ?1
    and id = ?2
  ]], "embedding")

  M.get_clusters = db.iter([[
    select c.id_words, c.id, c.similarity
    from clusters c
    where c.id_clusters_model = ?
  ]])

  M.delete_words_model_by_name = db.runner([[
    delete from words_model
    where name = ?
  ]])

  M.delete_clusters_model_by_name = db.runner([[
    delete from clusters_model
    where name = ?
  ]])

  M.get_bitmap = db.getter([[
    select b.bitmap
    from bitmaps_model bm, clusters_model cm, bitmaps b, words e
    where bm.id = ?1
    and e.name = ?2
    and e.id_words_model = cm.id_words_model
    and cm.id = bm.id_clusters_model
    and b.id_bitmaps_model = bm.id
    and b.id_words = e.id
  ]], "bitmap")

  M.get_nearest_clusters_by_id = db.iter([[
    select id from (
      select id from clusters
      where id_clusters_model = ?1
      and id_words = ?2
      order by similarity desc
      limit ?3
    )
    union
    select id from (
      select id from clusters
      where id_clusters_model = ?1
      and id_words = ?2
      and similarity >= ?5
      order by similarity desc
      limit ?4 - ?3 offset ?3
    )
  ]])

  M.get_nearest_clusters_by_word = db.iter([[
    with e as (
      select e.id
      from words e, clusters_model cm
      where e.name = ?2
      and e.id_words_model = cm.id_words_model
      and cm.id = ?1
    )
    select * from (
      select id from (
        select c.id from e, clusters c
        where c.id_clusters_model = ?1
        and c.id_words = e.id
        order by c.similarity desc
        limit ?3
      )
      union
      select id from (
        select c.id from e, clusters c
        where c.id_clusters_model = ?1
        and c.id_words = e.id
        and c.similarity >= ?5
        order by c.similarity desc
        limit ?4 - ?3 offset ?3
      )
    )
  ]])

  M.get_sentence_triplets = db.iter([[
    select
      a.a as anchor,
      b.b as positive,
      c.b as negative
    from sentences a
    inner join sentences b on a.a = b.a and b.label = 'entailment'
    inner join sentences c on a.a = c.a and c.label in ('contradiction', 'neutral')
    where a.id_sentences_model = ?
  ]])

  return M

end
