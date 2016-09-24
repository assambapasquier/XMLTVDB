package TVListings::WxApp;

use strict;
use warnings;

use Wx qw/:everything/;
use base qw/Wx::App/;
use Hash::Util qw/lock_keys/;
use TVListings::WxTVGridFrame;
use TVListings::DB qw/getdbh/;

sub OnInit {
  my $this = shift;
  $this->{dbh} = getdbh(1);
  $this->{config} = Wx::FileConfig->new('xmltvgui', 'fastcat.org', "", "",
    wxCONFIG_USE_LOCAL_FILE);
  Wx::ConfigBase::Set($this->{config});
  Wx::InitAllImageHandlers;
  my $frame = TVListings::WxTVGridFrame->new($this->{dbh});
  $this->SetTopWindow($frame);
  $frame->Show(1);
  lock_keys(%$this);
  return 1;
}

sub OnExit {
  my $this = shift;
  Wx::ConfigBase::Set(undef);
  $this->{config}->Flush;
  $this->{config} = undef;
  return 1;
}

sub GetAppName {
  return 'xmltvgui';
}

1;
