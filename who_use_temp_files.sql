SELECT
        pg_stat_activity.pid AS pid,
        datname AS database,
        pg_stat_activity.client_addr AS client,
        EXTRACT(epoch FROM (NOW() - pg_stat_activity.query_start)) AS duration,
        pg_stat_activity.usename AS user,
        pg_stat_activity.state AS state,
        pg_size_pretty(pg_temp_files.sum) as temp_file_size, pg_temp_files.count as temp_file_num
    FROM
        pg_stat_activity AS pg_stat_activity
INNER JOIN
(
SELECT unnest(regexp_matches(agg.tmpfile, 'pgsql_tmp([0-9]*)')) AS pid,
       SUM((pg_stat_file(agg.dir||'/'||agg.tmpfile)).size),
       count(*)
FROM
  (SELECT ls.oid,
          ls.spcname,
          ls.dir||'/'||ls.sub AS dir,
          CASE gs.i
              WHEN 1 THEN ''
              ELSE pg_ls_dir(dir||'/'||ls.sub)
          END AS tmpfile
   FROM
     (SELECT sr.oid,
             sr.spcname,
             'pg_tblspc/'||sr.oid||'/'||sr.spc_root AS dir,
             pg_ls_dir('pg_tblspc/'||sr.oid||'/'||sr.spc_root) AS sub
      FROM
        (SELECT spc.oid,
                spc.spcname,
                pg_ls_dir('pg_tblspc/'||spc.oid) AS spc_root,
                trim(TRAILING E'\n '
                     FROM pg_read_file('PG_VERSION')) AS v
         FROM
           (SELECT oid,
                   spcname
            FROM pg_tablespace
            WHERE spcname !~ '^pg_') AS spc) sr
      WHERE sr.spc_root ~ ('^PG_'||sr.v)
        UNION ALL
        SELECT 0,
               'pg_default',
               'base' AS dir,
               'pgsql_tmp' AS sub
        FROM pg_ls_dir('base') AS l WHERE l='pgsql_tmp' ) AS ls,

     (SELECT generate_series(1,2) AS i) AS gs
   WHERE ls.sub = 'pgsql_tmp') agg
GROUP BY 1
) as pg_temp_files on (pg_stat_activity.pid = pg_temp_files.pid::int)
WHERE
        pg_stat_activity.pid <> pg_backend_pid()
ORDER BY
        EXTRACT(epoch FROM (NOW() - pg_stat_activity.query_start)) DESC;
