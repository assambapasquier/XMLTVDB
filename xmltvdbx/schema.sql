
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;
CREATE SCHEMA @@SCHEMA@@;
SET search_path = @@SCHEMA@@, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;
CREATE TABLE bayes_cache (
    prg_oid bigint NOT NULL,
    prg_title text NOT NULL,
    pint_class character varying(1024) NOT NULL,
    bayes_prob double precision NOT NULL,
    lastupdate timestamp with time zone DEFAULT now() NOT NULL,
    num_toks bigint NOT NULL
);

COMMENT ON TABLE bayes_cache IS 'cache for computed bayseian classification';

CREATE TABLE bayes_toks (
    prg_oid bigint,
    prg_title text,
    tok_src character(1) NOT NULL,
    tok_name character varying(50) NOT NULL,
    tok_subname character varying(50) NOT NULL,
    tok_value text NOT NULL,
    pint_class character varying(1024) NOT NULL,
    CONSTRAINT bayes_toks_tok_src CHECK (((tok_src = 'p'::bpchar) OR (tok_src = 'c'::bpchar)))
);

COMMENT ON TABLE bayes_toks IS 'full token data for bayes learning';

COMMENT ON COLUMN bayes_toks.tok_value IS 'token value, not att value';

CREATE TABLE chan_attrs (
    catt_oid bigint NOT NULL,
    chan_oid bigint NOT NULL,
    catt_name character varying(50) NOT NULL,
    catt_value text NOT NULL
);

COMMENT ON TABLE chan_attrs IS 'channel attributes';

CREATE VIEW chan_best_name AS
    SELECT chan_attrs.chan_oid, ("substring"(chan_attrs.catt_value, '^\\d+'::text))::integer AS chan_number, "substring"(chan_attrs.catt_value, '^\\d+ (.*)$'::text) AS chan_name FROM chan_attrs WHERE ((chan_attrs.catt_name)::text = '_number_name'::text);

COMMENT ON VIEW chan_best_name IS 'Best name for a channel to present to user';

CREATE TABLE channels (
    chan_oid bigint NOT NULL,
    chan_id character varying(1024) NOT NULL
);

COMMENT ON TABLE channels IS 'channels (mostly just ids)';

CREATE VIEW chan_detail AS
    SELECT c.chan_oid, c.chan_id, ("substring"(ca.catt_value, '^\\d+'::text))::integer AS chan_number, "substring"(ca.catt_value, '^\\d+ (.*)$'::text) AS chan_name FROM (channels c NATURAL JOIN chan_attrs ca) WHERE ((ca.catt_name)::text = '_number_name'::text);

COMMENT ON VIEW chan_detail IS 'combo of channels and chan_best_name';

CREATE TABLE icons (
    icn_oid bigint NOT NULL,
    icn_src character varying(1024) NOT NULL,
    icn_width integer,
    icn_height integer
);

COMMENT ON TABLE icons IS 'base icons table from which other tables inherit';

CREATE SEQUENCE icons_icn_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE icons_icn_oid_seq OWNED BY icons.icn_oid;

CREATE TABLE chan_icons (
    icn_oid bigint,
    icn_src character varying(1024),
    icn_width integer,
    icn_height integer,
    chan_oid bigint NOT NULL
)
INHERITS (icons);

COMMENT ON TABLE chan_icons IS 'channel icons';

CREATE TABLE cv_interest (
    pint_class character varying(1024) NOT NULL,
    pint_order integer DEFAULT 2147483647 NOT NULL,
    weight integer,
    CONSTRAINT cv_pint_class_chk CHECK (((pint_class)::text ~ '^[a-z]+$'::text))
);

COMMENT ON TABLE cv_interest IS 'controlled vocabulary for programme interest classification';

CREATE TABLE prg_attrs (
    patt_oid bigint NOT NULL,
    prg_oid bigint NOT NULL,
    patt_name character varying(50) NOT NULL,
    patt_subname character varying(50),
    patt_lang character varying(2),
    patt_value text NOT NULL
);

COMMENT ON TABLE prg_attrs IS 'programme attributes';

CREATE TABLE prg_interest (
    prg_title text NOT NULL,
    pint_class character varying(1024) NOT NULL
);

COMMENT ON TABLE prg_interest IS 'programme interest classification
(by programme title)';

CREATE TABLE programmes (
    prg_oid bigint NOT NULL,
    prg_start timestamp with time zone NOT NULL,
    prg_stop timestamp with time zone,
    chan_oid bigint NOT NULL
);

COMMENT ON TABLE programmes IS 'programmes
(most info is actually in prg_attrs)';

CREATE VIEW shows AS
    SELECT programmes.prg_oid, programmes.prg_start, programmes.prg_stop, prg_attrs.patt_value AS prg_title, programmes.chan_oid, chan_best_name.chan_number, chan_best_name.chan_name FROM (((programmes NATURAL JOIN channels) NATURAL JOIN chan_best_name) NATURAL JOIN prg_attrs) WHERE ((prg_attrs.patt_name)::text = 'title'::text);

COMMENT ON VIEW shows IS 'Shows - program with title and channel info';

