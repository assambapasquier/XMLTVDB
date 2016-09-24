package TVListings::DB;

use strict;
use warnings;

use base qw/Exporter/;
# get_all_prg_interest
our @EXPORT = qw{
  get_now_patts get_all_patts get_patts
  get_cinfo get_all_cicon get_cicon
  get_cv_pint_class get_prg_interest
  get_bayes_details
  getdbh
  locktables_small locktables_big
};
our @EXPORT_OK = qw{
  SQL_GRID SQL_GRID_THEN SQL_NOW SQL_GRID_MOBILE
  SQL_SEARCH SQL_SEARCH_PINT SQL_SEARCH_LIMIT
  SQL_CHAN_SHOWS SQL_PINFO SQL_CNAME
  SQL_DEL_INTEREST SQL_INS_INTEREST
  SQL_BAYES_UPDATE SQL_BAYES_RELEARN SQL_BAYES_FULL
  SQL_BAYES_DEL SQL_BAYES_CLEAR
  SQL_GET_IMDB SQL_DEL_IMDB SQL_INS_IMDB
  SQL_GET_BAYES
  SQL_FIND_NO_IMDB
};
our %EXPORT_TAGS = (
  default => \@EXPORT,
  all => [@EXPORT, @EXPORT_OK],
);

use TVListings::Config;

use constant SQL_SEARCH_LIMIT => 25;
# "THEN" items take an offset in minutes
use constant {
  SQL_GRID_THEN => 'SELECT * FROM shows_grid_then('
    . qq{now() + (? || ' minutes')::interval)},
  SQL_NOW => 'SELECT * FROM shows_grid_then(now()) where prg_start <= now() '
    . 'and prg_stop > now()',
  SQL_GRID_MOBILE => 'SELECT * FROM shows_grid_then(roundup_5min(now())) '
    . 'WHERE prg_start <= roundup_5min(now()) '
    . 'AND prg_stop >= roundup_5min(now())',
  SQL_SEARCH => 'SELECT s.*, '
    . '(EXTRACT(epoch FROM prg_start - now()) / 60)::integer AS delta, '
    . '(EXTRACT(epoch FROM prg_stop - prg_start) / 60)::integer AS duration '
    . 'FROM shows s '
    . 'WHERE prg_stop >= now() AND prg_oid IN ( '
      . 'SELECT prg_oid FROM prg_attrs WHERE LOWER(patt_value) LIKE '
      . q{'%' || REPLACE(LOWER(?), ' ', '%') || '%' ) }
    . 'ORDER BY prg_start ASC, prg_stop ASC LIMIT ' . SQL_SEARCH_LIMIT,
  SQL_SEARCH_PINT => 'SELECT DISTINCT s.*, '
    . '(EXTRACT(epoch FROM prg_start - now()) / 60)::integer AS delta, '
    . '(EXTRACT(epoch FROM prg_stop - prg_start) / 60)::integer AS duration, '
    . 'now() as now FROM shows s NATURAL JOIN '
    . q{prg_interest WHERE pint_class = ? AND prg_stop > now() }
    . 'ORDER BY prg_start ASC, chan_number ASC LIMIT ' . SQL_SEARCH_LIMIT,
  SQL_PINFO => 'SELECT * FROM programmes WHERE prg_oid = ?',
  SQL_PATTS => 'SELECT * FROM prg_attrs WHERE prg_oid = ?',
