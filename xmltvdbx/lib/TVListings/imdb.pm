package TVListings::imdb;

use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw/search_imdb/;

use Apache2::Const qw/:http/;
use CGI qw/escapeHTML/;
use CGI::Util qw/escape/;
use Data::Dump qw/pp/;

use TVListings::Config;
use TVListings::DB qw/:default SQL_GET_IMDB SQL_DEL_IMDB SQL_INS_IMDB/;
use TVListings::Links;

my $bindir;
sub bindir() {
  return $bindir if defined $bindir;
  # find our bin path
  my $path = __PACKAGE__;
  $path =~ s/::/\//g;
  $path = "$path.pm";
  my $fullpath = $INC{$path};
  my $match = qr{^(.*)/lib/\Q$path\E$};
  if ($fullpath =~ $match) {
    return $bindir = "$1/bin";
  }
  $fullpath = Cwd::abs_path($fullpath);
  if ($fullpath =~ $match) {
    return $bindir = "$1/bin";
  }
  return undef;
}

sub search_imdb($%) {
  my ($title, %args) = @_;
  my $bin = bindir();
  return [] if !defined $bin;
  # sanitize path for this run
  local $ENV{PATH} = '/bin:/usr/bin';
  my @imdbargs = ('-M');
  my @opts;
  my $ddtype = '';
  if ($args{ddprogid}) {
    ($ddtype) = ($args{ddprogid} =~ /^(MV|EP|SH)/);
    $ddtype = '' if !defined $ddtype;
    # tv=only is broken
    if ($ddtype and $ddtype eq 'MV') {
      push @opts, 'tv=no';
    }
  }
  if ($args{year}) {
    my ($year) = ($args{year} =~ /^(\d+)$/);
    if ($year) {
      # year for the tv ep will be the airing year, which is >= the show start
      push @opts, "from_year=$year" if $ddtype ne 'EP';
      push @opts, "to_year=$year";
    }
  }
  push @imdbargs, join(',', @opts) if @opts;
  my $sanititle = $title;
  $sanititle =~ s/[^a-zA-Z0-9\.,_ -]//g;
  ($sanititle) = ($sanititle =~ /^([a-zA-Z0-9\.,_ -]+)$/);
  if (!$sanititle) {
    warn "unsanitary title: " . pp($title);
    return [];
  }
  push @imdbargs, $sanititle;
  if (!open(MVSIZE, "-|", "$bin/imdb.pl", @imdbargs)) {
    warn "can't fork: $!";
    return [];
  }
  my @output = <MVSIZE>;
  if (!close(MVSIZE)) {
    warn "Can't close: $!";
    return [];
  }
  
  my @results;
  for my $line (@output) {
    my ($id, $title) = split(':', $line, 2);
    # work around tv=only being broken
    next if $ddtype eq 'EP' and $title !~ /^"/;
    next if $ddtype eq 'MV' and $title =~ /^"/;
    push @results, [$id, $title];
  }
  
  return @results;
}

sub error($$$) {
  my ($r, $q, $error) = @_;
  my $out = pagehead($r, $q, "TV Show IMDB Connection - Error")
    . $error
    . pagefoot($r, $q);
  return { status => HTTP_OK, text => $out };
}

