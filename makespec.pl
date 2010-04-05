#!/usr/bin/perl

use strict;

my $want_mrst = 0;
my $want_netbook = 0;
my $want_ivi = 0;
my $want_menlow = 0;
my $want_n900 = 0;


sub do_Patch
{
  my $patchcounter = 1;
  open MYFILE, "<series" || die "Cannot open series\n";;
  while (<MYFILE>) {
    my $line = $_;
    chomp($line);
    if ($line =~ /\@\@x/) {
        next;
    }
    if ($line =~ /\@\@X/) {
        if ($want_mrst < 1) {
          last;
        }
        $patchcounter = 1001;
        next;
    }
    # we print comment lines
    if ($line =~/^#/ || length($line) < 4) {
      print "$line\n";
      next;
    }
    
    # ok now we have a patch
    print "Patch$patchcounter: $line\n";
    $patchcounter = $patchcounter + 1;
  }
  close MYFILE;
}

sub do_patch
{
  my $patchcounter = 1;
  open MYFILE, "<series" || die "Cannot open series\n";;
  while (<MYFILE>) {
    my $line = $_;
    chomp($line);
    if ($line =~ /\@\@x/) {
        next;
    }
    if ($line =~ /\@\@X/) {
        if ($want_mrst < 1) {
          last;
        }
        $patchcounter = 1001;
        next;
    }
    # we print comment lines
    if ($line =~/^#/ || length($line) < 4) {
      print "$line\n";
      next;
    }
    
    # ok now we have a patch
    print "# $line\n";
    print "\%patch$patchcounter -p1\n";
    $patchcounter = $patchcounter + 1;
  }
  close MYFILE;
}


if ( -e "./MRST") {
  $want_mrst = 1;
}
if ( -e "./IVI") {
  $want_ivi = 1;
}
if ( -e "./MENLOW") {
  $want_menlow = 1;
}
if ( -e "./NETBOOK") {
  $want_netbook = 1;
}

if ( -e "./N900") {
  $want_n900 = 1;
}

while (<>) {
  my $line = $_;
  chomp($line);
  
  if ($line =~ /\@\@/) {

    # Moorsetown only lines
    if ($want_mrst > 0 && $line =~ /\@\@M (.*)/) {
        print "$1\n";
        next;
    }
    if ($want_netbook > 0 && $line =~ /\@\@N (.*)/) {
        print "$1\n";
        next;
    }
    if ($want_ivi > 0 && $line =~ /\@\@I (.*)/) {
        print "$1\n";
        next;
    }
    if ($want_n900 > 0 && $line =~ /\@\@A (.*)/) {
        print "$1\n";
        next;
    }
    if ($want_menlow > 0 && $line =~ /\@\@W (.*)/) {
        print "$1\n";
        next;
    }
    # Patch directive
    if ($line =~ /\@\@P/) {
        do_Patch();
        next;
    }
    # patch directive
    if ($line =~ /\@\@p/) {
        do_patch();
        next;
    }
  } else {
    print "$line\n";
  }

}