#  SQL_ALL_PATTS => 'SELECT pa.* FROM prg_attrs pa NATURAL JOIN active_prgs',
  SQL_NOW_PATTS => 'SELECT pa.* FROM prg_attrs pa NATURAL JOIN prgs_now',
  SQL_THEN_PATTS => 'SELECT * from prg_attrs_then('
    . qq{now() + (? || ' minutes')::interval)},
  SQL_CHAN => 'SELECT * FROM channels WHERE chan_oid = ?',
  SQL_CHAN_NAME => 'SELECT * FROM chan_detail '
    . qq{where chan_number || ' ' || chan_name LIKE '%' || ? || '%'},
  SQL_CHAN_SHOWS => 'SELECT * FROM shows WHERE chan_oid = ? '
    . q{AND prg_stop - (? || ' minutes')::interval BETWEEN now() }
    . q{AND now() + '24 hours'::interval},
  SQL_CATTS => 'SELECT * FROM chan_attrs WHERE chan_oid = ?',
  SQL_CNAME => 'SELECT * FROM chan_best_name WHERE chan_oid = ?',
  SQL_CICON => 'SELECT * FROM chan_icons WHERE chan_oid = ?',
  SQL_ALL_CICON => 'SELECT * FROM chan_icons',
  SQL_CV_INTEREST => 'SELECT * FROM cv_interest ORDER BY pint_order',
  SQL_GET_INTEREST => 'SELECT * FROM prg_interest WHERE prg_title = ?',
  SQL_DEL_INTEREST => 'DELETE FROM prg_interest WHERE prg_title = ?',
  SQL_INS_INTEREST => 'INSERT INTO prg_interest (prg_title, pint_class) '
    . 'VALUES (?, ?)',
  SQL_ALL_INTEREST => 'SELECT * FROM prg_interest',
  SQL_BAYES_DETAILS => 'SELECT * FROM compute_bayes_class_all(?, null) ORDER BY bayes_prob DESC',
  SQL_BAYES_UPDATE => 'SELECT bayes_learn_prg(?, ?, ?)',
  SQL_BAYES_RELEARN => 'UPDATE bayes_toks SET pint_class = ? '
    . 'WHERE prg_title = ?',
  SQL_BAYES_DEL => 'DELETE FROM bayes_toks WHERE prg_oid = ?',
  SQL_BAYES_CLEAR => 'DELETE FROM bayes_toks WHERE prg_title = ?',
  SQL_BAYES_FULL => 'SELECT update_bayes_stats()',
  SQL_GET_IMDB => qq{SELECT imdb_id FROM imdb_ids WHERE patt_name = 'episode-num' AND patt_subname = 'dd_progid' AND patt_value = ?},
  SQL_DEL_IMDB => qq{DELETE FROM imdb_ids WHERE patt_name = 'episode-num' AND patt_subname = 'dd_progid' AND patt_value = ?},
  SQL_INS_IMDB => qq{INSERT INTO imdb_ids (patt_name, patt_subname, patt_value, imdb_id) VALUES ('episode-num', 'dd_progid', ?, ?)},
  
  SQL_GET_BAYES => q{
    select get_bayes_class(p.prg_oid, null) as bayes_class, p.prg_start
      from (
        select p.*
        from programmes p
          natural left join bayes_cache c
        where prg_start >= (now() - '08:00:00'::interval)
          and prg_start < now() + ($1||' hours')::interval
          and prg_stop > now()
          and c.pint_class is null
        order by prg_start
        _LIMIT_
      ) p
  },
  
  SQL_FIND_NO_IMDB => q{
    select prg_title, min(patt_value) as progid, min(prg_oid) as prg_oid
      from (
        select s.prg_oid, b.prg_title, b.pint_class, aep.patt_value, i.imdb_id
        from shows s
          join bayes_cache b using (prg_oid)
          join prg_attrs aep using (prg_oid)
          left join imdb_ids i on aep.patt_name = i.patt_name
            and aep.patt_subname = i.patt_subname
            and aep.patt_value like i.patt_value||'%'
        where
              s.prg_start >= (now() - '08:00:00'::interval)
          and s.prg_start < now() + ($1||' hours')::interval
          and s.prg_stop > now()
          and b.pint_class in ('crap','normal','good')
          and aep.patt_name = 'episode-num'
          and aep.patt_subname = 'dd_progid'
          and i.imdb_id is null
      ) foo
      group by prg_title
  },
};

sub _get_multi_patts($$;@) {
  my ($dbh, $sql, @phvals) = @_;
  my $pattsth = $dbh->prepare_cached($sql);
  $pattsth->execute(@phvals);
  my $patts = $pattsth->fetchall_arrayref();

  my $poidi = $pattsth->{NAME_lc_hash}{prg_oid};
  my $ani   = $pattsth->{NAME_lc_hash}{patt_name};
  my $subni = $pattsth->{NAME_lc_hash}{patt_subname};
  my $vali  = $pattsth->{NAME_lc_hash}{patt_value};

  my %patts;
  for my $pai (@$patts) {
    if ($pai->[$subni]) {
      push @{$patts{$pai->[$poidi]}{$pai->[$ani]}{$pai->[$subni]}},
        $pai->[$vali];
    } else {
      push @{$patts{$pai->[$poidi]}{$pai->[$ani]}}, $pai->[$vali];
    }
  }
  return \%patts;
}

sub get_all_patts($;$) {
  my ($dbh, $offset) = @_;
  return _get_multi_patts($dbh, SQL_THEN_PATTS, $offset || 0);
}

sub get_now_patts($) {
  my ($dbh) = @_;
  return _get_multi_patts($dbh, SQL_NOW_PATTS);
}

sub get_patts($$) {
  my ($dbh, $prgoid) = @_;
  my $pattsth = $dbh->prepare_cached(SQL_PATTS);
  $pattsth->execute($prgoid);
  my $patts = $pattsth->fetchall_arrayref({});
  my %patts;
  for my $pai (@$patts) {
    my $item = { map {$_ => $pai->{$_}} qw/patt_lang patt_value/ };
    if ($pai->{patt_subname}) {
      push @{$patts{$pai->{patt_name}}{$pai->{patt_subname}}}, $item;
    } else {
      push @{$patts{$pai->{patt_name}}}, $item;
    }
  }
  return \%patts;
}

