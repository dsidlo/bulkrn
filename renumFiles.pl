#!/usr/bin/perl

#
# Renumber files.
#

use Getopt::Long;

use strict;

my ($fnPat, $reNums, $seqOpt, $helpOpt, $testOpt, $verbOpt, $fmtOpt);

my $retGetOpts = GetOptions ( "fileRegExp|f=s" => \$fnPat,   # The file name regexp.
			      "reNums|r=s"     => \$reNums,  # br:n1|n1-n2:n3
			      "help|h"         => \$helpOpt, # Force Sequence Option
			      "test|t"         => \$testOpt, # Only do a test
			      "format|d=s"     => \$fmtOpt,  # Use a format string
			      "verbose|v"      => \$verbOpt, # Verbose Output
    );


if ($helpOpt) {
    print << "_EOF_";

renumFiles.pl - ReNumber Files

  Renumbers and renames numeric portions of files in the current directory.

  usage: renumFiles.pl [-h|-t|-v] -f [regexpWith2BackRefs] -r [br:n1|n1-n2:n3]

  Requires that the first argument, be defined as a pattern that matched to
  a set of files names of interest, where the pattern returns 3 back-reference
  values. The parameter br is the Back Reference value which will be changed
  into a new number.

  '(mwlog\\.wfiebj)(\\d+)(\\..*)'
    ^------------  ^--- ^--- 
    |              |    |
    |              |    +---: BackRef \$3 -> \$fn1
    |              +--------: BackRef \$2 -> \$fn2
    +-----------------------: BackRef \$1 -> \$fn3

  The 2nd back-reference value returned must be a numeric value.
  This numberic value is compared against n1. And, if there is a match, n1 is
  substitued with the value of n2. And the new file name is built...

  \$newFn = \$fn1.(\$fn+(n2-n1)).\$fn3;

  The --reNum|-r parameter consists of... [br:n1|n1-n2:n3]

  br: Back Reference value that is the numberic value that will be changed.
  n1: The first numeric value that will be changed.
  n2: The last  numeric value that will be changed.
  n3: The numberic value that n1 will be changed to.
      Subsequent values will be changed to n2+(n3-n1) incrementing the value
      by the difference between n1 and n3.

  ** If n1 is specified without n2, all values from n1 and greater are changed
     to the new value. 
     If n1 and n2 exist with a dash between them all values between n1 and n2
     inclusive are changed to a new value.

  example: renumFiles.pl -f '(mwlog\\.wfiebj)(\\d+)(\\..*)' -r 2:5:15 

  Above, only n1 and n3 are specified as options, all $2 back-reference values that
  match 5 and above will be incrmented by 10. 

  example: renumFiles.pl -f '(mwlog\\.wfiebj)(\\d+)(\\..*)' -r 2:5-7:15

  Above, n1-n2 and n3 are specified as options, only $2 back-reference values that
  match 5 thru 7 are incrmented by 10. 

  The rename process watches for file name overlap conditions what would cause
  a file to be overwritten and lost. If such conditions are found, the process aborts
  after undoing all file renames that had been done thus far.

  Other options:

  --format | -d <Leading Zeros Format Length>
  Format the new numberic value with leading zeros to a length of n.
  example: -d 5

  --help | -h
  Output this help text.


  --test | -t
  Test the renumbering/renaming process against the filenames in the current directory.

  --verbose | -v
  Print details of the renaming process.


_EOF_

    exit;

}

my ($br, $n1, $n2, $n3);
($br,$n1,$n3) = split(':', $reNums);

if ($n1 =~ m/\-/) {
    ($n1,$n2) = split('-', $n1);
}

if ( ($br !~ /\d+/) || ($n1 !~ /\d+/) || ($n2 !~ /(\d+|)/) || ($n3 !~ /\d+/) ) {
    die "Renumber Values Must be Integers! [br:n1|n1-n2:n3]\n";
}

if (($br > 3) || ($br < 1)) {
    die "Back Reference Value must be LessThan 3 and GreaterThan 1! [br]\n";
}

