package TVListings::edit;

use strict;
use warnings;

use Apache2::Const qw/:http/;
use CGI qw/escapeHTML/;
use Encode;

use TVListings::Config;
use TVListings::DB qw/:default
  SQL_DEL_INTEREST SQL_INS_INTEREST SQL_BAYES_UPDATE SQL_BAYES_RELEARN
  SQL_BAYES_FULL SQL_BAYES_DEL SQL_BAYES_CLEAR/;

sub render {
  my ($class, $r, $q, $dbh) = @_;
  my $out = pagehead($r, $q, "TV Show Edit - @{[$q->param('prg_title')]}")
    . '<br/>';
  
  my $fail = 0;
  if (!$q->param('prg_title')) {
    $out .= 'Bad prg title';
    $fail = 1;
  } elsif (!$q->param('prg_oid')) {
    $out .= 'Bad prg_oid';
    $fail = 1;
  } elsif (!$q->param('action') or $q->param('action') !~ /flag|learn/i) {
    $out .= 'Bad action';
    $fail = 1;
  } else {
    # lock tables first
    locktables_big($dbh);
    
    my $prg_title = decode('iso-8859-1', $q->param('prg_title'));
    my $prg_oid = $q->param('prg_oid');
    my $action = $q->param('action');
    # we need to convert prg_title back to utf8 octets (not string!)
    my $ptoctets = encode('utf8', $prg_title);
    eval {
      my $sth;
      if ($action =~ /flag/i) {
        $sth = $dbh->prepare_cached(SQL_DEL_INTEREST);
        $sth->execute($ptoctets);
        if ($q->param('pint_class')) {
          $sth = $dbh->prepare_cached(SQL_INS_INTEREST);
          $sth->execute($ptoctets, $q->param('pint_class'));
        }
      }
      if ($q->param('pint_class')) {
        if ($q->param('relearn')) {
          $sth = $dbh->prepare_cached(SQL_BAYES_RELEARN);
          $sth->execute($q->param('pint_class'), $ptoctets);
        }
        $sth = $dbh->prepare_cached(SQL_BAYES_UPDATE);
        $sth->execute($prg_oid, $ptoctets, $q->param('pint_class'));
        $sth->fetchall_arrayref(); # discard output
      } else {
        $sth = $dbh->prepare_cached(SQL_BAYES_DEL);
        $sth->execute($prg_oid);
        if ($q->param('relearn')) {
          $sth = $dbh->prepare_cached(SQL_BAYES_CLEAR);
          $sth->execute($ptoctets);
        }
      }
      if ($q->param('fullbayes')) {
        $sth = $dbh->prepare_cached(SQL_BAYES_FULL);
        $sth->execute();
        $sth->fetchall_arrayref(); # discard output
      }
      $dbh->commit;
      my $ac = $dbh->{AutoCommit};
      $dbh->{AutoCommit} = 1;
      # analyze tables for fast execution plans
      for my $table (qw/bayes_cache bayes_toks p_pint_mv p_tok_given_pint_mv
          pint_count_mv tok_count_by_pint_mv tok_total_mv/) {
        $dbh->do("ANALYZE @{[XMLTVSCHEMA]}.$table");
      }
      $dbh->{AutoCommit} = $ac;
    };
    if ($@) {
      $out .= "failed interestizing:<br/><tt>" . escapeHTML($@) . "</tt>";
      $fail = 1;
    } else {
      $out .= "Interest/bayes for '" . escapeHTML($ptoctets) . "' saved<br/>";
    }
  }
  
  $out .= pagefoot($r, $q);
  
  my %ret = (
    status => HTTP_OK,
    text => $out,
  );
  $ret{hdrs} = [['Refresh', '0.1;url=' . ($q->param('returl') || './')]]
    unless $fail;
  return \%ret;
}

1;
