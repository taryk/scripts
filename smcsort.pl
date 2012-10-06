#!/usr/bin/env perl
use common::sense;

use File::Basename qw[dirname basename fileparse];
use File::Path     qw[mkpath];
use File::Copy     qw[move];
use File::Find;
use Music::Tag;
use Pod::Usage;
use Digest::MD5;
use Getopt::Long;

use Sys::Syslog qw(:DEFAULT :macros);

use Carp qw[croak carp confess];
use Data::Printer;

# use lib dirname(__FILE__).'/libs';

BEGIN {
  openlog $0, 'ndelay,pid', 'local4';
  syslog(LOG_INFO, 'started');
}

END {
  syslog(LOG_INFO, 'finished');
  closelog;
}

my %archs   = ( 'rar' => 'unrar x %src% %dst%'  ,
                'zip' => 'unzip %src% -d %dst%' ,
                '7z'  => '7z -e %src -o %dst%'  );

my @track_ext = qw[ mp3 flac ogg ];

my $unpack    = 0;
my $to        = '/tmp/smcsort/music/';
my $unpack_to = '/tmp/smcsort/unpacked/';
my $pattern   = '/%artist%/%year%_-_%album%/%track_number%_-_%artist%_-_%track_name%.%ext%';

GetOptions(
  'debug'       => \my $debug,
  'from=s@'     => \my @from,
  'to=s'        => \$to,
  'verbose'     => \my $verbose,
  'delete'      => \my $delete,
  'noimages'    => \my $noimages,
  'unpack'      => \$unpack,
  'overwrite'   => \my $overwrite,
  'unpack-to=s' => sub { $unpack=1; $unpack_to=$_[1] },
  'usage|?'     => sub { pod2usage(1) },
  'help'        => sub { pod2usage(-exitstatus => 0, verbose => 2) },
) or pod2usage(2);

sub process() {
  for my $item (@from) {
    if ($unpack) {
      if ( -f $item and
           grep { $_ eq substr $item, -length } keys %archs )
      {
        main::process_archive($item);
      }
      elsif ( -d $item ) {
        File::Find::find(\&process_archive_cb, $item)
      }
      main::process_dir($unpack_to);
    }
    else {
      if    (-f $item) { main::process_file($item) }
      elsif (-d _)     { main::process_dir($item)  }
      else  { }
    }
  }
  move_files(files_hash())
}

sub process_dir($) {
  my $dir = shift;

  File::Find::find(\&process_file_cb, $dir);
}

sub process_archive_cb {
  my $path = $File::Find::name;
  process_archive($path);
}

sub process_archive($) {
  my $file = shift;
  while ( my ($ext, $cmd) = each %archs) {
    next unless $ext eq substr $file, -length $ext;
    my $unpack_dir = $unpack_to . '/' . basename $file;
    mkpath($unpack_dir) unless -d $unpack_dir;
    $cmd =~ s/\%src\%/quotemeta($file)/ex;
    $cmd =~ s/\%dst\%/quotemeta($unpack_dir)/ex;
    say $cmd;
    system $cmd;
    last;
  }
}

{ my %files = ();
  my $prev  = { dir  => undef,
                info => undef };
  my $first_track     = 0;
  my $various_artists = 0;

  sub files_hash()    { \%files };

  sub process_file($) {
    my $file = shift;
    return unless grep { $_ eq substr $file, -length } @track_ext;
    my $info = eval { Music::Tag->new($file)->get_tag } || do {
      printf "Can't get tags from file '%s'\n" => $file;
      return;
    };
    push @{ $files{$files{$info->album}}{tracks} } => {
      info => $info,
      file => $file,
    };
    $files{$info->album}{various_artists} = 0;
    return $info;
  }

  sub process_file_cb {
    return unless grep { $_ eq substr $File::Find::name, -length } @track_ext;

    if ($File::Find::dir ne $prev->{dir}) {
      $prev->{dir} = $File::Find::dir;
      $first_track = 1;
    } else { $first_track = 0 }

    return unless -f $File::Find::name;

    my $info = process_file $File::Find::name or return;
    if (not $first_track
        and lc $info->artist eq lc $prev->{info}->artist)
    {
      $various_artists = 1;
    }
    $files{$info->album}{various_artists} = $various_artists;
    $prev->{info} = $info;
    $prev->{first_track} = $first_track;
  }

}

sub md5_compare($$) {
  open(FL0, $_[0])
    or die sprintf "can't open '%s': [%d]: %s" => $_[0], $!, $!;
  binmode FL0;

  open(FL1, $_[1])
    or die sprintf "can't open '%s': [%d]: %s" => $_[1], $!, $!;
  binmode FL1;

  my $res = Digest::MD5->new->addfile(*FL0)->hexdigest eq
            Digest::MD5->new->addfile(*FL1)->hexdigest;

  close FL0;
  close FL1;

  return $res;
}

sub move_files($) {
  for my $album ( values %{ $_[0] } ) {
    for my $track ( @{ $album->{tracks} } ) {
      my $dest = $to.'/'.format_filepath($track->{info}, va => $album->{va});
      while (-f $dest) {
        printf "file '%s' already exists\n" => $dest;
        if ( -s $dest eq -s $track->{file}
             and md5_compare $dest => $track->{file})
        {
          printf "files '%s' and '%s' are the same.\n",
                 $dest => $track->{file};
          last;
        }
        else {
          $dest .= '.2' unless $dest =~ s/\.(\d+)$/++$1/e;
        }
      }
      my ($filename, $filepath) = fileparse $dest;
      unless ($debug) {
        mkpath $filepath
          unless -d $filepath;
        move($track->{file} => $dest);
      }
      printf  "move: '%s' => '%s'\n",
           $track->{file} => $dest;
    }
  }
}

sub format_filepath($@) {
  my $info = shift;
  my %options = @_;
  my $result;
  if ($options{va}) {
    my ($pattern_filename, $pattern_path) = fileparse $pattern;
    $pattern_path =~ s/%artist%/Various_Artists/g;
    $result = $pattern_path.'/'.$pattern_filename;
  }
  else { $result = $pattern }
  $result =~ s/%artist%/$info->artist/eg;
  $result =~ s/%album%/$info->album/eg;
  $result =~ s/%year%/$info->year/eg;
  if ($info->track) {
    $result =~ s/%track_number%/sprintf("%02d",$info->track)/eg;
  } else {
    $result =~ s/%track_number%_\-_//g;
  }
  $result =~ s/%track_name%/$info->title/eg;
  $result =~ s/%genre%/$info->genre/eg;
  $result =~ s/%ext%/mp3/g;
  $result =~ s/\s/\_/g;
  $result
}

process;

__END__

=head1 NAME

smcsort

=head1 SYNOPSIS

smcsort --verbose --unpack --from /source/path0 /source/path1 --to /usr/path2

smcsort --verbose --delete --unpack --from /source/path0 /source/path1 --to /usr/path2

smcsort --verbose --from /source/path0 /source/path1 --to /usr/path2

smcsort --verbose --from /source/path0/file0.mp3 /source/path1/file1.mp3 --to /usr/path2

smcsort --verbose --delete --from /source/path0/file0.mp3 /source/path1/file1.mp3 --to /usr/path2

=head1 OPTIONS

=over 8

=item --verbose

=item --unpack

=item --from

=item --to

=item --delete

=item --help

=item --unage

=back

=head1 DESCRIPTION

The script for sorting your music collection

=head1 AUTHOR

(c) 2012 Taras Yagniuk <mrtaryk@gmail.com>

=cut
