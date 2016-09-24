package TVListings::modperl;

# mod_perl specific bits for tvlistings
# copied mostly from gallery
# copied mostly from eznode

use strict;
use warnings;

use Apache2::RequestUtil;
use Apache2::Const qw(:common);
use CGI;
use CGI::Util qw(escape);
use Encode qw/from_to/;

use TVListings::chan;
use TVListings::edit;
use TVListings::grid;
use TVListings::imdb;
use TVListings::mobile;
use TVListings::now;
use TVListings::search;
use TVListings::show;
use TVListings::DB qw/getdbh/;
use TVListings::Config;

our %modes = map {$_ => 1} qw/grid now mobile show chan search edit imdb/;

sub handler($$) {
  my ($pkg, $r) = (@_ > 1) ? @_ : (__PACKAGE__, shift);
  
  # make request available to other modules
  Apache2::RequestUtil->request($r);
  
  # never cache any output, since it's all dynamic from the database
  $r->no_cache(1);
  
  my ($root, $path);
  my $loc = $r->location;
  if ($r->uri =~ m{^(\Q$loc\E)(/(.*?))?/?$}) {
    $root = $1;
    $path = $3;
    $path = '' unless defined $path;
  } else {
    return DECLINED;
  }
  
  #FIXME: catch die's, log as errors, return internal server error
  my @reqpath = split('/', $path);

  my $mode = $#reqpath == -1 ? 'grid' : $reqpath[0];
  die "invalid mode '$mode'" if !defined $modes{$mode};
  my $renderer = "TVListings::$mode";
  
  # add trailing slashes and redirect if needed
  if ($mode eq 'grid' and $r->uri !~ m{/$}) {
    my $fixed = $r->uri . '/';
    $fixed .= '?' . $r->args if $r->args;
    $r->headers_out->set(Location => $fixed);
    $r->status(REDIRECT);
    return OK;
  }

  #FIXME: give proper 404's for bad urls
  # this requires passing the header_only flag to renderers
  # and then letting them return either the text, or a status code
  
  $r->content_type('text/html');
  #FIXME: this is a bad hack until proper header/retstatus handling
  # can be done
  if ($r->header_only) {
    return OK;
  }
  
  # simulate filename for some bits to print good values
  my $simfname = $renderer;
  $simfname =~ s/::/\//g;
  $simfname .= '.pm';
  $simfname = $INC{$simfname};
  $r->filename($simfname);
  
  my $q = new CGI;
  my $dbh = getdbh();
  my $rout = $renderer->render($r, $q, $dbh);
  $dbh->rollback;
  
  die "broken renderer $renderer" if ref($rout) ne 'HASH';
  
  for my $ho (@{$rout->{hdrs}}) {
    $r->headers_out->add($ho->[0], $ho->[1]);
  }
  for my $eho (@{$rout->{errhdrs}}) {
    $r->err_headers_out->add($eho->[0], $eho->[1]);
  }
  $r->status($rout->{status});
  if ($rout->{text}) {
    # from utf8 octents to iso-8859-1 octets
    from_to($rout->{text}, 'utf8', 'iso-8859-1');
    # workaround for some things escapeHTML misses
    $rout->{text} =~ s/(.)/ord($1)>128?"&#@{[ord($1)]};":$1/eg;
    $r->print(pagefilter($r, $q, $rout->{text}));
  }
  return OK;
}

1;