if ($n2) {
    die "Parameter Error [n1-n2:n3] n2 must be greater than n1!\n" if ($n2 <= $n1);
}

my $nDiff = $n3 - $n1;

opendir(my $DF, "./") || die "Could not opendir './'!\n";
my @allfiles = readdir($DF);

my (%rn2, %rn3);
my @rnDone;

if ($testOpt) {
    
    my %testRns;

    foreach my $fn (@allfiles) {
	$testRns{$fn} = $fn;
    }

    foreach my $fn (sort (grep m/${fnPat}/, @allfiles)) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    # print "==> $fn\n";
	    my $fn1 = $1;
	    my $fn2 = $2;
	    my $fn3 = $3;

	    die "The Filename RegExp must return at least 1 Back Reference.\n" if (($br == 1) && ($fn1 eq ''));
	    die "The Filename RegExp must return at least 2 Back Reference.\n" if (($br == 2) && ($fn2 eq ''));
	    die "The Filename RegExp must return at least 3 Back Reference.\n" if (($br == 3) && ($fn3 eq ''));

	    die "Back Reference 1 must return a integer value.\n" if (($br == 1) && ($fn1 !~ /\d+/));
	    die "Back Reference 2 must return a integer value.\n" if (($br == 2) && ($fn2 !~ /\d+/));
	    die "Back Reference 3 must return a integer value.\n" if (($br == 3) && ($fn3 !~ /\d+/));

	    if ( ($fn2 >= $n1) && (($n2 eq '') || ($fn2 <= $n2)) ) {
		my $xVal = $fn2 + $nDiff;

		if ($fmtOpt) {
		    $xVal = sprintf "\%0".$fmtOpt."\d", $xVal;
		}
		
		my $newFn;
		if ($br == 1) {
		    $newFn = $xVal.$fn2.$fn3;
		}
		if ($br == 2) {
		    $newFn = $fn1.$xVal.$fn3;
		}
		if ($br == 3) {
		    $newFn = $fn1.$fn2.$xVal;
		}

		if (! exists $testRns{$newFn}) {
		    $testRns{$newFn} = $testRns{$fn};
		    undef $testRns{$fn};
		    print "Test: Renamed $fn to $newFn\n";
		} else {
		    # Renaming this file requires 2 stages to eliminate file overwrites.
		    print "Test: Renamed $fn to $newFn (Using Scheme2)\n";
		    $rn2{$fn} = $newFn;
		    if (($xVal < $n1) && ($xVal >$n2)) {
			print "\nTest: *** Rename would be aborted because files outside of the renamed range would be lost! ($newFn)\n";
			die;
		    }
		}
		
	    }
	}
    }

    if (keys %rn2) {

	foreach my $rnf (keys %rn2) {
	    my $newFn2 = $rnf."_".time()."_".rand(time());
	    if (! exists $testRns{$newFn2}) {
		$testRns{$newFn2} = $testRns{$rnf};
		delete $testRns{$rnf};
		print "Test: Renamed $rnf to $newFn2\n";
		$rn3{$newFn2} = $rn2{$rnf};
	    } else {
		print "\nTest: *** Phase1 Existing file would be over-written lost! ($newFn2)\n";
		print "Test: ...\n";
		print "Test: Rename Actions would be undone.\n";
		exit;
	    }
	}
	foreach my $rnf (keys %rn3) {
	    my $newFn = $rn3{$rnf};
	    if (! exists $testRns{$newFn}) {
		$testRns{$newFn} = $testRns{$rnf};
		delete $testRns{$rnf};
		print "Test: Renamed $rnf to $newFn\n";
	    } else {
		print "\nTest: *** Phase2 Existing file would be over-written and lost! ($newFn)\n";
		print "Test: ...\n";
		print "Test: Rename Actions would be undone.\n";
		exit;
	    }
	}
    }

    exit;

}

