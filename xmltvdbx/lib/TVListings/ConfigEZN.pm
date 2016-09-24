package TVListings::ConfigEZN;

use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT = qw{
  pagehead pagehead_mini pagehead_mobile
  pagefoot pagefoot_mini
  pagefilter
};

use EZNode::Render;

sub getcsslist($) {
  my ($r) = @_;
  my @csslist = map {TVListings::Config::CSSBASE() . "/$_"}
    TVListings::Config::CSSLIST();
  return wantarray ? @csslist : join(' ', @csslist);
}

sub pagehead($$$) {
  my ($r, $q, $title) = @_;
  my $csslist = getcsslist($r);
  return qq{<widget id=header title="$title" }
    . qq{stylesheets="$csslist" }
    . qq{doctype="xhtml10_strict">\n}
    . qq{<widget id=pagetop pagehead="$title" cdivexclass="smallmargin">\n}
    . TVListings::Config::searchinsert($r, $q, 0);
}

sub pagehead_mini($$$) {
  my ($r, $q, $title) = @_;
  my $csslist = getcsslist($r);
  return
      qq{<widget id=header title="$title" stylesheets="$csslist" }
    . qq{inlinecss="no" doctype="xhtml10_strict">\n}
    . qq{<widget id=pagetop mini=1 pagehead="$title" cdivexclass="smallmargin">\n};
}

sub pagehead_mobile($$$) {
  my ($r, $q, $title) = @_;
  my $csslist = getcsslist($r);
  return
      qq{<widget id=header title="$title" stylesheets="$csslist" }
    . qq{inlinecss="no" doctype="xhtml10_strict">\n}
    . qq{<widget id=pagetop mini=1 pagehead="$title" cdivexclass="nomargin">\n};
}

sub pagefoot($$) {
  my ($r, $q) = @_;
  return TVListings::Config::searchinsert($r, $q, 1)
    . qq{\n<widget id=footer w3cok=yes dynpage=yes>\n};
}

sub pagefoot_mini($$) {
  my ($r, $q) = @_;
  return qq{\n<widget id=footer w3cok=yes dynpage=yes mini=1>\n};
}

# pagefoot_mobile inherited

sub pagefilter($$$) {
  my ($r, $q, $pagedata) = @_;
  return EZNode::Render::render($pagedata);
}

1;
