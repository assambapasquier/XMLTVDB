#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use TVListings::WxApp;
use DBI;

my $app = TVListings::WxApp->new;
$app->MainLoop;