# print "File...\n";
foreach my $fn (sort (grep m/${fnPat}/, @allfiles)) {
    my $ln = $fn;
    # print "> $fn\n";
    if ($ln =~ m/${fnPat}/) {
	# print "==> $fn\n";
	my $fn1 = $1;
	my $fn2 = $2;
	my $fn3 = $3;

	die "The Filename RegExp must return at least 1 Back Reference.\n" if (($br == 1) && ($fn1 eq ''));
	die "The Filename RegExp must return at least 2 Back Reference.\n" if (($br == 2) && ($fn2 eq ''));
	die "The Filename RegExp must return at least 3 Back Reference.\n" if (($br == 3) && ($fn3 eq ''));

	die "Back Reference 1 must return a integer value.\n" if (($br == 1) && ($fn1 !~ /\d+/));
	die "Back Reference 2 must return a integer value.\n" if (($br == 2) && ($fn2 !~ /\d+/));
	die "Back Reference 3 must return a integer value.\n" if (($br == 3) && ($fn3 !~ /\d+/));

	if ( ($fn2 >= $n1) && (($n2 eq '') || ($fn2 <= $n2)) ) {
	    my $xVal = $fn2 + $nDiff;
	    
	    if ($fmtOpt) {
		$xVal = sprintf "\%0".$fmtOpt."\d", $xVal;
	    }

	    my $newFn;
	    if ($br == 1) {
		$newFn = $xVal.$fn2.$fn3;
	    }
	    if ($br == 2) {
		$newFn = $fn1.$xVal.$fn3;
	    }
	    if ($br == 3) {
		$newFn = $fn1.$fn2.$xVal;
	    }

	    if (! -f $newFn) {
		rename ($fn, $newFn) || print "Failed to rename file ($fn -> $newFn)\n";
		push (@rnDone, "$fn:$newFn");
		&verbose("Renamed $fn to $newFn\n");
	    } else {
		# Renaming this file requires 2 stages to eliminate file overwrites.
		$rn2{$fn} = $newFn;
		if (($xVal < $n1) && ($xVal >$n2)) {
		    print "\n*** Rename aborted because files outside of the renamed range would be lost! ($newFn)\n";
		    &undoRenames();
		    print "Rename Actions have been undone.\n";
		    exit;
		}
	    }
	}
    }
}

if (keys %rn2) {

    foreach my $rnf (keys %rn2) {
	my $newFn2 = $rnf."_".time()."_".rand(time());
	if (! -f $newFn2) {
	    rename ($rnf, $newFn2) || die "File Stage1 Rename failed! ($rnf -> $newFn2)\n";
	    push (@rnDone, "$rnf:$newFn2");
	    &verbose("Renamed $rnf to $newFn2\n");
	    $rn3{$newFn2} = $rn2{$rnf};
	} else {
	    print "\n*** Phase1 Existing file would be over-written lost! ($newFn2)\n";
	    &undoRenames();
	    print "Rename Actions have been undone.\n";
	    exit;
	}
    }
    foreach my $rnf (keys %rn3) {
	my $newFn = $rn3{$rnf};
	if (! -f $newFn) {
	    rename ($rnf, $newFn) || die "File Stage2 Rename failed! ($rnf -> $newFn)\n";
	    push (@rnDone, "$rnf:$newFn");
	    &verbose("Renamed $rnf to $newFn\n");
	} else {
	    print "\n*** Phase2 Existing file would be over-written and lost! ($newFn)\n";
	    &undoRenames();
	    print "Rename Actions have been undone.\n";
	    exit;
	}
    }
}


sub undoRenames {
    for (my $i=$#rnDone; $i>=0; $i--) {
	my ($on, $nn) = split(':', $rnDone[$i]);
	if (! -f $on) {
	    rename ($nn, $on) || die "Undo Rename failed! ($nn -> $on)\n";
	    &verbose("Rename was undone [$nn back-to $on].\n");
	} else {
	    # This should not occur.
	    die "Undo Rename Failed, Existing file would be over-written and lost! ($on)";
	}
    }

}

sub verbose {
    my $msg = shift;

    if ($verbOpt) {
	print $msg;
    }
}