sub get_cinfo($$) {
  my ($dbh, $chanoid) = @_;
  # handle some magic with the chanoid
  my $sth;
  if ($chanoid =~ /^\d+$/) {
    $sth = $dbh->prepare_cached(SQL_CHAN);
  } else {
    $sth = $dbh->prepare_cached(SQL_CHAN_NAME);
  }
  $sth->execute($chanoid);
  my $chits = $sth->fetchall_arrayref({});
  my %cinfo = (chan => $chits->[0]);
  # prefer exact matches
  for (my $n = 1; $n <= $#$chits; ++$n) {
    if ($chits->[$n]{chan_name} eq $chanoid) {
      $cinfo{chan} = $chits->[$n];
    }
  }
  # in case it was a by-name thing
  $chanoid = $cinfo{chan}{chan_oid};
  $sth = $dbh->prepare_cached(SQL_CATTS);
  $sth->execute($chanoid);
  my $catts = $sth->fetchall_arrayref({});
  for my $cai (@$catts) {
    push @{$cinfo{atts}{$cai->{catt_name}}}, $cai->{catt_value};
  }
  $cinfo{icon} = get_cicon($dbh, $chanoid);
  $sth = $dbh->prepare_cached(SQL_CNAME);
  $sth->execute($chanoid);
  my $cninfo = $sth->fetchall_arrayref({})->[0];
  $cinfo{name} = "$cninfo->{chan_number} $cninfo->{chan_name}";
  return \%cinfo;
}

sub get_all_cicon($) {
  my ($dbh) = @_;
  my $icnsth = $dbh->prepare_cached(SQL_ALL_CICON);
  $icnsth->execute();
  my $icndata = $icnsth->fetchall_hashref('chan_oid');
  for my $row (values %$icndata) {
    ($row->{icn_src_file} = $row->{icn_src}) =~ s/.*\///;
  }
  return $icndata;
}

sub get_cicon($$) {
  my ($dbh, $chanoid) = @_;
  my $icnsth = $dbh->prepare_cached(SQL_CICON);
  $icnsth->execute($chanoid);
  my $icndata = $icnsth->fetchall_arrayref({});
  if ($icndata and $icndata->[0]) {
    $icndata->[0]{icn_src_file} = $icndata->[0]{icn_src};
    $icndata->[0]{icn_src_file} =~ s/.*\///;
    return $icndata->[0];
  } else {
    return undef;
  }
}

sub get_cv_pint_class($) {
  my ($dbh) = @_;
  my $sth = $dbh->prepare_cached(SQL_CV_INTEREST);
  $sth->execute;
  my $cvdata = $sth->fetchall_arrayref({});
  return map {$_->{pint_class}} @$cvdata;
}

#sub get_all_prg_interest($) {
#  my ($dbh) = @_;
#  my $sth = $dbh->prepare_cached(SQL_ALL_INTEREST);
#  $sth->execute();
#  my $data = $sth->fetchall_arrayref();
#  my $pti = $sth->{NAME_lc_hash}{prg_title};
#  my $pii = $sth->{NAME_lc_hash}{pint_class};
#  return { map {$_->[$pti] => $_->[$pii]} @$data };
#}

sub get_prg_interest($$) {
  my ($dbh, $pt) = @_;
  my $sth = $dbh->prepare_cached(SQL_GET_INTEREST);
  $sth->execute($pt);
  my $data = $sth->fetchall_arrayref({});
  for my $d (@$data) {
    return $d->{pint_class};
  }
  return '';
}

sub get_bayes_details($$) {
  my ($dbh, $poid) = @_;
  my $sth = $dbh->prepare_cached(SQL_BAYES_DETAILS);
  $sth->execute($poid);
  my $data = $sth->fetchall_arrayref({});
  return @$data;
}

sub getdbh(;$) {
  my $permschema = shift;
  my $dbh = DBI->connect(XMLTVDBI);
  $dbh->do('SET ' . ($permschema ? '' : 'LOCAL ') . 'search_path = '
    . XMLTVSCHEMA);
  return $dbh;
}

# lock all the tables that need to be locked when viewing
sub locktables_small($) {
  my ($dbh) = @_;
  for my $tbl (qw/bayes_cache/) {
    $dbh->do("LOCK TABLE $tbl IN SHARE ROW EXCLUSIVE MODE");
  }
}

# lock all the tables that need to be locked when updating
sub locktables_big($) {
  my ($dbh) = @_;
  locktables_small($dbh);
  for my $tbl (qw/bayes_toks p_pint_mv p_tok_given_pint_mv
      pint_count_mv tok_count_by_pint_mv tok_total_mv/) {
    $dbh->do("LOCK TABLE $tbl IN SHARE ROW EXCLUSIVE MODE");
  }
}

1;
