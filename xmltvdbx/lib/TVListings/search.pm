package TVListings::search;

use strict;
use warnings;

use Apache2::Const qw/:http/;

use CGI qw/escapeHTML/;
use Date::Parse;
use POSIX;
use List::Util qw/min max/;

use TVListings::DB qw/:default SQL_SEARCH SQL_SEARCH_PINT SQL_SEARCH_LIMIT/;
use TVListings::Config;
use TVListings::Links;

use constant EMFACTOR => 6;

sub render_form {
	my ($class, $r, $q) = @_;
	
	my $sval = $q->param('q');
	$sval = '' if !defined $sval;
	$sval = escapeHTML($sval);
	my $out = qq{<form method="get" action="./search"><div>}
		. qq{<input class="text" type="text" name="q" value="$sval"/> }
		. qq{<input class="submit" type="submit" value="Search Shows"/>}
		. qq{</div></form>};
	
	return $out;
}

sub fmtmins($) {
	my ($mins) = @_;
	my $hrs  = floor($mins / 60);
	$mins %= 60;
	my $days = floor($hrs / 24);
	$hrs %= 24;
	my $out;
	$out .= "${days}d" if $days;
	$out .= "${hrs}h" if $hrs;
	$out .= "${mins}m" if $mins;
	return $out;
}

