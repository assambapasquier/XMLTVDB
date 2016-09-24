package TVListings::show;

use strict;
use warnings;

use Apache2::Const qw/:http/;

use POSIX;
use Date::Parse;
use CGI qw/escapeHTML/;

use TVListings::Config;
use TVListings::DB qw/:default SQL_PINFO SQL_CNAME SQL_GET_IMDB/;
use TVListings::Links;

our %patt_renderers = (
  title => sub { $_[1]{patt_value} },
  'sub-title' => sub {'<h2>' . escapeHTML($_[1]{patt_value}) . '</h2>'},
  desc => sub {'<p>' . escapeHTML($_[1]{patt_value})
    . '</p>'},
  category => [sub {'<dt>Category</dt><dd>' . join(', ',
    map {escapeHTML($_->{patt_value})} @{$_[0]}) . '</dd>'}],
  'episode-num' => [sub {
    my $o = '<dt>Episode Number</dt><dd>';
    my @e;
    for my $s (sort keys %{$_[0]}) {
      push @e, map {escapeHTML($_->{patt_value}) . ' ('
        . escapeHTML($s) . ')'} @{$_[0]{$s}};
    }
    $o .= join('<br/>', @e);
    $o .= '</dd>';
    return $o;
  }],
  rating => [sub {
    my $o = '';
    for my $k (sort keys %{$_[0]}) {
      if ($k eq 'MPAA') {
        $o .= join('', map {
            my $im = lc($_->{patt_value});
            $im =~ tr/a-z0-9//cd;
            my $alt = escapeHTML($_->{patt_value});
            qq|<img class="rating" src="@{[IMAGESBASE]}/rate_${im}.gif" |
              . qq{alt="$alt" title="$alt"/>}
          } @{$_[0]{$k}});
      } elsif ($k eq 'VCHIP') {
        $o .= join('', map {
            my $im = uc($_->{patt_value});
            $im =~ s/^TV-//;
            $im =~ tr/A-Z0-9//cd;
            my $alt = escapeHTML($_->{patt_value});
            qq|<img class="rating" src="@{[IMAGESBASE]}/tv${im}.gif" |
              . qq{alt="$alt" title="$alt"/>}
          } @{$_[0]{$k}});
      }
    }
    return $o;
  }],
  'star-rating' => sub {
    my $r = Apache2::RequestUtil->request;
    my $ipfx = '';
    $ipfx = 'mobile_' if $r->headers_in->{'User-Agent'} =~ /blazer/i;
    my $o = qq{<span style="padding-left:1em" }
      . qq|title="@{[escapeHTML($_[1]{patt_value})]}">|;
    my ($s, $t) = ($_[1]{patt_value} =~ /^([0-9.]+)\/(\d+)$/);
    for my $i (1 .. $t) {
      my $im;
      if ($i <= $s) {
        $im = 'full';
      } elsif ($i - 1 < $s) {
        $im = 'half';
      } else {
        $im = 'empty';
      }
      $o .= qq{<img class="star" alt="$im" }
        . qq|src="@{[IMAGESBASE]}/${ipfx}star_${im}.png"/>|;
    }
    $o .= '</span>';
    return $o;
  },
  subtitles => sub {'<dt>Subtitles</dt><dd>' . escapeHTML($_[1]{patt_value})
    . '</dd>'},
  date => sub {'<dt>Original Air Date</dt><dd> '
    . escapeHTML($_[1]{patt_value}) . '</dd>'},
  'previously-shown' => sub {'<dd>Repeat</dd>'},
  credits => [sub {
    my $o = '<dl class="showatts">';
    for my $credit (sort keys %{$_[0]}) {
      (my $cname = $credit) =~ s/^(.)/uc($1)/e;
      $cname .= 's' if $#{$_[0]{$credit}} > 0;
      $o .= '<dt>' . escapeHTML($cname)
        . '</dt><dd>' . join(', ', map {personlink($_->{patt_value})}
        @{$_[0]{$credit}}) . '</dd>';
    }
    $o .= '</dl>';
    return $o;
  }],
  audio => sub {sprintf '<dt>Audio</dt><dd>%s: %s</dd>', escapeHTML($_[0]),
    escapeHTML($_[1]{patt_value})},
  video => sub {sprintf '<dt>Video</dt><dd>%s: %s</dd>', escapeHTML($_[0]),
    escapeHTML($_[1]{patt_value})},
  length => sub {'<dt>Running Time</dt><dd>' . escapeHTML($_[1]{patt_value})
    . ' minutes</dd>'},
  
);
sub render {
  my ($class, $r, $q, $dbh) = @_;
  
  # pagehead gets put in later
  my $out = '<div class="showinfo">';
  
  if (!$q->param('prg')) {
    $out = pagehead($r, $q, "TV Show Details")
      . '<i>No prorgram specified</i><br/></div>' . pagefoot($r, $q);
    return { status => HTTP_BAD_REQUEST, text => $out };
  }
  
  my $backurl = $q->param('back') || './#top';
  
  # get our locks
  locktables_small($dbh);
  
  my $pisth = $dbh->prepare_cached(SQL_PINFO);
  $pisth->execute($q->param('prg'));
  my $pinfo = $pisth->fetchall_arrayref({});
  if ($#$pinfo > 0) {
    $out .= '<i>Multiple programs hit? Only showing first one</i><br/>';
  } elsif ($#$pinfo < 0) {
    $out = pagehead($r, $q, "TV Show Details")
      . '<i>No program found</i><br/></div>' . pagefoot($r, $q);
    return { status => HTTP_OK, text => $out };
  }
  $pinfo = $pinfo->[0];
  my $patts = get_patts($dbh, $pinfo->{prg_oid});
  my $cnsth = $dbh->prepare_cached(SQL_CNAME);
  $cnsth->execute($pinfo->{chan_oid});
  my $cinfo = $cnsth->fetchall_arrayref({})->[0];
  my $cname = "$cinfo->{chan_number} $cinfo->{chan_name}";
  my $cicon = get_cicon($dbh, $pinfo->{chan_oid});
  my ($iw, $ih) = @{$cicon}{qw/icn_width icn_height/};
  
  #FIXME: fetch icons for program and ratings? na_dd doesn't output any
  
  my $searchlink = '';
  my $prg_title = '';
  
  my @attorder = qw/title star-rating rating sub-title desc credits category
      episode-num date previously-shown audio video length/;
  my @ignoredatts = qw/subtitles/;
  
  for my $att (@attorder) {
    
    # capture the title for links and stuff
    # start top heading
    if ($att eq 'title') {
      $prg_title = $patts->{title}[0]{patt_value};
      $searchlink = 'Other airings '
        . searchlink($prg_title, '[Title]');
      if (exists $patts->{'episode-num'}{dd_progid}) {
        my $ddprogid = $patts->{'episode-num'}{dd_progid}[0]{patt_value};
        my @ddbits = split (/\./, $ddprogid);
        my $ddtype = $ddbits[0] =~ /^MV/ ? 'Movie' : 'Show';
        $searchlink .= ' ' . searchlink($ddbits[0], "[$ddtype]");
        $searchlink .= ' ' . searchlink("$ddbits[0].$ddbits[1]", '[Episode]')
          if $#ddbits > 0 and $ddbits[1] ne '0000';
        
        my $imdblinks = '';
        my $imdbeditlinks = '';
        
        my $back = $r->uri . '?' . ($r->args || '');
        
        my $imdbsth = $dbh->prepare_cached(SQL_GET_IMDB);
        $imdbsth->execute($ddbits[0]);
        my $imdbinfo = $imdbsth->fetchall_arrayref({});
        my $haveshow = $imdbinfo->[0] ? 1 : 0;
        if ($haveshow) {
          $imdblinks .= ' ' . imdbidlink($imdbinfo->[0]{imdb_id}, '[IMDB]');
          $imdbeditlinks .= ' ' . imdbeditlink($q->param('prg'), 'title', '[Edit IMDB]', back => $back);
        } else {
          $imdblinks .= ' ' . imdbeditlink($q->param('prg'), 'title', '[IMDB]', back => $back, fast => 1);
        }
        if ($#ddbits > 0 and $ddbits[1] ne '0000') {
          $imdbsth->execute($ddprogid);
          $imdbinfo = $imdbsth->fetchall_arrayref({});
          my $haveep = $imdbinfo->[0] ? 1 : 0;
          # can't do fast on an ep title yet
          $imdblinks .= ' ' . imdbidlink($imdbinfo->[0]{imdb_id}, '[IMDB Ep]') if $haveep;
          if ($haveshow) {
            $imdbeditlinks .= ' ' . imdbeditlink($q->param('prg'), 'sub-title', '[Edit IMDB Ep', back => $back, stype => 'list');
            $imdbeditlinks .= ' ' . imdbeditlink($q->param('prg'), 'sub-title', 'Alt]', back => $back, stype => 'title');
          } else {
            $imdbeditlinks .= ' ' . imdbeditlink($q->param('prg'), 'sub-title', '[Edit IMDB Ep]', back => $back, stype => 'title');
          }
        }
        $searchlink .= ' Info ' . $imdblinks . '<br/><span style="font-size: smaller">' . $imdbeditlinks . '</span>';
      }
      $out .= '<h1>';
    }
    
    # end top heading after star-rating
    if ($att eq 'sub-title') {
      $out .= '</h1>';
    }
    
    # insert some special stuff before the description
    if ($att eq 'desc') {
      $out .= '<div style="margin-left:1em">'; # info block
      $out .= chanlink($r, $pinfo->{chan_oid},
        qq|<img src="@{[ICONSBASE]}/$cicon->{icn_src_file}" |
        . qq|alt="@{[escapeHTML($cname)]}"|
        . (($iw and $ih) ? qq{ width="$iw" height="$ih"} : '')
        . ' style="vertical-align:middle"/>', undef, $cinfo->{chan_name})
          if $cicon->{icn_src_file};
      $out .= chanlink($r, $pinfo->{chan_oid}, $cname, undef,
        $cinfo->{chan_name});
      $out .= ' ';
      my ($pstart, $pstop) = map {escapeHTML(strftime("%a %b %e %H:%M",
        strptime($_)))} @{$pinfo}{qw/prg_start prg_stop/};
      $out .= qq{<span style="font-size: smaller;padding-left:2em">}
        . qq{$pstart - $pstop</span><br/>};
      $out .= qq{<div style="font-size:smaller;padding-left:4em">}
        . $searchlink . '</div>';
      # split showatts into two columns
      $out .= '<table class="cols"><tr><td class="col" style="width:66%">';
      #$out .= '<dl class="showatts">'; # show info
    }
    
    # col break between credits and category
    if ($att eq 'category') {
      $out .= '</td><td class="col" style="width:34%">'
        . '<dl class="showatts">';
    }
    
    # advisory is a magic item
#    if ($att eq 'advisory' and defined $patts->{rating}
#        and defined $patts->{rating}{advisory}) {
#      $out .= '<dt>Advisory</dt><dd>'
#        . join(', ', map {$_->{patt_value}} @{$patts->{rating}{advisory}})
#        . '</dd>';
#    }
    
    next if !$patts->{$att};
    
    if (ref($patt_renderers{$att}) eq 'ARRAY') {
      $out .= $patt_renderers{$att}[0]->($patts->{$att}, $r, $q, $dbh);
    } elsif (ref($patts->{$att}) eq 'HASH') {
      for my $satt (sort keys %{$patts->{$att}}) {
        $out .= $patt_renderers{$att}->($satt, $_, $r, $q, $dbh) foreach @{$patts->{$att}{$satt}};
      }
    } else {
      $out .= $patt_renderers{$att}->(undef, $_, $r, $q, $dbh) foreach @{$patts->{$att}};
    }
  }
  
  delete $patts->{$_} for @attorder;
  delete $patts->{$_} for @ignoredatts;
  
  # now that we have the prg title, prepend the header
  $out = pagehead($r, $q, "TV Show Details - $prg_title") . $out;
  
  $out .= '</dl>'; # end show info dl
  $out .= '</td></tr></table>'; # end two column
  $out .= '</div>'; # end info block
  
  my @pintclass = get_cv_pint_class($dbh);
  my $pint_cur = get_prg_interest($dbh, $prg_title);
  my @bayes_details = get_bayes_details($dbh, $pinfo->{prg_oid});
  
  # 2col for bottom table
  $out .= qq{<table class="cols"><tr><td class="col" style="width:66%">};
  
  $out .= qq{<form method="post" action="./edit"><div>}
    . qq{<input type="hidden" name="prg_title" value=\"}
      # hack to make utf8 stuff pass through right, we convert the title
      # to octets
      . escapeHTML($prg_title) . qq{\"/>}
    . qq{<input type="hidden" name="prg_oid" value=\"}
      . escapeHTML($pinfo->{prg_oid}) . qq{\"/>}
    . qq{<input type="hidden" name="returl" value=\"}
      . escapeHTML($backurl)
      . qq{\"/>}
    . qq{<b>Interest:</b> <select name="pint_class">}
    . qq{<option value="">&lt;none&gt;</option>}
    . join('', map {
        qq{<option value="$_"}
        . ($_ eq escapeHTML($pint_cur) ? qq{ selected="selected"} : '')
        . qq{>$_</option>}
      } map {escapeHTML($_)} @pintclass)
    . qq{</select> }
    #. qq{<input class="submit" type="submit" name="action" value="Flag it"/> }
    . qq{<input class="submit" type="submit" name="action" value="Learn it"/> }
    . qq{<small>}
    . qq{<input class="checkbox" type="checkbox" name="relearn" id="relearn" value="1"/><label for="relearn">Re-Learn</label>}
    . qq{<input class="checkbox" type="checkbox" name="fullbayes" id="fullbayes" value="1"/><label for="fullbayes">Full Update</label>}
    . qq{</small>}
    . qq{</div></form>};
  
  $out .= qq{</td><td class="col" style="width:34%">}; # next column
  
  $out .= q{<table class="prg_bayes">}
    . q{<caption>Bayes Info</caption>}
    . q{<tr><th>Interest</th><th>Ranking</th><th># Tokens</th></tr>};
  for my $bayes_info (@bayes_details) {
    $out .= q{<tr>} . join('', map {'<td>' . escapeHTML($_) . '</td>'}
      $bayes_info->{pint_class}, sprintf('%.4f', $bayes_info->{bayes_prob}),
      $bayes_info->{num_toks}) . '</tr>';
  }
  $out .= q{</table>};
  
  $out .= qq{</td></tr></table>}; # end 2col for bottom table
  
  if (scalar keys %$patts) {
    $out .= 'Extra Info:<br/><table border="1">';
    
    sub outrow {
      return '<tr>' . join('',
        map {'<td>' . escapeHTML(defined $_ ? $_ : '') . '</td>'} @_)
        . "</tr>\n";
    }
    
    for my $att (sort keys %$patts) {
      if (ref($patts->{$att}) eq 'HASH') {
        foreach my $satt (sort keys %{$patts->{$att}}) {
          foreach my $av (@{$patts->{$att}{$satt}}) {
            $out .= outrow($att, $satt, @{$av}{qw/patt_lang patt_value/});
          }
        }
      } else {
        foreach my $av (@{$patts->{$att}}) {
          $out .= outrow($att, '', @{$av}{qw/patt_lang patt_value/});
        }
      }
    }
    
    $out .= '</table>';
  }
  
  $out .= '</div>'; # end showinfo
  
  $out .= pagefoot($r, $q);
  
  return {
    status => HTTP_OK,
    text => $out,
  };
}