sub render {
  my ($class, $r, $q, $dbh) = @_;
  
  my $prg_oid = $q->param('prg');
  my $key = $q->param('key');
  
  my $patts = get_patts($dbh, $prg_oid);
  
  my $out = '';
  
  if (!defined $patts->{title}) {
    return error($r, $q, 'Bad prg_oid');
  }
  if (!defined $patts->{'episode-num'} || !defined $patts->{'episode-num'}{'dd_progid'}) {
    return error($r, $q, 'No episode num');
  }
  if ($key ne 'title' and $key ne 'sub-title') {
    return error($r, $q, 'Bad key');
  }
  if ($key eq 'sub-title' and !$patts->{'sub-title'}) {
    return error($r, $q, 'Bad prg_oid or key');
  }
  my $stype = $q->param('stype') || 'title';
  if ($stype ne 'list' and $stype ne 'title') {
    return error($r, $q, 'Bad search type');
  }
  my $fast = $q->param('fast') ? 1 : 0;
  
  my $ddprogid = $patts->{'episode-num'}{'dd_progid'}[0]{patt_value};
  $ddprogid =~ s/\..*// if $key eq 'title';
  my $prg_title = $patts->{title}[0]{patt_value};
  my $prg_subtitle = $patts->{'sub-title'} ? $patts->{'sub-title'}[0]{patt_value} : '';
  
  $out = pagehead($r, $q, "TV Show IMDB Connection - $prg_title"
    . ($prg_subtitle ? " - $prg_subtitle" : ''));

  my %extra;
    
  if (!$q->param('imdburl')) {
    
    my $getsth = $dbh->prepare_cached(SQL_GET_IMDB);
    $getsth->execute($ddprogid);
    my $results = $getsth->fetchall_arrayref({});
    my $curid = $results->[0] ? $results->[0]{imdb_id} : '';

    # don't do fast mode if we already have an item
    my $year;
    if ($patts->{'date'}) {
      $year = $patts->{'date'}[0]{patt_value};
      ($year) = ($year =~ /^(\d{4})/);
    }
    my @imdbhits;
    @imdbhits = search_imdb($prg_title, ddprogid => $ddprogid, year => $year)
      if $key eq 'title';

    my $havehit = 0;

    if ($fast and $#imdbhits == 0) {
      # one exact hit, load it up
      my $sth = $dbh->prepare_cached(SQL_INS_IMDB);
      $sth->execute($ddprogid, $imdbhits[0][0]);
      push @{$extra{hdrs}}, ['Refresh', '0.1;url=' . imdbidurl($imdbhits[0][0])];
      $curid = $imdbhits[0][0];
      $havehit = 1;
      # rest of page will still render, but user should never see it
    } else {
      $fast = 0;
    }
    
    my $cururl = $curid ? imdbidurl($curid) : '';

    my $hitout = '';
    if (@imdbhits) {
      $hitout .= '<p>';
      for my $imdbhit (@imdbhits) {
        $hitout .= '<label><input type="radio" name="imdburl" value="' . escapeHTML($imdbhit->[0]) . '"';
        if ($imdbhit->[0] eq $curid) {
          $hitout .= ' checked="checked"' if $imdbhit->[0] eq $curid;
          $havehit = 1;
        }
        $hitout .= '/>' . escapeHTML($imdbhit->[1]) . '</label><br/>';
      }
      $hitout .= '</p>';
    }

    $out .= '<form method="post" action="./imdb"><p>';
    $out .= '<input type="hidden" name="prg" value="' . escapeHTML($prg_oid) . '"/>';
    $out .= '<input type="hidden" name="key" value="' . escapeHTML($key) . '"/>';
    $out .= '<input type="hidden" name="back" value="' . escapeHTML($q->param('back')) . '"/>'
      if $q->param('back');
    $out .= '<input type="radio" name="imdburl" value="_2"';
    $out .= ' checked="checked"' unless $havehit;
    $out .= '/>'
      . '<input type="text" name="imdburl_2" style="width: 50%" value="' . escapeHTML($cururl) . '"/> '
      . '<input type="submit" value="Set IMDB Url"/>'
      . '</p>'
      . $hitout
      . '</form>';
    
    my $imdburl;
    if ($cururl) {
      $imdburl = $cururl;
    } elsif ($key eq 'sub-title') {
      (my $showid = $ddprogid) =~ s/\..*//;
      $getsth->execute($showid);
      $results = $getsth->fetchall_arrayref({});
      if ($results->[0]) {
        if ($stype eq 'list') {
          $imdburl = imdbidurl($results->[0]{imdb_id}) . 'episodes';
        } elsif ($stype eq 'title') {
          $imdburl = imdbepurl($prg_subtitle);
        }
      }
    }
    if (!defined $imdburl) {
      $imdburl = $key eq 'title' ? imdbturl($prg_title) : imdbepurl($prg_subtitle);
    }
    
    $out .= '<object type="text/html" class="iframe" data="'
      . escapeHTML($imdburl) . '" width="100%" height="480"/>'
        if !$fast;
  } else {
    my $imdburl = $q->param('imdburl');
    if ($imdburl =~ /^_\d+$/) {
      $imdburl = $q->param('imdburl' . $imdburl);
    }
    my $imdbid;
    if ($imdburl =~ /^[0-9]{7}$/) {
      $imdbid = $imdburl;
    } else {
      ($imdbid) = ($imdburl =~ m</title/tt([0-9]{7})>);
    }
    my $sth = $dbh->prepare_cached(SQL_DEL_IMDB);
    $sth->execute($ddprogid);
    my $didnew = !$sth->rows;
    $sth = $dbh->prepare_cached(SQL_INS_IMDB);
    $sth->execute($ddprogid, $imdbid);
    my $refreshurl = $didnew ? imdbidurl($imdbid) : ($q->param('back') || './');
    push @{$extra{hdrs}}, ['Refresh', '0.1;url=' . $refreshurl];
    
    $out .= 'IMDB URL Set';
  }
  
  $dbh->commit();
  
  $out .= pagefoot($r, $q);
  return {
    status => HTTP_OK,
    text => $out,
    %extra,
  };
}

1;
