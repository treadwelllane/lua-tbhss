select c.id, json_group_array(w.word) words
from clusters c, words w
where c.id_words = w.id
and c.id_clusters_model = ?1
group by c.id
order by json_array_length(words) desc;

select max(id) from clusters where id_clusters_model = ?1;

select id, count(id_words) n
from clusters
where id_clusters_model = ?1
group by id
order by n asc;

with sel as (
  select c.id, c.id_clusters_model, cm.id_words_model
  from clusters c, words w, clusters_model cm
  where w.word = ?2 and w.id = c.id_words
  and cm.id = c.id_clusters_model
  and cm.id = ?1 and cm.id_words_model = cm.id_words_model
  order by c.similarity
)
select w.word, c.id, c.similarity
from clusters c, words w, sel s
where s.id = c.id and c.id_words = w.id
and w.id_words_model = s.id_words_model and c.id_clusters_model = s.id_clusters_model
order by c.similarity;

with sel as (
  select c.id, c.id_clusters_model, cm.id_words_model
  from clusters c, words w, clusters_model cm
  where c.id = ?2 and w.id = c.id_words
  and cm.id = c.id_clusters_model
  and cm.id = ?1 and cm.id_words_model = cm.id_words_model
  order by c.similarity
)
select distinct w.word, c.id, c.similarity
from clusters c, words w, sel s
where s.id = c.id and c.id_words = w.id
and w.id_words_model = s.id_words_model and c.id_clusters_model = s.id_clusters_model
order by c.similarity;
