package TVListings::now;

use strict;
use warnings;

use Date::Parse;
use Apache2::Const qw/:http/;
use POSIX;
use Time::HiRes;

use TVListings::Config;
use TVListings::DB qw/:default SQL_NOW/;
use TVListings::grid qw/:render/;

sub render {
  my ($class, $r, $q, $dbh) = @_;
  
  my $renderstart = Time::HiRes::time;
  my $renderstep = $renderstart;
  
  # locks
  locktables_small($dbh);
  
  my $sth = $dbh->prepare_cached(SQL_NOW);
  $sth->execute;
  my $data= $sth->fetchall_arrayref({});
  
  my @now = localtime(time);
	my $nowstr = strftime("%H:%M", @now);

  my $out = pagehead_mini($r, $q, "On TV Now - $nowstr");
  
  $out .= rendernote('Grid', $renderstep);
  
  my $now_patts = get_now_patts($dbh);
  
  $out .= rendernote('PAtts', $renderstep);
  
  $out .= '<table class="tvlistings nowlistings">';
  
#  my $prg_interest = get_all_prg_interest($dbh);
  my $cicons = get_all_cicon($dbh);
  
  $out .= rendernote('CIcon', $renderstep);
  
  $out .= qq{<tr><th colspan="2">Channel</th><th colspan="3">Show</th></tr>\n};
  
  for my $row (@$data) {
    # skip junky shit to make sidebar short
    next if defined $row->{pint_class}
      and ($row->{pint_class} eq 'bad' or $row->{pint_class} eq 'hide');
    next if !defined $row->{pint_class} and defined $row->{bayes_class}
      and ($row->{bayes_class} eq 'bad' or $row->{bayes_class} eq 'hide');
#    next if $prg_interest->{$row->{prg_title}}
#      and $prg_interest->{$row->{prg_title}} eq 'bad';
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
  
  my $rtime = 300 - (time % 300);
  # don't refresh silly fast
  $rtime += 300 if $rtime < 15;
  $out .= pagefoot_mini($r, $q);
  
  # make sure we save the bayes cache
  $dbh->commit;
  
  return {
    hdrs => [['Refresh', $rtime]],
    status => HTTP_OK,
    text => $out,
  };
}


1;
