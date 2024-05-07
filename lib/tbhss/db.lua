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

  M.add_embeddings_model = db.inserter([[
    insert into embeddings_model (name, dimensions)
    values (?, ?)
  ]])

  M.add_clusters_model = db.inserter([[
    insert into clusters_model (name, id_embeddings_model, clusters)
    values (?, ?, ?)
  ]])

  local encode_bitmaps_model = function (inserter)
    return function (n, t, r, p)
      return inserter(n, t, r, cjson.encode(p))
    end
  end

  local decode_bitmaps_model = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.model_params then
        model.model_params = cjson.decode(model.model_params)
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
    insert into bitmaps_model (name, model_type, model_ref, model_params)
    values (?, ?, ?, ?)
  ]]))

  M.add_encoder_model = encode_encoder_model(db.inserter([[
    insert into encoder_model (name, id_embeddings_model, params)
    values (?, ?, ?)
  ]]))

  M.set_embeddings_loaded = db.runner([[
    update embeddings_model
    set loaded = true
    where id = ?
  ]])

  M.set_encoder_created = db.runner([[
    update encoder_model
    set created = true, model = ?2
    where id = ?1
  ]])

  M.get_encoder = decode_encoder(db.getter([[
    select model from encoder_model where id = ?1
  ]], "model"))

  M.set_embeddings_clustered = db.runner([[
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

  M.get_embeddings_model_by_name = db.getter([[
    select *
    from embeddings_model
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

  M.get_embeddings_model_by_id = db.getter([[
    select *
    from embeddings_model
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

  M.add_embedding = db.inserter([[
    insert into embeddings (id_embeddings_model, id, name, embedding)
    values (?, ?, ?, ?)
  ]])

  M.add_bitmap = db.inserter([[
    insert into bitmaps (id_bitmaps_model, id_embedding, bitmap)
    values (?, ?, ?)
  ]])

  M.set_embedding_cluster_similarity = db.inserter([[
    insert into clusters (id_clusters_model, id_embedding, id, similarity)
    values (?, ?, ?, ?)
  ]])

  M.get_embeddings = db.iter([[
    select id, name, embedding from embeddings
    where id_embeddings_model = ?
    order by id asc
  ]])

  M.get_total_embeddings = db.getter([[
    select count(*) as n
    from embeddings
    where id_embeddings_model = ?
  ]], "n")

  M.get_embedding_name = db.getter([[
    select name from embeddings
    where id_embeddings_model = ?1
    and id = ?2
  ]], "name")

  M.get_embedding = db.getter([[
    select embedding from embeddings
    where id_embeddings_model = ?1
    and id = ?2
  ]], "embedding")

  M.get_clusters = db.iter([[
    select c.id_embedding, c.id, c.similarity
    from clusters c
    where c.id_clusters_model = ?
  ]])

  M.delete_embeddings_model_by_name = db.runner([[
    delete from embeddings_model
    where name = ?
  ]])

  M.delete_clusters_model_by_name = db.runner([[
    delete from clusters_model
    where name = ?
  ]])

  local get_bitmap_clustered = db.getter([[
    select b.bitmap, cm.clusters
    from bitmaps_model bm, clusters_model cm, bitmaps b, embeddings e
    where bm.id = ?1
    and e.name = ?2
    and e.id_embeddings_model = cm.id_embeddings_model
    and cm.id = bm.model_ref
    and b.id_bitmaps_model = bm.id
    and b.id_embedding = e.id
  ]])

  M.get_bitmap_clustered = function (...)
    local rec = get_bitmap_clustered(...)
    return bitmap.from_raw(rec.bitmap, rec.clusters)
  end

  local get_bitmap_encoded = db.getter([[
    select b.bitmap, json_extract(em.params, '$.bits') as bits
    from bitmaps_model bm, encoder_model em, bitmaps b, embeddings e
    where bm.id = ?1
    and e.name = ?2
    and em.id = bm.model_ref
    and e.id_embeddings_model = em.id_embeddings_model
    and b.id_bitmaps_model = bm.id
    and b.id_embedding = e.id
  ]])

  M.get_bitmap_encoded = function (...)
    local rec = get_bitmap_encoded(...)
    return bitmap.from_raw(rec.bitmap, rec.bits)
  end

  M.get_nearest_clusters_by_id = db.iter([[
    select id from (
      select id from clusters
      where id_clusters_model = ?1
      and id_embedding = ?2
      order by similarity desc
      limit ?3
    )
    union
    select id from (
      select id from clusters
      where id_clusters_model = ?1
      and id_embedding = ?2
      and similarity >= ?5
      order by similarity desc
      limit ?4 - ?3 offset ?3
    )
  ]])

  M.get_nearest_clusters_by_word = db.iter([[
    with e as (
      select e.id
      from embeddings e, clusters_model cm
      where e.name = ?2
      and e.id_embeddings_model = cm.id_embeddings_model
      and cm.id = ?1
    )
    select * from (
      select id from (
        select c.id from e, clusters c
        where c.id_clusters_model = ?1
        and c.id_embedding = e.id
        order by c.similarity desc
        limit ?3
      )
      union
      select id from (
        select c.id from e, clusters c
        where c.id_clusters_model = ?1
        and c.id_embedding = e.id
        and c.similarity >= ?5
        order by c.similarity desc
        limit ?4 - ?3 offset ?3
      )
    )
  ]])

  return M

end
