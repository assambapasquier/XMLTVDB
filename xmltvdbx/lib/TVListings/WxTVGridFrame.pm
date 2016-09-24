package TVListings::WxTVGridFrame;

use strict;
use warnings;

use Wx qw/:everything/;
use Wx::Event qw/:everything/;
use base qw/Wx::Frame/;
use Hash::Util qw/lock_keys/;

sub new {
  my ($class, $dbh) = @_;
  my $config = Wx::ConfigBase::Get;
  my $x = $config->ReadInt('/TVGrid/x', -1);
  my $y = $config->ReadInt('/TVGrid/y', -1);
  my $w = $config->ReadInt('/TVGrid/w', -1);
  my $h = $config->ReadInt('/TVGrid/h', -1);
  my $this = $class->SUPER::new(undef, -1, "xmltvdb-gui", [$x, $y], [$w, $h],
    wxDEFAULT_FRAME_STYLE, "xmltvdb_tvgrid");
  bless $this, $class;
  
  $this->{dbh} = $dbh;
  $this->{iconsdir} = $config->Read('/xmltv/iconsdir',
    '/usr/share/xmltv/icons');
  
  $this->{scrl} = Wx::ScrolledWindow->new($this, -1);
  $this->{scrl}->SetScrollbars(1, 1, 1, 1);
  $this->{fgs} = Wx::FlexGridSizer->new(0, 4);
  
  $this->_setup_pgrid;
  
  $this->{scrl}->SetSizer($this->{fgs});
  
  EVT_SIZE($this, \&SaveSize);
  EVT_MOVE($this, \&SaveSize);
  $this->{uptmr} = Wx::Timer->new($this);
  my $uprate = $config->ReadFloat('/TVGrid/delay', 5);
  $config->WriteFloat('/TVGrid/delay', $uprate);
  $this->{uptmr}->Start(int($uprate*1000), 0);
  EVT_TIMER($this, $this->{uptmr}->GetId, \&_setup_pgrid);
  
  lock_keys(%$this);
  
  return $this;
}

sub SaveSize {
  my ($this, $evt) = @_;
  my ($x, $y) = $this->GetPositionXY;
  my ($w, $h) = $this->GetSizeWH;
  my $config = Wx::ConfigBase::Get;
  $config->WriteInt('/TVGrid/x', $x);
  $config->WriteInt('/TVGrid/y', $y);
  $config->WriteInt('/TVGrid/w', $w);
  $config->WriteInt('/TVGrid/h', $h);
  $evt->Skip;
}

sub _setup_pgrid {
  my $this = shift;
  $this->{fgs}->DeleteWindows;
  while ($this->{fgs}->GetChildren) {
    $this->{fgs}->Remove(0);
  }
  
  my $config = Wx::ConfigBase::Get;
  my $data = $this->{dbh}->selectall_arrayref(
    "SELECT * FROM active_shows NATURAL LEFT JOIN chan_icons
      NATURAL LEFT JOIN prg_interest
      WHERE prg_start <= now() AND prg_stop > now()
      ORDER BY chan_number ASC, chan_name ASC",
    {Slice => {}});
  for my $row (@$data) {
    $row->{pint_class} = 'normal' if !$row->{pint_class};
    next if $row->{pint_class} eq 'bad';
    my $hiderow = $config->ReadBool('/Channels/hide/' . $row->{chan_name}, 0);
    $config->WriteBool('/Channels/hide/' . $row->{chan_name}, $hiderow);
    next if $hiderow;
    if ($row->{icn_src}) {
      my $src = $row->{icn_src};
      $src =~ s{^file://}{};
      $this->{fgs}->Add(Wx::StaticBitmap->new($this->{scrl}, -1,
        Wx::Bitmap->new($src, wxBITMAP_TYPE_ANY)), 0,
        wxALL | wxALIGN_CENTER, 2);
    } else {
      $this->{fgs}->Add(1, 1, 0);
    }
    my @lbls;
    push @lbls, Wx::StaticText->new($this->{scrl}, -1, $row->{chan_number});
    push @lbls, Wx::StaticText->new($this->{scrl}, -1, $row->{chan_name});
    push @lbls, Wx::StaticText->new($this->{scrl}, -1, $row->{prg_title});
    my $font = $lbls[0]->GetFont;
    $font->SetWeight(wxBOLD) if $row->{pint_class} eq 'good';
    $font->SetStyle(wxITALIC) if $row->{pint_class} eq 'crap';
    for my $n (0 .. $#lbls) {
      $lbls[$n]->SetFont($font);
      my $flags = wxALL | wxALIGN_CENTER_VERTICAL;
      $flags |= wxALIGN_RIGHT if $n == 0;
      $this->{fgs}->Add($lbls[$n], 0, $flags, 2);
    }
  }
  $this->{fgs}->FitInside($this->{scrl});
  $this->Layout;
}

1;
