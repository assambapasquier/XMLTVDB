package TVListings::chan;

use strict;
use warnings;

use Apache2::Const qw/:http/;

use CGI qw/escapeHTML/;
use Date::Parse;
use POSIX qw/strftime/;

use TVListings::DB qw/:default SQL_CHAN_SHOWS/;
use TVListings::Config;
use TVListings::Links;

sub render {
  my ($class, $r, $q, $dbh) = @_;
  my $cinfo = get_cinfo($dbh, $q->param('chan'));
  my $chanoid = $cinfo->{chan}{chan_oid};
  my $offset = $q->param('offset') || 0;
  my $out = pagehead($r, $q, "TV Channel Info - $cinfo->{name}");
  $out .= "<h1>" . escapeHTML($cinfo->{name});
  if ($cinfo->{icon}) {
    my ($iw, $ih) = @{$cinfo->{icon}}{qw/icn_width icn_height/};
    $out .= ' <img src="' . ICONSBASE . qq[/$cinfo->{icon}{icn_src_file}" ]
      . 'alt="' . escapeHTML($cinfo->{name}) . '"'
      . (($iw and $ih) ? qq{ width="$iw" height="$ih"} : '')
      . '/>';
  }
  $out .= '</h1><p>'
    . "Chan ID: $cinfo->{chan}{chan_id}<br/>";
  for my $an (sort keys %{$cinfo->{atts}}) {
    $out .= $an;
    $out .= 's' if $#{$cinfo->{atts}{$an}} > 0;
    $out .= ': ' . join(', ', map {escapeHTML($_)}
      @{$cinfo->{atts}{$an}}) . '<br/>';
  }
  $out .= '</p>';

  my $ssth = $dbh->prepare_cached(SQL_CHAN_SHOWS);
  $ssth->execute($chanoid, $offset);
  my $sres = $ssth->fetchall_arrayref({});
  
  my $hrefstart = "./chan?chan=" . $chanoid;
  my $tvtimelinks = '<table class="tvtimelinks"><tr>'
    . qq{<td align="left"><a name="top" id="top" href=\"$hrefstart;offset=}
      . (($offset ? $offset : 0) - 1440) . '#top">&lt;&lt; Back</a></td>'
    . qq{<td align="right"><a href=\"$hrefstart;offset=}
      . (($offset ? $offset : 0) + 1440) . '#top">Forward &gt;&gt;</a></td>'
    . '</tr></table>';
  
  $out .= $tvtimelinks;
  
  if (@$sres) {
    $out .= qq{<table class="tvlistings sres">}
      . qq{<tr><th colspan="2" style="width:10%">Channel</th>}
      . qq{<th style="width:60%">Show</th>}
      . qq{<th style="width:15%">Show Start</th>}
      . qq{<th style="width:15%">Show End</th></tr>\n};
  } else {
    $out .= '<i>No shows</i>';
  }

  my $chanicon = get_cicon($dbh, $chanoid);
  my ($iw, $ih) = @{$chanicon}{qw/icn_width icn_height/};

  for my $row (@$sres) {
    my $icnstr = '';
    $icnstr = chanlink($r, $row->{chan_oid}, qq{<img }
      . 'src="' . ICONSBASE . qq[/$chanicon->{icn_src_file}" ]
      . 'alt="' . escapeHTML($row->{chan_name}) . '"'
      . (($iw and $ih) ? qq{ width="$iw" height="$ih"} : '')
      . '/>', {offset => $offset}, $row->{chan_name}) . ' '
        if defined $chanicon;
    my $prgstr = prglink($r, $row->{prg_oid}, escapeHTML($row->{prg_title}),
      $r->uri . '?' . $r->args);
    my $chanstr = chanlink($r, $row->{chan_oid},
      escapeHTML("$row->{chan_number} $row->{chan_name}"),
      {offset => $offset}, $row->{chan_name});
    my ($pstart, $pstop) = map {escapeHTML(strftime("%a %b %e %H:%M",
      strptime($_)))} @{$row}{qw/prg_start prg_stop/};
    $out .= qq{<tr class="chan hasicon"><td class="icon">$icnstr</td>}
      . qq{<td class="chan">$chanstr</td>}
      . qq{<td class="tv">$prgstr</td>}
      . qq{<td class="small">$pstart</td>}
      . qq{<td class="small">$pstop</td>}
      . "</tr>\n";
  }
  
  $out .= "</table>\n" if @$sres;
  
  $tvtimelinks =~ s/"top"/"bottom"/g;
  $out .= $tvtimelinks;
  
  $out .= pagefoot($r, $q);
  return {
    status => HTTP_OK,
    text =>$out,
  };
}

1;