sub render {
	my ($class, $r, $q, $dbh) = @_;
	
	my @hdrs;
	
	my $srchmode = 'q';
	my $srch = $q->param('q');
	my $sql = SQL_SEARCH;
	if (!defined $srch) {
		$srchmode = 'i';
		$srch = $q->param('int');
		$sql = SQL_SEARCH_PINT;
		my $rtime = 300 - (time % 300);
		# don't refresh silly fast
		$rtime += 300 if $rtime < 15;
		push @hdrs, ['Refresh', $rtime];
	}
	
	my @navcells = ('', '', '');
	my $sres = [];
	
	if ($srch =~ /^\s*$/) {
		$navcells[1] .= "No Search Terms";
	} else {
		my $fullurl = $r->uri . '?' . $r->args;
		my $off = $q->param('startat');
		if ($off and $off =~ /^\d+$/ and $off > 0) {
			$sql .= " OFFSET $off";
			my $prevoff = $off - SQL_SEARCH_LIMIT;
			$prevoff = 0 if $prevoff < 0;
			(my $prevurl = $fullurl) =~ s/startat=\d+/startat=$prevoff/;
			$prevurl =~ s/[&;]startat=0// if $prevoff == 0;
			$prevurl = escapeHTML($prevurl);
			$navcells[0] .= qq{<a href="$prevurl">&lt;&lt; Prev</a>};
		} else {
			$off = 0;
		}
		my $ssth = $dbh->prepare_cached($sql);
		$ssth->execute($srch);
		$sres = $ssth->fetchall_arrayref({});
		
		if (@$sres) {
			$navcells[1] .= ($#$sres + 1) . ' Results';
			if ($#$sres == SQL_SEARCH_LIMIT - 1) {
				$navcells[1] =~ s/(\d+)( Results)/$1+$2/;
				my $nextoff = $off + SQL_SEARCH_LIMIT;
				my $nexturl = $fullurl;
				if ($nexturl =~ /startat=/) {
					$nexturl =~ s/startat=\d+/startat=$nextoff/;
				} else {
					$nexturl .= ";startat=$nextoff";
				}
				$nexturl = escapeHTML($nexturl);
				$navcells[2] .= qq{<a href="$nexturl">Next &gt;&gt;</a>};
			}
		} else {
			$navcells[1] .= 'No results';
		}
	}
	
	my $pgsubtitle;
	if ($srchmode eq 'q') {
		$pgsubtitle = $q->param('q');
	} else {
		$pgsubtitle = $q->param('int');
		$pgsubtitle =~ s/^(.)/\U$1\E/;
		$pgsubtitle = "The $pgsubtitle Stuff";
	}
	my $out = pagehead($r, $q, "TV Listings Search Results - "
		. escapeHTML($pgsubtitle));
	
	my $navtxt = qq{<table class="center" width="100%" border="0">}
		. qq{<tr><td style="width:33%;text-align:left">$navcells[0]</td>}
		. qq{<td style="text-align:center;font-style:italic">$navcells[1]</td>}
		. qq{<td style="width:33%;text-align:right">$navcells[2]</td></tr>}
		. qq{</table>};
	
	$out .= $navtxt;
	$out .= qq{<table class="tvlistings sres">}
		. qq{<tr><th colspan="2" style="width:10%">Channel</th>}
		. qq{<th style="width:30%">Show</th>}
		. qq{<th style="width:15%">Show Start</th>}
		. qq{<th colspan="2" style="width:45%">Duration</th></tr>} if @$sres;
	my $mindelta = min(map {$_->{delta}} @$sres);
	my $maxend = max(map {$_->{duration} + $_->{delta}} grep {$_->{delta} <= 0}
		@$sres);
	
	for my $row (@$sres) {
		my $chanicon = get_cicon($dbh, $row->{chan_oid});
		my $icnstr = '';
		if ($chanicon) {
			my ($iw, $ih) = @{$chanicon}{qw/icn_width icn_height/};
			$icnstr = chanlink($r, $row->{chan_oid}, qq{<img }
				. qq{src="@{[ICONSBASE]}/$chanicon->{icn_src_file}" }
				. qq{alt="@{[escapeHTML($row->{chan_name})]}"}
				. (($iw and $ih) ? qq{ width="$iw" height="$ih"} : '')
				. '/>', undef, $row->{chan_name}) . ' ';
		}
		my $prgstr = prglink($r, $row->{prg_oid}, escapeHTML($row->{prg_title}),
			$r->uri . '?' . ($r->args || ''));
		my $chanstr = chanlink($r, $row->{chan_oid},
			escapeHTML("$row->{chan_number} $row->{chan_name}"), undef,
			$row->{chan_name});
		my ($pstart, $pstop) = map {escapeHTML(strftime("%a %b %e %H:%M",
			strptime($_)))} @{$row}{qw/prg_start prg_stop/};
		my $fillm = $row->{delta} < 0 ? -$row->{delta} : 0;
		my $emptym = $row->{duration} + ($row->{delta} < 0 ? $row->{delta} : 0);
		my ($fillem, $emptyem) = map {sprintf "%.2f", $_ / EMFACTOR}
			($fillm, $emptym);
		my @durtds;
		if ($row->{delta} < 0) {
			$durtds[0] = ['pbar_past',
				qq{<td style="width:${fillem}em">@{[fmtmins $fillm]}</td>}];
		} else {
			$durtds[0] = ['', undef];
		}
		$durtds[1] = [$row->{delta} <= 0 ? 'pbar_now' : 'pbar_future',
			qq{<td style="width:${emptyem}em">@{[fmtmins $emptym]}</td>}];
		my $durtds = join('', map { qq{<td class="pbar $_->[0]">}
			. (defined $_->[1] ? qq{<table><tr>$_->[1]</tr></table>} : '')
			. '</td>'} @durtds);
		$out .= qq{<tr><td class="icon">$icnstr</td>}
			. qq{<td class="chan">$chanstr</td>}
			. join('', map {
					($row->{delta} > 30 ? qq{<td class="small">} : '<td>')
					. ($row->{delta} <= 0 ? "<b>$_</b>" : $_)
					. "</td>"
				} $prgstr, "$pstart ("
					. ($row->{delta} <= 0 ? 'On Now'
						: "Starts in " . fmtmins($row->{delta})
					) . ')'
			)
			. $durtds
			. "</tr>";
	}
	
	$out .= "</table>";
	$out .= $navtxt if @$sres;
	
	$out .= pagefoot($r, $q);
	return {
		hdrs => \@hdrs,
		status => HTTP_OK,
		text => $out,
	};
}

1;
