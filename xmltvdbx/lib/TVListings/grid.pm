package TVListings::grid;

use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw{
	spanwidth
	render_row_header
	render_grid_cell
	rendernote
};
our %EXPORT_TAGS = (
	render => \@EXPORT_OK,
);

use Date::Parse;
use POSIX;
use Time::HiRes;

use Apache2::Const qw/:http/;
use CGI qw/escapeHTML/;
use CGI::Util qw/escape/;
use List::Util qw/min/;
use Scalar::Util qw/looks_like_number/;

use TVListings::DB qw/:default SQL_GRID SQL_GRID_THEN/;
use TVListings::Config;
use TVListings::Links;
use TVListings::search;

use constant MAX_TIPLEN => 150;

sub rendernote($\$) {
  my ($desc, $rtref) = @_;
  my $now = Time::HiRes::time;
  my $out = "<!-- $desc Render time: @{[$now - $$rtref]} -->\n";
  $$rtref = $now;
  return $out;
}

sub spanwidth($$) {
  return qq<colspan="$_[0]" style="width:@{[int $_[0]*$_[1]]}%">;
}

sub render_row_header($$$$$) {
  my ($r, $row, $cicons, $chancols, $offset) = @_;
  my $chanicon = $cicons->{$row->{chan_oid}};
  my ($iw, $ih);
  if ($chanicon) {
    ($iw, $ih) = @{$chanicon}{qw/icn_width icn_height/};
    $chanicon = $chanicon->{icn_src_file};
  }
  my $icnstr = '';
  $icnstr = chanlink($r, $row->{chan_oid}, qq{<img }
    . qq|src="@{[ICONSBASE]}/$chanicon" |
    . qq|alt="@{[escapeHTML($row->{chan_name})]}"|
    . (($iw and $ih) ? qq{ width="$iw" height="$ih"} : '')
    . '/>', {offset => $offset})
    if defined $chanicon;
  my $trclass = defined $chanicon ? 'hasicon' : 'noicon';
  return qq|</tr>\n<tr id="@{[escapeHTML($row->{chan_name})]}"|
    . qq{ class="chan $trclass __unclassified__">}
    . qq{<td class="icon">$icnstr</td>}
    . qq|<td class="chan" colspan="@{[$chancols-1]}">|
    . chanlink($r, $row->{chan_oid},
      qq{$row->{chan_number} $row->{chan_name}},
      {id => "chan_$row->{chan_number}_$row->{chan_name}",
        offset => $offset}, $row->{chan_name})
    . "</td>";
}

sub render_grid_cell($$$$$$$$) {
  my ($r, $row, $patts, $pint_class, $bayes_class, $tdsw, $rtimes, $offset)
    = @_;
  
  # collate extra information
  my (@tips, %exinfo, %genres);
  $genres{tv} = 1;
  foreach my $pa (@{$patts->{category}}) {
    my $gname = $pa;
    $gname =~ tr/A-Z/a-z/;
    $gname =~ tr/a-z//cd;
    $genres{$gname} = 1;
  }
  if ($patts->{rating}{MPAA}) {
    $genres{movie} = 1;
    $exinfo{rating} = $patts->{rating}{MPAA}[0];
  }
  push @tips, @{$patts->{title}} if $patts->{title};
  push @tips, @{$patts->{'sub-title'}} if $patts->{'sub-title'};
  if ($patts->{'episode-num'} and $patts->{'episode-num'}{onscreen}) {
    push @tips, "Ep#"
      . $patts->{'episode-num'}{onscreen}[0];
  }
  push @tips, @{$patts->{desc}} if $patts->{desc};
  my $tip = join(' -- ', @tips);
  if (length($tip) > MAX_TIPLEN) {
    $tip = substr($tip, 0, MAX_TIPLEN);
    $tip =~ s/(\s+)\S*$/${1}.../;
  }
  $tip = escapeHTML($tip);
  $exinfo{stars} = $patts->{'star-rating'}[0] if $patts->{'star-rating'};
  $exinfo{aspect} = $patts->{'video'}{'aspect'}[0]
    if $patts->{'video'} and $patts->{'video'}{'aspect'};
  $exinfo{hd} = 'HD' if $exinfo{'aspect'} and $exinfo{'aspect'} eq '16:9';
  $exinfo{audio} = $patts->{'audio'}{'stereo'}[0]
    if $patts->{'audio'} and $patts->{'audio'}{'stereo'};
  $exinfo{dd} = 'D' if $exinfo{audio} and $exinfo{audio} eq 'dolby';
  $exinfo{dd} = 'DD' if $exinfo{audio} and $exinfo{audio} eq 'dolby digital';
  
  # fetch any flagged interest
  if ($pint_class) {
    $genres{"interest_$pint_class"} = 1;
  } elsif ($bayes_class) {
    $genres{"bayes interest_$bayes_class"} = 1;
  } else {
    $genres{interest_none} = 1;
  }
  
  # the table cell
  my $prgtxt = ($rtimes->{prg_start} < $rtimes->{blk_start} ? '&lt; ' : '')
    . escapeHTML($row->{prg_title});
  my @exbits;
  for my $bit (qw/hd dd stars rating/) {
    push @exbits, $exinfo{$bit} if $exinfo{$bit};
  }
  $prgtxt .= ' <small>(' . escapeHTML(join(', ', @exbits)) . ')</small>'
    if @exbits;
  $prgtxt .= ($rtimes->{prg_stop} > $rtimes->{blk_end} ? ' &gt;' : '');
  # $genres{long} = 1 if length($prgtxt) > $show_width * 4;
  my $tdclass = join(' ', keys %genres);
  return qq{<td $tdsw class="$tdclass" title="$tip">}
    . prglink($r, $row->{prg_oid}, $prgtxt,
      $r->uri . '?' . ($r->args || '') . '#top')
    . "</td>";
}

