package TVListings::mobile;

use strict;
use warnings;

use Date::Parse;
use Apache2::Const qw/:http/;
use POSIX;
use Time::HiRes;
use List::Util qw/first/;

use TVListings::Config;
use TVListings::DB qw/:default SQL_GRID_MOBILE/;
use TVListings::grid qw/:render/;

sub render {
  my ($class, $r, $q, $dbh) = @_;
  
  my $renderstart = Time::HiRes::time;
  my $renderstep = $renderstart;
  
  # locks
  locktables_small($dbh);
  
  my $sth = $dbh->prepare_cached(SQL_GRID_MOBILE);
  $sth->execute;
  my $data= $sth->fetchall_arrayref({});
  
  my $now5 = time;
  $now5 += 300 - ($now5 % 300) if $now5 % 300 != 0;
  my $nowstr = strftime("%H:%M", localtime($now5));
  my $out = pagehead_mobile($r, $q, "On TV - $nowstr");
  
  $out .= rendernote('Grid', $renderstep);
  
  my $now_patts = get_now_patts($dbh);
  
  $out .= rendernote('PAtts', $renderstep);
  
  $out .= '<table class="tvlistings nowlistings mobilelistings">';
  
#  my $prg_interest = get_all_prg_interest($dbh);
  my $cicons = {};
  # no cicons for mobile
#  my $cicons = get_all_cicon($dbh);
#  for my $ci (values %$cicons) {
#    $ci->{icn_width} /= 2;
#    $ci->{icn_height} /= 2;
#  }
  
  $out .= rendernote('CIcon', $renderstep);
  
  $out .= qq{<tr><th colspan="2">Channel</th><th colspan="3">Show</th></tr>\n};
  
  for my $row (@$data) {
    next if $row->{pint_class}
      ? $row->{pint_class} eq 'hide' : $row->{bayes_class} eq 'hide';
    my %rtimes = map {$_ => str2time($row->{$_})} qw/prg_start prg_stop/;
    $rtimes{blk_start} = $rtimes{prg_start};
    $rtimes{blk_end} = $rtimes{prg_stop};
    $out .= render_row_header($r, $row, $cicons, 2, 0);
    $out .= render_grid_cell($r, $row, $now_patts->{$row->{prg_oid}},
      $row->{pint_class}, $row->{bayes_class}, 'colspan="3"', \%rtimes, 0);
  }
  $out .= '</tr></table>';
  
  $out .= rendernote('Table', $renderstep);
  $out .= rendernote('Total', $renderstart);
  
  my $rtime = 600 - (time % 600);
  # refresh early
  $rtime -= 60;
  # don't refresh silly fast
  $rtime += 300 if $rtime < 60;
  $out .= pagefoot_mobile($r, $q);
  
  # make sure we save the bayes cache
  $dbh->commit;
  
  return {
    hdrs => [['Refresh', $rtime]],
    status => HTTP_OK,
    text => $out,
  };
}


1;