CREATE VIEW chan_quality AS
    SELECT cq.chan_name, cq.pint_class, cq.totaltime, (cq.totaltime * (cv_interest.weight)::double precision) AS weightedtime FROM ((SELECT shows.chan_name, COALESCE(prg_interest.pint_class, 'normal'::character varying) AS pint_class, sum((shows.prg_stop - shows.prg_start)) AS totaltime FROM (shows NATURAL LEFT JOIN prg_interest) GROUP BY shows.chan_name, COALESCE(prg_interest.pint_class, 'normal'::character varying)) cq NATURAL JOIN cv_interest) ORDER BY cq.chan_name, cq.pint_class;

COMMENT ON VIEW chan_quality IS 'Attempts to estimate the overall quality of a channel by tallying the ratings of the shows it airs';

CREATE DOMAIN imdb_id_number AS character(7)
	CONSTRAINT imdb_id_number_check CHECK ((VALUE ~ similar_escape('^[0-9]*$'::text, NULL::text)));

CREATE TABLE imdb_ids (
    imdb_id_oid bigint NOT NULL,
    patt_name character varying(50) NOT NULL,
    patt_subname character varying(50) NOT NULL,
    patt_value text NOT NULL,
    imdb_id imdb_id_number NOT NULL
);

CREATE TABLE pint_count_mv (
    pint_class character varying(1024),
    num_toks bigint
);

CREATE TABLE tok_total_mv (
    num_toks bigint
);

CREATE VIEW p_pint AS
    SELECT p.pint_class, log(((p.num_toks)::double precision / (t.num_toks)::double precision)) AS prb_pint FROM pint_count_mv p, tok_total_mv t;

CREATE TABLE p_pint_mv (
    pint_class character varying(1024),
    prb_pint double precision
);

CREATE TABLE tok_count_by_pint_mv (
    tok_src character(1),
    tok_name character varying(50),
    tok_subname character varying,
    tok_value text,
    pint_class character varying(1024),
    num_prgs bigint
);

CREATE VIEW p_tok_given_pint AS
    SELECT tok_count_by_pint_mv.tok_src, tok_count_by_pint_mv.tok_name, tok_count_by_pint_mv.tok_subname, tok_count_by_pint_mv.tok_value, tok_count_by_pint_mv.pint_class, log(((tok_count_by_pint_mv.num_prgs)::double precision / (pint_count_mv.num_toks)::double precision)) AS prb_tok_given_pint FROM (tok_count_by_pint_mv JOIN pint_count_mv USING (pint_class));

CREATE TABLE p_tok_given_pint_mv (
    tok_src character(1),
    tok_name character varying(50),
    tok_subname character varying,
    tok_value text,
    pint_class character varying(1024),
    prb_tok_given_pint double precision
);

CREATE TABLE patt_icons (
    icn_oid bigint,
    icn_src character varying(1024),
    icn_width integer,
    icn_height integer,
    patt_oid bigint NOT NULL
)
INHERITS (icons);

COMMENT ON TABLE patt_icons IS 'icons for programme attributes
(rarely used)';

CREATE VIEW pint_count AS
    SELECT tok_count_by_pint_mv.pint_class, (sum(tok_count_by_pint_mv.num_prgs))::bigint AS num_toks FROM tok_count_by_pint_mv GROUP BY tok_count_by_pint_mv.pint_class;

CREATE TABLE prg_icons (
    icn_oid bigint,
    icn_src character varying(1024),
    icn_width integer,
    icn_height integer,
    prg_oid bigint NOT NULL
)
INHERITS (icons);

COMMENT ON TABLE prg_icons IS 'programme icons
(rarely used)';

CREATE VIEW prgs_now AS
    SELECT programmes.prg_oid, programmes.prg_start, programmes.prg_stop, programmes.chan_oid FROM programmes WHERE ((((programmes.prg_start >= (now() - '08:00:00'::interval)) AND (programmes.prg_start <= now())) AND (programmes.prg_stop > now())) AND (programmes.prg_stop <= (now() + '08:00:00'::interval)));

COMMENT ON VIEW prgs_now IS 'Programmes that are showing right now';