sub classify ($%) {
  my ($buff, %seenclass) = @_;
  my @keys = (keys %seenclass);
  my @repl;
  push @repl, "all_$keys[0]" if $#keys == 0;
  my $best;
  for my $class (qw/hide bad crap normal good/) {
    $best = $class if $seenclass{$class};
  }
  push @repl, "best_$best" if defined $best;
  my $repl = join(' ', @repl);
  $buff =~ s/__unclassified__/$repl/g;
  return $buff;
}

sub render {
  my ($class, $r, $q, $dbh) = @_;
  
  my $lastchan = '';
  my $lastblkend = 0;
  my $cspctfct;
  my $skipped = 0;
  
  my $renderstart = Time::HiRes::time;
  my $renderstep = $renderstart;
  
  my $sth;
  my $offset = $q->param('offset');
  my $hidebad = $q->param('hidebad') || 0;
  # format check
  return {status => HTTP_BAD_REQUEST, text => 'Bad offset'}
    if $offset and !looks_like_number($offset);
  $offset = int($offset) if $offset;
  
  # before we start selecting, get our locks
  locktables_small($dbh);
  
  $sth = $dbh->prepare_cached(SQL_GRID_THEN);
  if ($offset) {
    $sth->execute($offset);
  } else {
    $sth->execute(0);
  }
  my $data = $sth->fetchall_arrayref({});
  
  my $offtitle = '';
  if ($offset) {
    my $offval = $offset;
    $offtitle = $offval < 0 ? " ago" : " from now";
    $offval = abs($offval);
    my @offbits;
    unshift @offbits, ($offval % 60) . " min" . ($offval % 60 > 1 ? 's' : '')
      if $offval % 60;
    $offval = int(($offval - $offval % 60) / 60);
    unshift @offbits, ($offval % 24) . " hour" . ($offval % 24 > 1 ? 's' : '')
      if $offval % 24;
    $offval = int(($offval - $offval % 24) / 24);
    unshift @offbits, $offval . " day" . ($offval > 1 ? 's' : '')
      if $offval;
    $offtitle = " - " . join(', ', @offbits) . $offtitle;
  }
  my $out = pagehead($r, $q, "TV Listings$offtitle");
  
  $out .= rendernote("Grid", $renderstep);
  
  my $all_patts = get_all_patts($dbh, $offset);
  
  $out .= rendernote("PAtts", $renderstep);
  
  #FIXME: handle odd case when no data returned
  
  # the forward/backward links
  my $argsinsert = $r->args;
  if ($argsinsert) {
    $argsinsert .= ';';
  } else {
    $argsinsert = '';
  }
  $argsinsert =~ s/([;]?)offset=\d+;/$1/;
  my $tvtimelinks = '<table class="tvtimelinks"><tr>'
    . '<td align="left"><a name="top" id="top" href="./?' . $argsinsert . 'offset='
      . (($offset ? $offset : 0) - 120) . '#top">&lt;&lt; Back</a></td>'
    . '<td align="right"><a href="./?' . $argsinsert . 'offset='
      . (($offset ? $offset : 0) + 120) . '#top">Forward &gt;&gt;</a></td>'
    . '</tr></table>';
  
  $out .= $tvtimelinks
    . '<table class="tvlistings">';
  
  # figure out the range of times returned
  my ($mintime, $maxtime) = (0, 0);
  for my $r (@$data) {
    my ($rstart, $rstop) = map {str2time($_)} @{$r}{qw/blk_start blk_end/};
    $mintime = $rstart if $mintime == 0 or $rstart < $mintime;
    $maxtime = $rstop if $maxtime == 0 or $rstop > $maxtime;
  }
  my $chancols = 3;
  my $ncols = int($chancols + ($maxtime - $mintime) / (5*60));
  $cspctfct = 100 / $ncols;
  $out .= qq{<tr class="hide">}
    . qq|<td @{[spanwidth $chancols, $cspctfct]}/>|
    . (qq|<td @{[spanwidth 1, $cspctfct]}/>| x ($ncols - $chancols)) . "</tr>";
  $out .= qq|<tr><th @{[spanwidth $chancols, $cspctfct]}>Channel</th>|;
  my $blktime = $mintime;
  while ($blktime < $maxtime) {
    my @blktimes = localtime($blktime);
    my $blkend = min($maxtime, $blktime + 30*60 - ($blktimes[1] % 30) * 60);
    my $blkstart = strftime("%H:%M", @blktimes);
    my $blkspan = ceil($blkend - $blktime) / (5*60);
    $out .= qq|<th @{[spanwidth($blkspan, $cspctfct)]}>$blkstart</th>|;
    $blktimes[1] += 30 - ($blktimes[1] % 30);
    $blktime = mktime(@blktimes);
  }
  
  $out .= rendernote('bounds', $renderstep);
  
#  my $prg_interest = get_all_prg_interest($dbh);
#  $out .= rendernote("Pint", $renderstep);
  
  my $cicons = get_all_cicon($dbh);
  $out .= rendernote("CIcon", $renderstep);
  
  my $buff = '';
  my $allhide = 1;
  my %seenclass;
  
  for my $row (@$data) {
    my %rtimes = map {$_ => str2time($row->{$_})}
      qw/prg_start prg_stop blk_start blk_end/;
    
    # channel row header
    if ($lastchan ne "$row->{chan_number} $row->{chan_name}") {
      $buff = classify($buff, %seenclass);
      $out .= $buff unless $allhide;
      $allhide = 1;
      %seenclass = ();
      $buff = render_row_header($r, $row, $cicons, $chancols, $offset);
      $lastchan = "$row->{chan_number} $row->{chan_name}";
      $lastblkend = $mintime;
    }
    
    # handle overlapping or disjoint shows
    if ($rtimes{blk_end} <= $lastblkend) {
      ++$skipped;
      $buff .= "<!-- skipped -->";
      next;
    } elsif ($rtimes{blk_start} > $lastblkend) {
      $buff .= "<!-- padding -->";
      my $spacer_width = int(($rtimes{blk_start} - $lastblkend) / (5*60));
      my $spacer_pct = int($spacer_width * $cspctfct);
      $buff .= qq|<td @{[spanwidth($spacer_width, $cspctfct)]}>|
        . qq|<small>No Data</small></td>|;
    } elsif ($rtimes{blk_start} < $lastblkend) {
      $buff .= "<!-- killing overlap -->";
      $rtimes{blk_start} = $lastblkend;
    }
    
    ######### RENDER IT ###############################################
    # table cell size info
    my $show_width = int(($rtimes{blk_end} - $rtimes{blk_start}) / (5*60));
    my $tdsw = spanwidth($show_width, $cspctfct);
    $buff .= render_grid_cell($r, $row, $all_patts->{$row->{prg_oid}},
      $row->{pint_class}, $row->{bayes_class}, $tdsw, \%rtimes, $offset); 
    ###################################################################
    
    $lastblkend = $rtimes{blk_end};
    $skipped = 0;
    
    my $rowclass = defined $row->{pint_class}
      ? $row->{pint_class} : $row->{bayes_class};
    $seenclass{$rowclass} = 1;
    $allhide = 0 if $rowclass ne 'hide' and (!$hidebad or $rowclass ne 'bad');
    
  }
  
  $buff = classify($buff, %seenclass);
  $out .= $buff unless $allhide;
  
  $tvtimelinks =~ s/"top"/"bottom"/g;
  $out .= "</tr>\n</table>\n" . $tvtimelinks;
  
  $out .= rendernote("Total", $renderstart);
  my $rtime = 300 - (time % 300);
  # don't refresh silly fast
  $rtime += 300 if $rtime < 15;
  $out .= "<!-- rtime = $rtime -->\n";
  
  $out .= pagefoot($r, $q);
  
  # make sure we save the bayes cache!
  $dbh->commit;
  
  return {
    hdrs => [['Refresh', $rtime]], # ;url=./
    status => HTTP_OK,
    text => $out,
  };
}

1;
