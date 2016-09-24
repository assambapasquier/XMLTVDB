package TVListings::Links;

use strict;
use warnings;

use CGI qw/escapeHTML/;
use CGI::Util qw/escape/;

use base qw/Exporter/;
our @EXPORT = qw/chanlink prglink searchlink attsearchlink
  imdbturl imdbtlink imdbnlink personlink imdbidurl imdbidlink
  imdbeditlink imdbepurl/;

sub chanlink($$$;$$) {
  my ($r, $chanid, $text, $extra, $channame) = @_;
  my $id;
  $id = escapeHTML($extra->{id}) if defined $extra->{id};
  my $offset = $extra->{offset};
  my $atitle = "View Channel Listings";
  $atitle .= " For $channame" if $channame;
  $atitle = escapeHTML($atitle);
  return qq{<a }
    . (defined $id ? qq{id="$id" name="$id" } : '')
    . qq{href=\"./chan?chan=$chanid}
    . ($offset ? ";offset=$offset" : '')
    . qq{\" title="$atitle">$text</a>};
}

sub prglink($$$;$) {
  my ($r, $prgid, $text, $back) = @_;
  return qq{<a id="prg_$prgid" name="prg_$prgid" }
    . qq{href=\"./show?prg=@{[escapeHTML(escape($prgid))]}}
    . (defined $back ? ";back=@{[escapeHTML(escape($back))]}" : '')
    . qq{\">$text</a>};
}

sub searchlink($$) {
  my ($query, $text) = @_;
  return qq|<a href="./search?q=@{[escapeHTML(escape($query))]}" |
    . qq{title="Search info in TV Listings">$text</a>};
}

sub imdbturl($) {
  return "http://imdb.com/find?tt=on;mx=20;q=" . escape($_[0]);
}

sub imdbtlink($;$) {
  my $imdburl = escapeHTML(imdbturl($_[0]));
  return q{<a href="} . $imdburl . '" title="Search Title on IMDB">'
    . ($_[1] || escapeHTML($_[0])) . '</a>';
}

sub imdbnlink($;$) {
  return q{<a href="http://imdb.com/find?nm=on;mx=20;q=}
    . escape($_[0]) . '" title="Search Name on IMDB">'
    . ($_[1] || escapeHTML($_[0])) . '</a>';
}

sub imdbepurl($) {
  return 'http://imdb.com/find?s=tt;ttype=ep;q=' . escape($_[0]);
}

sub imdbidurl($) {
  return "http://imdb.com/title/tt$_[0]/";
}

sub imdbidlink($$) {
  return qq{<a href="} . escapeHTML(imdbidurl($_[0]))
    . qq{" title="IMDB Page">} . escapeHTML($_[1]) . '</a>';
}

sub imdbeditlink($$$%) {
  my ($prgid, $key, $text, %args) = @_;
  my $link = qq{<a href="./imdb?prg=} . escapeHTML(escape($prgid))
    . ';key=' . escapeHTML(escape($key));
  $link .= ';back=' . escapeHTML(escape($args{back})) if $args{back};
  $link .= ';stype=' . escapeHTML(escape($args{stype})) if $args{stype};
  $link .= ';fast=' . $args{fast} if defined $args{fast};
  my $linktitle = 'Edit IMDB';
  $linktitle .= " ($args{stype})" if $args{stype};
  $link .= '" title="' . escapeHTML($linktitle) . '">' . escapeHTML($text) . '</a>';
  return $link;
}

sub personlink($) {
  return escapeHTML($_[0]) . '<sup>' . imdbnlink($_[0], "[i]")
    . searchlink($_[0], "[a]") . '</sup>';
}

1;