CREATE FUNCTION blk_end(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$select case when $1 > @@SCHEMA@@.grid_end() then @@SCHEMA@@.grid_end() else @@SCHEMA@@.roundup_5min($1) end$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION blk_end(timestamp with time zone) IS 'Returns the ''programming block'' end time - the time rounted to a five minute mark, truncated down to be not more than the grid end for now.';

CREATE FUNCTION blk_start(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$select case when $1 < @@SCHEMA@@.now_5min()
then @@SCHEMA@@.now_5min()
else @@SCHEMA@@.round_5min($1) end$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION blk_start(timestamp with time zone) IS 'Returns the ''programming block'' start for a given time - the time rounded to a five minute mark, shifted forwards to be at least now';

CREATE FUNCTION get_bayes_class(bigint, character varying) RETURNS character varying
    AS $_$DECLARE
	prgoid alias for $1;
	prgtitle alias for $2;
	crow @@SCHEMA@@.bayes_cache%ROWTYPE;
BEGIN
	select into crow * from @@SCHEMA@@.bayes_cache where prg_oid = prgoid;
	if crow.pint_class is not null and now() - crow.lastupdate > '24 hours'::interval then
		delete from @@SCHEMA@@.bayes_cache where prg_oid = prgoid;
		crow.pint_class := null;
	end if;
	if crow.pint_class is null then
		select into crow * from @@SCHEMA@@.compute_bayes_class(prgoid, prgtitle);
		insert into @@SCHEMA@@.bayes_cache (prg_oid, prg_title, pint_class,
				bayes_prob, lastupdate, num_toks)
			values (crow.prg_oid, crow.prg_title, crow.pint_class,
				crow.bayes_prob, crow.lastupdate, crow.num_toks);
	end if;
	return crow.pint_class;
END;
$_$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION get_bayes_class(bigint, character varying) IS 'bayes_class = get_bayes_class(prg_oid) -- fetches bayes classification for a prg_oid, using and maintaining cache';

CREATE VIEW shows_grid AS
    SELECT s.prg_oid, s.prg_start, s.prg_stop, blk_start(s.prg_start) AS blk_start, blk_end(s.prg_stop) AS blk_end, s.prg_title, s.chan_oid, s.chan_number, s.chan_name, pi.pint_class, COALESCE(bc.pint_class, get_bayes_class(s.prg_oid, (s.prg_title)::character varying)) AS bayes_class FROM ((shows s LEFT JOIN bayes_cache bc USING (prg_oid)) LEFT JOIN prg_interest pi ON ((s.prg_title = pi.prg_title))) ORDER BY s.chan_number, s.chan_name, s.prg_start;

COMMENT ON VIEW shows_grid IS 'Shows with grid information added';

CREATE VIEW tok_count_by_pint AS
    SELECT bayes_toks.tok_src, bayes_toks.tok_name, bayes_toks.tok_subname, bayes_toks.tok_value, bayes_toks.pint_class, count(bayes_toks.prg_oid) AS num_prgs FROM bayes_toks GROUP BY bayes_toks.tok_src, bayes_toks.tok_name, bayes_toks.tok_subname, bayes_toks.tok_value, bayes_toks.pint_class;

CREATE VIEW tok_total AS
    SELECT count(*) AS num_toks FROM bayes_toks;

CREATE FUNCTION bayes_learn_prg(bigint, character varying, character varying) RETURNS integer
    AS $_$DECLARE
	prgoid alias for $1;
	prgtitle varchar;
	pintclass alias for $3;
	learnpintclass varchar;
	learnprgtitle varchar;
	rowcount int4;
BEGIN
	if prgoid is null then
		raise exception 'prgoid must not be null';
	end if;
	delete from @@SCHEMA@@.bayes_toks where prg_oid = prgoid;
	if pintclass is null then
		return 0;
	end if;
	prgtitle := coalesce($2, '');
	-- any lookups to do?
	if length(prgtitle) = 0 then
		learnprgtitle := @@SCHEMA@@.get_prg_title(prgoid);
	else
		learnprgtitle := prgtitle;
	end if;
	if length(pintclass) = 0 then
		select into learnpintclass pint_class
			from @@SCHEMA@@.prg_interest
			where prg_title = prgtitle and prg_oid = prgoid;
	else
		learnpintclass := pintclass;
	end if;
	if length(pintclass) > 0 then
		learnpintclass := coalesce(pintclass, '');
	end if;
	if length(learnpintclass) = 0 then
		raise exception 'no auto pint_class found for prg_oid %', prgoid;
	end if;
	if length(learnprgtitle) = 0 then
		raise exception 'no auto prg_title found ofr prg_oid %', prgoid;
	end if;
	insert into @@SCHEMA@@.bayes_toks
		select distinct *
		from @@SCHEMA@@.get_prg_toks(prgoid, learnprgtitle, learnpintclass);
	get diagnostics rowcount = ROW_COUNT;
	PERFORM incr_bayes_update(prgoid);
	return rowcount;
END;
$_$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION bayes_learn_prg(bigint, character varying, character varying) IS 'token_count = bayes_learn_prg(prg_oid, prg_title, pint_class) -- computes and stores bayes tokens for a prg_oid, pint_class, prg_title.
if pint_class is null, unlearns (removes tokens), if it is '''', does a lookup to find it.
if prg title is null or '''', does a lookup to find it.';

CREATE FUNCTION blk_endx(timestamp with time zone, timestamp with time zone) RETURNS timestamp with time zone
    AS $_$select case when $1 > @@SCHEMA@@.grid_endx($2)
then @@SCHEMA@@.grid_endx($2)
else @@SCHEMA@@.roundup_5min($1) end$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION blk_endx(timestamp with time zone, timestamp with time zone) IS 'The programming block end for a time and a grid start';

CREATE FUNCTION blk_startx(timestamp with time zone, timestamp with time zone) RETURNS timestamp with time zone
    AS $_$select case when $1 < @@SCHEMA@@.round_5min($2)
then @@SCHEMA@@.round_5min($2)
else @@SCHEMA@@.round_5min($1) end$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION blk_startx(timestamp with time zone, timestamp with time zone) IS 'The programming block start for a given time and grid start';

CREATE FUNCTION compute_bayes_class(bigint, character varying) RETURNS bayes_cache
    AS $_$select * from @@SCHEMA@@.compute_bayes_class_all($1, $2)
order by bayes_prob desc, num_toks desc
limit 1;
$_$
    LANGUAGE sql STABLE COST 300;

COMMENT ON FUNCTION compute_bayes_class(bigint, character varying) IS 'bayes_cache%rowtype = compute_bayes_cache(prg_oid, prg_title) -- computes the value for the bayes_cache row for a prg_oid';

CREATE FUNCTION compute_bayes_class_all(bigint, character varying) RETURNS SETOF bayes_cache
    AS $_$declare
    prgoid alias for $1;
    prgtitle alias for $2;
    unweighted @@SCHEMA@@.bayes_cache[];
    uwrow @@SCHEMA@@.bayes_cache;
    ppint double precision;
    --ppcount double precision;
    i int4;
    maxcount int4;
    minrank double precision;
begin
    -- can't use the array() constructor with rowtypes
    maxcount := 0;
    minrank := 0;
    for uwrow in select t.prg_oid, t.prg_title, pt.pint_class,
            sum(prb_tok_given_pint) as bayes_prob,
            now() as lastupdate, count(*) as num_toks
        from (select distinct * from @@SCHEMA@@.get_prg_toks($1, $2, '')) t
            join @@SCHEMA@@.p_tok_given_pint_mv pt using (tok_src, tok_name, tok_subname, tok_value)
            group by t.prg_oid, t.prg_title, pt.pint_class
    loop
        unweighted := array_append(unweighted, uwrow);
        if uwrow.num_toks > maxcount then maxcount := uwrow.num_toks; end if;
        if uwrow.bayes_prob < minrank then minrank := uwrow.bayes_prob; end if;
    end loop;
    if unweighted is null or array_lower(unweighted, 1) is null then return; end if;
    for i in array_lower(unweighted, 1) .. array_upper(unweighted, 1)
    loop
        uwrow := unweighted[i];
        select prb_pint into ppint from @@SCHEMA@@.p_pint_mv where pint_class = uwrow.pint_class;
        --select -log(num_toks) into ppcount from @@SCHEMA@@.pint_count_mv where pint_class = uwrow.pint_class;
        -- prb_pint values will be negative
        -- so we downweight pints that din't match many tokens by adding extra copies of prb_pint
        uwrow.bayes_prob := uwrow.bayes_prob - minrank + ppint + uwrow.num_toks ^ 2 - (maxcount - uwrow.num_toks) ^ 2;
        return next uwrow;
    end loop;
end
$_$
    LANGUAGE plpgsql STABLE COST 300 ROWS 4;

COMMENT ON FUNCTION compute_bayes_class_all(bigint, character varying) IS 'setof bayes_cache%rowtype = compute_bayes_cache(prg_oid, prg_title) -- computes the weighted bayes score for each pint_class for a prg_oid';

CREATE FUNCTION get_prg_title(bigint) RETURNS character varying
    AS $_$select patt_value from @@SCHEMA@@.prg_attrs where prg_oid = $1 and patt_name = 'title' order by patt_name limit 1;$_$
    LANGUAGE sql STABLE STRICT;

CREATE FUNCTION get_prg_toks(bigint, character varying, character varying) RETURNS SETOF bayes_toks
    AS $_$DECLARE
	prgoid alias for $1;
	argprgtitle alias for $2;
	pintclass alias for $3;
	outrow @@SCHEMA@@.bayes_toks%ROWTYPE;
	pattrow @@SCHEMA@@.prg_attrs%ROWTYPE;
	cattrow @@SCHEMA@@.chan_attrs%ROWTYPE;
	tok record;
	prgtitle varchar;
BEGIN
	if prgoid is null or pintclass is null then
		return;
	end if;
	if argprgtitle is null then
		prgtitle := @@SCHEMA@@.get_prg_title(prgoid);
	else
		prgtitle := argprgtitle;
	end if;
	outrow.prg_oid := prgoid;
	outrow.prg_title := prgtitle;
	outrow.pint_class := pintclass;
	outrow.tok_src := 'p';
	-- tokenize programme attributes
	for pattrow in select * from @@SCHEMA@@.prg_attrs where prg_oid = outrow.prg_oid loop
		outrow.tok_name := pattrow.patt_name;
		outrow.tok_subname := coalesce(pattrow.patt_subname, '');
		for tok in select distinct lower(t) as t
				from @@SCHEMA@@.tokenizer(pattrow.patt_value) as t
				where length(t) > 2 and t != 'the' loop
			outrow.tok_value = tok.t;
			return next outrow;
		end loop;
	end loop;
	-- tokenize channel attributes
	outrow.tok_src := 'c';
	outrow.tok_subname := '';
	for cattrow in select ca.* from @@SCHEMA@@.chan_attrs ca
			inner join @@SCHEMA@@.programmes p on p.chan_oid = ca.chan_oid
			where p.prg_oid = outrow.prg_oid loop
		outrow.tok_name := cattrow.catt_name;
		for tok in select distinct lower(t) as t
				from @@SCHEMA@@.tokenizer(cattrow.catt_value) as t
				where length(t) > 2 and t != 'the' loop
			outrow.tok_value = tok.t;
			return next outrow;
		end loop;
	end loop;
	return;
END;$_$
    LANGUAGE plpgsql STABLE COST 300 ROWS 50;

COMMENT ON FUNCTION get_prg_toks(bigint, character varying, character varying) IS 'setof bayes_toks = get_prg_toks(prg_oid, prg_title, pint_class) -- produces all the bayes_toks for a prg_oid, using the prg_title and pint_class given';

CREATE FUNCTION grid_end() RETURNS timestamp with time zone
    AS $$select @@SCHEMA@@.grid_endx(@@SCHEMA@@.now_5min())$$
    LANGUAGE sql STABLE;

COMMENT ON FUNCTION grid_end() IS 'Returns the time at which the current grid should end';

CREATE FUNCTION grid_endx(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$DECLARE
	res timestamptz;
	tmins int4;
BEGIN
	res := @@SCHEMA@@.round_5min($1);
	return res + '2 hours'::interval;
END;$_$
    LANGUAGE plpgsql STABLE STRICT;

COMMENT ON FUNCTION grid_endx(timestamp with time zone) IS 'Returns the time at which a grid should end when it starts at the passed time.';

CREATE FUNCTION incr_bayes_update(bigint) RETURNS void
    AS $_$
DECLARE
	prgoid ALIAS FOR $1;
	tok RECORD;
	pint RECORD;
BEGIN
	-- this is not a perfect incremental update
	-- to do a perfect one, it needs to update for all interests of this prg's tokens
	-- and for all tokens of this prg's new and old interests
	-- the former is doable by (un)commenting some lines
	-- the latter is doable, but would be almost as slow as doing a full update
	-- that could be improved by adding some columns to p_tok_given_pint and
	-- then doing an update to the matview that duplicates the logic from the view
	-- but that gets hairy

	-- complex mvs, part 1
	-- redo for all pints in case this is a delta and not a fresh one
	FOR tok IN SELECT DISTINCT tok_src, tok_name, tok_subname, tok_value, pint_class
			FROM @@SCHEMA@@.bayes_toks WHERE prg_oid = prgoid LOOP
		-- tok_count_by_pint
		DELETE FROM @@SCHEMA@@.tok_count_by_pint_mv
		WHERE tok_src = tok.tok_src AND tok_name = tok.tok_name
		AND tok_subname = tok.tok_subname AND tok_value = tok.tok_value
		AND pint_class = tok.pint_class
		;
		-- p_tok_given_pint
		DELETE FROM @@SCHEMA@@.p_tok_given_pint_mv
		WHERE tok_src = tok.tok_src AND tok_name = tok.tok_name
		AND tok_subname = tok.tok_subname AND tok_value = tok.tok_value
		AND pint_class = tok.pint_class
		;
		-- re-insert tok_count_by_pint
		INSERT INTO @@SCHEMA@@.tok_count_by_pint_mv
		SELECT * FROM @@SCHEMA@@.tok_count_by_pint
		WHERE tok_src = tok.tok_src AND tok_name = tok.tok_name
		AND tok_subname = tok.tok_subname AND tok_value = tok.tok_value
		AND pint_class = tok.pint_class
		;
	END LOOP;

	-- refresh pint_count
	-- FOR pint IN SELECT pint_class FROM @@SCHEMA@@.cv_interest LOOP
	FOR pint IN SELECT DISTINCT pint_class FROM @@SCHEMA@@.bayes_toks WHERE prg_oid = prgoid LOOP
		-- delete
		DELETE FROM @@SCHEMA@@.pint_count_mv
		WHERE pint_class = pint.pint_class;
		-- insert
		INSERT INTO @@SCHEMA@@.pint_count_mv
		SELECT * FROM @@SCHEMA@@.pint_count
		WHERE pint_class = pint.pint_class;
	END LOOP;

	-- refresh tok_total
	DELETE FROM @@SCHEMA@@.tok_total_mv;
	INSERT INTO @@SCHEMA@@.tok_total_mv SELECT * FROM @@SCHEMA@@.tok_total;

	-- refresh p_pint
	DELETE FROM  @@SCHEMA@@.p_pint_mv;
	INSERT INTO @@SCHEMA@@.p_pint_mv SELECT * FROM @@SCHEMA@@.p_pint;

	-- re-insert for p_tok_given_pint
	FOR tok IN SELECT DISTINCT tok_src, tok_name, tok_subname, tok_value, pint_class
			FROM @@SCHEMA@@.bayes_toks WHERE prg_oid = prgoid LOOP
		INSERT INTO @@SCHEMA@@.p_tok_given_pint_mv
		SELECT * FROM @@SCHEMA@@.p_tok_given_pint
		WHERE tok_src = tok.tok_src AND tok_name = tok.tok_name
		AND tok_subname = tok.tok_subname AND tok_value = tok.tok_value
		AND pint_class = tok.pint_class
		;
	END LOOP;
	DELETE FROM @@SCHEMA@@.bayes_cache;
	RETURN;
END;
$_$
    LANGUAGE plpgsql STRICT;

CREATE FUNCTION longer(character varying, character varying) RETURNS character varying
    AS $_$select case when $1 is null then $2 when $2 is null then $1 when length($2) > length($1) then $2 else $1 end;$_$
    LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION longer(character varying, character varying) IS 'Returns the longer of two input strings';

CREATE FUNCTION max(anyelement, anyelement) RETURNS anyelement
    AS $_$BEGIN
	if $1 > $2 then
		return $1;
	else
		return $2;
	end if;
end;
$_$
    LANGUAGE plpgsql IMMUTABLE STRICT;

COMMENT ON FUNCTION max(anyelement, anyelement) IS 'returns the maximum of two elements';

CREATE FUNCTION min(anyelement, anyelement) RETURNS anyelement
    AS $_$BEGIN
	if $1 < $2 then
		return $1;
	else
		return $2;
	end if;
end;
$_$
    LANGUAGE plpgsql IMMUTABLE STRICT;

COMMENT ON FUNCTION min(anyelement, anyelement) IS 'returns the minimum of two elements';

CREATE FUNCTION now_5min() RETURNS timestamp with time zone
    AS $$select @@SCHEMA@@.round_5min(now());$$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION now_5min() IS 'Rounds current time to previous 5 minute mark';

CREATE FUNCTION prg_attrs_then(timestamp with time zone) RETURNS SETOF prg_attrs
    AS $_$SELECT pa.* 
   FROM @@SCHEMA@@.prg_attrs pa
   natural join @@SCHEMA@@.programmes p
WHERE p.prg_start >= ($1 - '08:00:00'::interval)
AND p.prg_start < @@SCHEMA@@.grid_endx($1)
AND p.prg_stop > @@SCHEMA@@.round_5min($1)
AND p.prg_stop <= (@@SCHEMA@@.grid_endx($1) + '08:00:00'::interval)$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION prg_attrs_then(timestamp with time zone) IS 'Fetches programme attrs for prgs on during a grid block starting at the given time';

CREATE FUNCTION prgs_then(timestamp with time zone) RETURNS SETOF programmes
    AS $_$SELECT *
   FROM @@SCHEMA@@.programmes p
WHERE p.prg_start >= ($1 - '08:00:00'::interval)
AND p.prg_start < @@SCHEMA@@.grid_endx($1)
AND p.prg_stop > @@SCHEMA@@.round_5min($1)
AND p.prg_stop <= (@@SCHEMA@@.grid_endx($1) + '08:00:00'::interval)$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION prgs_then(timestamp with time zone) IS 'Fetches programmes active in a grid starting at the given time';

CREATE FUNCTION round_5min(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$DECLARE
	result timestamptz;
	fixmin int4;
BEGIN
	result := $1;
	result := @@SCHEMA@@.trunc_mins(result);
	fixmin := extract(minute from result);
	fixmin := fixmin % 5;
	result := result - (fixmin || ' minutes')::interval;
	return result;
END;$_$
    LANGUAGE plpgsql STABLE STRICT;

COMMENT ON FUNCTION round_5min(timestamp with time zone) IS 'Rounds a time to the previous five minute mark';

CREATE FUNCTION roundup_5min(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$DECLARE
	result timestamptz;
	fixmin int4;
BEGIN
	result := $1;
	result := @@SCHEMA@@.trunc_mins(result);
	fixmin := extract(minute from result);
	fixmin := fixmin % 5;
	if fixmin > 0 then
		result := result + ((5 - fixmin) || ' minutes')::interval;
	end if;
	return result;
END;$_$
    LANGUAGE plpgsql STABLE STRICT;

COMMENT ON FUNCTION roundup_5min(timestamp with time zone) IS 'Rounds a time to the next five minute mark';

CREATE FUNCTION shows_grid_then(timestamp with time zone) RETURNS SETOF shows_grid
    AS $_$
SELECT s.prg_oid, s.prg_start, s.prg_stop,
	@@SCHEMA@@.blk_startx(s.prg_start, $1) AS blk_start,
	@@SCHEMA@@.blk_endx(s.prg_stop, $1) AS blk_end,
	s.prg_title, s.chan_oid, s.chan_number, s.chan_name,
	pi.pint_class, coalesce(bc.pint_class, @@SCHEMA@@.get_bayes_class(s.prg_oid, s.prg_title)) as bayes_class
FROM @@SCHEMA@@.shows s
	left join @@SCHEMA@@.bayes_cache bc using (prg_oid)
	left join @@SCHEMA@@.prg_interest pi on s.prg_title = pi.prg_title
WHERE s.prg_start >= ($1 - '08:00:00'::interval)
	AND s.prg_start < @@SCHEMA@@.grid_endx($1)
	AND s.prg_stop > @@SCHEMA@@.round_5min($1)
	AND s.prg_stop <= (@@SCHEMA@@.grid_endx($1) + '08:00:00'::interval)
ORDER BY s.chan_number, s.chan_name, s.prg_start;
$_$
    LANGUAGE sql STABLE STRICT;

COMMENT ON FUNCTION shows_grid_then(timestamp with time zone) IS 'Fetches a table like active_shows_grid, but for a grid starting other than now';

CREATE FUNCTION tokenizer(text) RETURNS SETOF text
    AS $_$DECLARE
	splitme text;	
	word text;
BEGIN
	splitme := $1;
    -- trim leading junk
    splitme := substring(splitme from $$^\W*(.*)$$);
	WHILE length(splitme) > 0 LOOP
		-- snarf a word
		word := substring(splitme from $$^(\w*)$$);
		if length(word) > 0 then
			return next word;
		end if;
		-- trim leading word
		splitme := substring(splitme from $$^\w*\W*(.*)$$);
	END LOOP;
	return;
END;$_$
    LANGUAGE plpgsql IMMUTABLE STRICT ROWS 10;

COMMENT ON FUNCTION tokenizer(text) IS 'return all the tokens from a string';

CREATE FUNCTION trunc_mins(timestamp with time zone) RETURNS timestamp with time zone
    AS $_$DECLARE
	result timestamptz;
	tz int4;
	tz2 int4;
BEGIN
	-- have to do this way instead of simpler alternative
	-- because that introduces tiny floating point errors sometimes
	result := $1;
	tz := extract(timezone from result);
	result := date_trunc('minutes', result);
	tz2 := extract(timezone from result);
	if tz2 != tz then
		result := result + ((tz2 - tz) || ' seconds')::interval;
	end if;
	return result;
END;$_$
    LANGUAGE plpgsql IMMUTABLE STRICT;

COMMENT ON FUNCTION trunc_mins(timestamp with time zone) IS 'Limited version of date_trunc that does not have bugs across DST changes';

CREATE FUNCTION update_bayes_stats() RETURNS void
    AS $$DECLARE
	bt_corr real;
BEGIN
	-- check if we should cluster our toks table
	analyze @@SCHEMA@@.bayes_toks;
	select into bt_corr correlation
		from pg_catalog.pg_stats
		where schemaname = '@@SCHEMA@@' and tablename = 'bayes_toks'
		and attname = 'tok_src';
	if bt_corr < 0.9 then
		cluster @@SCHEMA@@.bayes_toks;
	end if;

	-- flush our matviews
	delete from @@SCHEMA@@.p_tok_given_pint_mv;
	delete from @@SCHEMA@@.p_pint_mv;
	delete from @@SCHEMA@@.tok_total_mv;
	delete from @@SCHEMA@@.pint_count_mv;
	delete from @@SCHEMA@@.tok_count_by_pint_mv;
	-- repopuplate our matviews
	insert into @@SCHEMA@@.tok_count_by_pint_mv select * from @@SCHEMA@@.tok_count_by_pint;
	analyze @@SCHEMA@@.tok_count_by_pint_mv;
	insert into @@SCHEMA@@.pint_count_mv select * from @@SCHEMA@@.pint_count;
	analyze @@SCHEMA@@.pint_count_mv;
	insert into @@SCHEMA@@.tok_total_mv select * from @@SCHEMA@@.tok_total;
	analyze @@SCHEMA@@.tok_total_mv;
	insert into @@SCHEMA@@.p_pint_mv select * from @@SCHEMA@@.p_pint;
	analyze @@SCHEMA@@.p_pint_mv;
	insert into @@SCHEMA@@.p_tok_given_pint_mv select * from @@SCHEMA@@.p_tok_given_pint;
	analyze @@SCHEMA@@.p_tok_given_pint_mv;

	-- flush cache
	delete from @@SCHEMA@@.bayes_cache;
	
	return;
end;$$
    LANGUAGE plpgsql;

COMMENT ON FUNCTION update_bayes_stats() IS 'Update all bayes statistics materialized view tables';

CREATE SEQUENCE chan_attrs_catt_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE chan_attrs_catt_oid_seq OWNED BY chan_attrs.catt_oid;

CREATE SEQUENCE channels_chan_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE channels_chan_oid_seq OWNED BY channels.chan_oid;

CREATE SEQUENCE imdb_ids_imdb_id_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE imdb_ids_imdb_id_oid_seq OWNED BY imdb_ids.imdb_id_oid;

CREATE SEQUENCE prg_attrs_patt_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE prg_attrs_patt_oid_seq OWNED BY prg_attrs.patt_oid;

CREATE SEQUENCE programmes_prg_oid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER SEQUENCE programmes_prg_oid_seq OWNED BY programmes.prg_oid;

ALTER TABLE chan_attrs ALTER COLUMN catt_oid SET DEFAULT nextval('chan_attrs_catt_oid_seq'::regclass);

ALTER TABLE channels ALTER COLUMN chan_oid SET DEFAULT nextval('channels_chan_oid_seq'::regclass);

ALTER TABLE icons ALTER COLUMN icn_oid SET DEFAULT nextval('icons_icn_oid_seq'::regclass);

ALTER TABLE imdb_ids ALTER COLUMN imdb_id_oid SET DEFAULT nextval('imdb_ids_imdb_id_oid_seq'::regclass);

ALTER TABLE prg_attrs ALTER COLUMN patt_oid SET DEFAULT nextval('prg_attrs_patt_oid_seq'::regclass);

ALTER TABLE programmes ALTER COLUMN prg_oid SET DEFAULT nextval('programmes_prg_oid_seq'::regclass);

ALTER TABLE ONLY bayes_cache
    ADD CONSTRAINT bayes_cache_pkey PRIMARY KEY (prg_oid);

ALTER TABLE bayes_cache CLUSTER ON bayes_cache_pkey;

ALTER TABLE ONLY chan_icons
    ADD CONSTRAINT chan_icons_pkey PRIMARY KEY (icn_oid);

ALTER TABLE ONLY chan_attrs
    ADD CONSTRAINT channel_attrs_pkey PRIMARY KEY (catt_oid);

ALTER TABLE ONLY channels
    ADD CONSTRAINT channels_chan_id_key UNIQUE (chan_id);

ALTER TABLE ONLY channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (chan_oid);

ALTER TABLE channels CLUSTER ON channels_pkey;

ALTER TABLE ONLY cv_interest
    ADD CONSTRAINT cv_interest_pkey PRIMARY KEY (pint_class);

ALTER TABLE ONLY icons
    ADD CONSTRAINT icons_pkey PRIMARY KEY (icn_oid);

ALTER TABLE ONLY imdb_ids
    ADD CONSTRAINT imdb_ids_patt_name_key UNIQUE (patt_name, patt_subname, patt_value, imdb_id);

ALTER TABLE imdb_ids CLUSTER ON imdb_ids_patt_name_key;

ALTER TABLE ONLY imdb_ids
    ADD CONSTRAINT imdb_ids_pkey PRIMARY KEY (imdb_id_oid);

ALTER TABLE ONLY prg_attrs
    ADD CONSTRAINT prg_attrs_pkey PRIMARY KEY (patt_oid);

ALTER TABLE ONLY prg_icons
    ADD CONSTRAINT prg_icons_pkey PRIMARY KEY (icn_oid);

ALTER TABLE ONLY prg_interest
    ADD CONSTRAINT prg_interest_pkey PRIMARY KEY (prg_title);

ALTER TABLE ONLY programmes
    ADD CONSTRAINT programmes_pkey PRIMARY KEY (prg_oid);

ALTER TABLE ONLY bayes_toks
    ADD CONSTRAINT ux_tok_uniq UNIQUE (tok_src, tok_name, tok_subname, tok_value, prg_oid);

ALTER TABLE bayes_toks CLUSTER ON ux_tok_uniq;

CREATE INDEX ix_catt_best_name ON chan_attrs USING btree (chan_oid, catt_value) WHERE (((catt_name)::text = 'display-name'::text) AND (catt_value ~ '^[0-9]+ [A-Z]+$'::text));

CREATE INDEX ix_catt_search ON chan_attrs USING btree (chan_oid, catt_name, catt_value);

ALTER TABLE chan_attrs CLUSTER ON ix_catt_search;

CREATE INDEX ix_cicons_chan_oid ON chan_icons USING btree (chan_oid);

CREATE INDEX ix_patt_search ON prg_attrs USING btree (prg_oid, patt_name, patt_value);

ALTER TABLE prg_attrs CLUSTER ON ix_patt_search;

CREATE INDEX ix_patt_search2 ON prg_attrs USING btree (patt_name);

CREATE INDEX ix_prg_start_stop ON programmes USING btree (prg_start, prg_stop);

ALTER TABLE programmes CLUSTER ON ix_prg_start_stop;

CREATE INDEX ix_ptgp_lu ON p_tok_given_pint_mv USING btree (tok_src, tok_name, tok_subname, tok_value);

CREATE INDEX ix_tcbp_lu ON tok_count_by_pint_mv USING btree (tok_src, tok_name, tok_subname, tok_value);

CREATE INDEX ix_tok_prg_oid ON bayes_toks USING btree (prg_oid);

CREATE INDEX ix_tok_prg_title ON bayes_toks USING btree (prg_title);

ALTER TABLE ONLY bayes_toks
    ADD CONSTRAINT "$1" FOREIGN KEY (pint_class) REFERENCES cv_interest(pint_class) ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE ONLY bayes_cache
    ADD CONSTRAINT "$1" FOREIGN KEY (prg_oid) REFERENCES programmes(prg_oid) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE ONLY chan_attrs
    ADD CONSTRAINT catt_chan_ref FOREIGN KEY (chan_oid) REFERENCES channels(chan_oid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY chan_icons
    ADD CONSTRAINT chan_icon_chan_ref FOREIGN KEY (chan_oid) REFERENCES channels(chan_oid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY patt_icons
    ADD CONSTRAINT patt_icon_patt_ref FOREIGN KEY (patt_oid) REFERENCES prg_attrs(patt_oid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY prg_attrs
    ADD CONSTRAINT patt_prg_ref FOREIGN KEY (prg_oid) REFERENCES programmes(prg_oid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY prg_interest
    ADD CONSTRAINT pint_cv_ref FOREIGN KEY (pint_class) REFERENCES cv_interest(pint_class) ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE ONLY programmes
    ADD CONSTRAINT prg_chan_ref FOREIGN KEY (chan_oid) REFERENCES channels(chan_oid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY prg_icons
    ADD CONSTRAINT prg_icon_prg_ref FOREIGN KEY (prg_oid) REFERENCES programmes(prg_oid) ON UPDATE CASCADE ON DELETE CASCADE;


SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = @@SCHEMA@@, pg_catalog;
COPY cv_interest (pint_class, pint_order, weight) FROM stdin;
good	1	2
normal	2	0
crap	3	0
bad	4	-1
hide	99	-10
\.

