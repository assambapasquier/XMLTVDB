=head1 NAME

TVListings Installation Instructions

=head1 DATABASE

=head2 SERVER

TVListings requires a relatively recent copy of PostgreSQL to host its data
and DBD::Pg to access it.

=head2 SCHEMA

A SQL/DDL script is included for creating the TVListings database schema.

=head2 CONNECTION

You'll need to edit the XMLTVDBI item in Config.pm to set the DBI connection
parameters.  The perldoc there should explain what needs changing.

=head1 BASIC HTML FORMATTING

Again, read the perldoc on Config.pm, use the sample code included, and
write your code for how you want the page around the tv listings to look.

The TVListings code will generate XHTML 1.0 Transitional compliant output,
and you are encouraged to keep to this in the html you wrap around this,
including the DOCTYPE declaration.  Not keeping to this may cause browsers
to go into quirks mode and not render the default stylesheet properly.

Nearly all of the formatting of the tv listing is done via CSS.  A default
stylesheet based upon what I personally use is included, but it only
includes the style items for the tvlisting items, not the whole page.  This
makes it easy for inclusion into an existing site via the @import
declaration, but means that you must do some extra work if you want this to
stand alone.

=head1 APACHE CONFIGURATION

You will need at least Perl 5.8.x for proper Unicode support, and some
version of mod_perl and Apache.  The Perl bits of TVListings need to be
placed somewhere mod_perl can find them.  By default <directory of
httpd.conf>/lib/perl is in the include path, so I recommend you place the
files there, or symlink that location to another location where you want to
store your mod_perl modules.

Then you will need to add something like the following to your httpd.conf:

 <Location /tv>
   SetHandler perl-script
   PerlModule Apache::DBI
   PerlHandler TVListings::modperl
 </Location>

I also strongly suggest that you add some access control limits to the
TVListings pages.  If you want leave the listings open, but restrict the
database-modifying pages, you can put the access restrictions within a
<Location /tv/edit> section.

=cut
