
SET client_encoding = 'SQL_ASCII';
SET check_function_bodies = false;

SET search_path = @@SCHEMA@@, pg_catalog;

ALTER TABLE ONLY @@SCHEMA@@.bayes_cache DROP CONSTRAINT "$1";
ALTER TABLE ONLY @@SCHEMA@@.chan_attrs DROP CONSTRAINT catt_chan_ref;
ALTER TABLE ONLY @@SCHEMA@@.chan_icons DROP CONSTRAINT chan_icon_chan_ref;
ALTER TABLE ONLY @@SCHEMA@@.patt_icons DROP CONSTRAINT patt_icon_patt_ref;
ALTER TABLE ONLY @@SCHEMA@@.prg_attrs DROP CONSTRAINT patt_prg_ref;
ALTER TABLE ONLY @@SCHEMA@@.prg_icons DROP CONSTRAINT prg_icon_prg_ref;
ALTER TABLE ONLY @@SCHEMA@@.programmes DROP CONSTRAINT prg_chan_ref;
ALTER TABLE ONLY @@SCHEMA@@.bayes_cache DROP CONSTRAINT bayes_cache_pkey;
ALTER TABLE ONLY @@SCHEMA@@.prg_attrs DROP CONSTRAINT prg_attrs_pkey;
ALTER TABLE ONLY @@SCHEMA@@.programmes DROP CONSTRAINT programmes_pkey;
ALTER TABLE ONLY @@SCHEMA@@.icons DROP CONSTRAINT icons_pkey;
ALTER TABLE ONLY @@SCHEMA@@.chan_attrs DROP CONSTRAINT channel_attrs_pkey;
ALTER TABLE ONLY @@SCHEMA@@.channels DROP CONSTRAINT channels_chan_id_key;
ALTER TABLE ONLY @@SCHEMA@@.channels DROP CONSTRAINT channels_pkey;
DROP INDEX @@SCHEMA@@.ix_tspmv;
DROP INDEX @@SCHEMA@@.ix_tsmv;
DROP INDEX @@SCHEMA@@.ix_catt_search;
DROP INDEX @@SCHEMA@@.ix_catt_best_name;
DROP INDEX @@SCHEMA@@.ix_patt_search;
DROP INDEX @@SCHEMA@@.ix_cicons_chan_oid;
DROP INDEX @@SCHEMA@@.ix_prg_start_stop;
DROP FUNCTION @@SCHEMA@@.shows_grid_then(timestamp with time zone);
DROP VIEW @@SCHEMA@@.chan_quality;
DROP VIEW @@SCHEMA@@.shows_grid;
DROP VIEW @@SCHEMA@@.shows;
DROP VIEW @@SCHEMA@@.prg_long_title;
DROP VIEW @@SCHEMA@@.tok_stats;
DROP VIEW @@SCHEMA@@.tok_sum_pint;
DROP VIEW @@SCHEMA@@.tok_counts_full;
DROP VIEW @@SCHEMA@@.tok_counts_pint;
DROP VIEW @@SCHEMA@@.tok_counts_val;
DROP VIEW @@SCHEMA@@.tok_counts_val_pint;
DROP FUNCTION @@SCHEMA@@.update_bayes_stats();
DROP TABLE @@SCHEMA@@.tok_sum_pint_mv;
DROP FUNCTION @@SCHEMA@@.compute_bayes_class(bigint);
DROP FUNCTION @@SCHEMA@@.compute_bayes_class_all(bigint);
DROP TABLE @@SCHEMA@@.bayes_cache;
DROP VIEW @@SCHEMA@@.prgs_now;
DROP FUNCTION @@SCHEMA@@.blk_endx(timestamp with time zone, timestamp with time zone);
DROP TABLE @@SCHEMA@@.tok_stats_mv;
DROP FUNCTION @@SCHEMA@@.max(anyelement, anyelement);
DROP FUNCTION @@SCHEMA@@.min(anyelement, anyelement);
DROP FUNCTION @@SCHEMA@@.bayes_learn_prg(bigint, character varying, character varying);
DROP FUNCTION @@SCHEMA@@.get_prg_toks(bigint, character varying, character varying);
DROP FUNCTION @@SCHEMA@@.get_bayes_class(bigint);
DROP TABLE @@SCHEMA@@.tok_counts_full_mv;
DROP TABLE @@SCHEMA@@.tok_counts_pint_mv;
DROP TABLE @@SCHEMA@@.tok_counts_val_mv;
DROP TABLE @@SCHEMA@@.tok_counts_val_pint_mv;
DROP FUNCTION @@SCHEMA@@.tokenizer(text);
DROP AGGREGATE @@SCHEMA@@.product(double precision);
DROP FUNCTION @@SCHEMA@@.agg_prod_next(double precision, double precision);
DROP FUNCTION @@SCHEMA@@.prg_attrs_then(timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.prgs_then(timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.blk_startx(timestamp with time zone, timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.grid_endx(timestamp with time zone);
DROP VIEW @@SCHEMA@@.chan_best_name;
DROP TABLE @@SCHEMA@@.patt_icons;
DROP TABLE @@SCHEMA@@.prg_attrs;
DROP TABLE @@SCHEMA@@.prg_icons;
DROP TABLE @@SCHEMA@@.programmes;
DROP TABLE @@SCHEMA@@.chan_icons;
DROP TABLE @@SCHEMA@@.icons;
DROP TABLE @@SCHEMA@@.chan_attrs;
DROP TABLE @@SCHEMA@@.channels;
DROP FUNCTION @@SCHEMA@@.blk_end(timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.blk_start(timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.roundup_5min(timestamp with time zone);
DROP FUNCTION @@SCHEMA@@.grid_end();
DROP FUNCTION @@SCHEMA@@.now_5min();
DROP FUNCTION @@SCHEMA@@.round_5min(timestamp with time zone);
DROP AGGREGATE @@SCHEMA@@.longest(character varying);
DROP FUNCTION @@SCHEMA@@.longer(character varying, character varying);

