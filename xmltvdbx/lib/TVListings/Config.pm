package TVListings::Config;

use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT = qw{
  XMLTVDBI XMLTVSCHEMA ICONSBASE IMAGESBASE
  searchinsert
  pagehead pagehead_mini pagehead_mobile
  pagefoot pagefoot_mini pagefoot_mobile
  pagefilter
};

use CGI qw/escapeHTML/;
use CGI::Util qw/escape/;

=head1 NAME

TVListings::Config

=head1 DESCRIPTION

Contains local configuration settings for how to connect to the database and
how to display pages.  You will certainly need to edit this file to
customize it for your local installation.

=head1 STUFF TO CUSTOMIZE

=over 4

=item XMLTVDBI

An array that contains the DBI connection parameters.  You will want to
change the first three (the DBI connect string, user, and password,
respectively), but you should leave the connection options alone unless you
are really really sure you know what you're doing.

=cut

use constant XMLTVDBI => (
  'dbi:Pg:dbname=xmltv',
  'postgres',
  'AZaz09!@zX',
  {
    AutoCommit => 0,
    RaiseError => 1,
    FetchHashKeyName => 'NAME_lc',
  },
);

=item XMLTVSCHEMA

The name of the schema within the database that xmltv will query against

=cut

use constant XMLTVSCHEMA => 'xmltv';

=item ICONSBASE

A constant defining the URL path base that should be used for the channel
icons.  In the html, the src attribute of the img elements will be composed
as ICONSBASE/imgfile.ext.

=cut

use constant ICONSBASE => '/images/xmltv-icons';

=item IMAGESBASE

A constant defining the URL path base for the images that come with this
package

=cut

use constant IMAGESBASE => '/images/tvlistings';

=item CSSBASE

A constant defining the url path base for the CSS files tvlistings will
pull in.

=cut

use constant CSSBASE => '/include/tvlistings';

=item CSSLIST

A constant of all the css files to pull in.

=cut

use constant CSSLIST => (qw/tvlistings.css tvprefs.css tvcolors.css/);

=item sub searchinsert($$)

You probably won't need to customize it, but if you're curious, it takes a
request, a cgi object, and an instance count as parameters, and returns the
html for the basic navigation and search bar that appears at the top and
bottom of each page.  The instance count should be 0 for tie first render
(top), 1 for the second (bottom)

=cut

sub searchinsert($$$) {
  my ($r, $q, $instance) = @_;
  my $homeurl = "./";
  $homeurl .= "?offset=@{[escape $q->param('offset')]}"
    if $q->param('offset') and $r->uri !~ /\/$/;
  $homeurl .= '#top';
  $homeurl = escapeHTML($homeurl);
  return qq|
    <table class="tvlinks tvlinks${instance}"><tr>
      <td align="left"><b><a href="$homeurl">TV Home</a></b></td>
      <td align="center"><b><a href="./?hidebad=true">
        Just The Good Stuff</a></b></td>
      <td class="right">
        @{[TVListings::search->render_form($r, $q)]}
      </td>
    </tr></table>
  |;
}

=item sub pagehead($$$)

Generates and returns the beginning of the page, from the DOCTYPE
declaration through to where tv listing content will begin.  You will need
to customize this.

Arguments are Apache request object, CGI object, and the page title.

Return value should the the page header content.

=item sub pagehead_mini($$$)

Same as pagehead, but for 'mini' pages that might be used in a sidebar.
Should remove any header and footer links, or whatever.

=cut

# declare up front to allow either one to call the other
sub pagehead($$$);
sub pagehead_mini($$$);
sub pagehead_mobile($$$);

sub pagehead($$$) {
  my ($r, $q, $title) = @_;
  return pagehead_mini($r, $q, $title) . searchinsert($r, $q, 0);
}

sub pagehead_mini($$$) {
  my ($r, $q, $title) = @_;
  my @csslist = map {CSSBASE . "/$_"} CSSLIST;
  return qq{
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
      <head>
      <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1"/>
      <meta name="Author" content="xmltvdb/TVListings"/>
    }
    . join('', map{qq{<link rel="stylesheet" href="$_" type="text/css"/>}}
      @csslist)
    . "<title>" . escapeHTML($title) . "</title></head><body>";
}

sub pagehead_mobile($$$) {
  my ($r, $q, $title) = @_;
  return pagehead_mini($r, $q, $title);
}

=item sub pagefoot($$)

Generates and returns the end of the page, from the end of the tv listings
content through to the end of the HTML document.  You will need to customize
this function.

Arguments are the Apache request object and the CGI object.

Return value should be the page footer content.

=cut

sub pagefoot($$) {
  my ($r, $q) = @_;
  return searchinsert($r, $q, 1) . qq{</body></html>};
}

=item sub pagefoot_mini($$)

Same idea as pagehead_mini, but for the footer.

=cut

sub pagefoot_mini($$) {
  my ($r, $q) = @_;
  return qq{</body></html>};
}

sub pagefoot_mobile($$) {
  my ($r, $q) = @_;
  return TVListings::search->render_form($r, $q) . pagefoot_mini($r, $q);
}

=item sub pagefilter($$$)

Final page content filter.  Just before sending the full generated page to
the client, its content will be passed through this filter.  You can use
this to pass it through any templating or other content adjustment tool you
want.

Arguments are the Apache request object, the CGI object, and the page
content to be filtered.

Return value should be the filtered page content.

=cut

sub pagefilter($$$) {
  my ($r, $q, $pagedata) = @_;
  $pagedata =~ s/\s+/ /sg;
  return $pagedata;
}

=back

=head1 AUTHOR

Matthew "Cheetah" Gabeler-Lee <cheetah@fastcat.org>

=cut

# evil hacking: if EZNode is available, replace vanilla with it
# if you are customizing this file for your own uses, don't worry about this
# you can delete it if you want, or leave it in if you don't care
BEGIN {
  eval "use EZNode::modperl ()";
  if (!$@) {
    eval "require TVListings::ConfigEZN";
    # funky hack to avoid warnings
    no strict 'refs';
    no warnings 'redefine';
    for my $sym (@TVListings::ConfigEZN::EXPORT) {
      *{__PACKAGE__."::$sym"} = \&{"TVListings::ConfigEZN::$sym"};
    }
  }
}

1;
