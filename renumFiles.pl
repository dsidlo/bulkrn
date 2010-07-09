#!/usr/bin/perl

#
# Renumber files.
#

use Getopt::Long;

use strict;

my $VERSION = "0.0.2";

my ($fnPat, $reNums, $seqOpt, $helpOpt, $testOpt, $verbOpt, $fmtOpt, $roOpt, $substOpt);

my $retGetOpts = GetOptions ( "filePat|f=s"    => \$fnPat,    # The file name regexp.
			      "reNums|r=s"     => \$reNums,   # br:n1|n1-n2:nn
			      "format|d=s"     => \$fmtOpt,   # Use a format string
			      "reSeq|s:i"      => \$seqOpt,   # Force Sequence with Optional Increment
			      "change|c=s"     => \$substOpt, # Substitution String
			      "help|h"         => \$helpOpt,  # Output help
			      "test|t"         => \$testOpt,  # Only do a test
			      "verbose|v+"     => \$verbOpt,  # Verbose Output
			      "run-only|x"     => \$roOpt,    # Run Only. No test before running 
    );

# print "=> (\$fnPat\:$fnPat, \$reNums\:$reNums, \$seqOpt\:$seqOpt, \$helpOpt\:$helpOpt,"
#      ." \$testOpt\:$testOpt, \$verbOpt\:$verbOpt, \$fmtOpt\:$fmtOpt, \$roOpt\:$roOpt)\n";

if ($helpOpt) {
    &helpMe();
}

# Just run a File Pattern Test...
if ( ($fnPat ne '') && ($reNums == undef) && ($substOpt eq '') ) {
    print "Testing the FilePattern...\n";
    opendir(my $DF, "./") || die "Could not opendir './'!\n";
    my @allfiles = readdir($DF);
    foreach my $fn (sort (grep m/${fnPat}/, @allfiles)) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    # print "==> $fn\n";
	    my $fn1 = $1;
	    my $fn2 = $2;
	    my $fn3 = $3;
            print "FilePattern Test: $ln => \$1($fn1) \$2($fn2) \$3($fn3)\n";
        }
    }
    close $DF;
    exit;
}

my ($br, $n1, $n2, $nn);
my $exclam = 0;
my $dash = 0;
if ($reNums ne '') {
    ($br,$n1,$nn) = split(':', $reNums);
    # print "==> ($reNums) [$br:$n1|$n1-$n2:$nn]\n";

    if ($nn =~ /\!/) {
	$exclam = 1;
	$nn =~ s/!//g;
    }

    if ($n1 =~ /\-/) {
	($n1,$n2) = split('-', $n1);
	$dash = 1;
    } else {
	$n2 = $n1;
    }

    if ( ($br !~ /\d+/) || ($n1 !~ /\d+/) || ($n2 !~ /(\d+|)/) || ($nn !~ /\d+/) ) {
	die "Renumber Values Must be Integers! [br:n1|n1-n2:nn] [$br:$n1|$n1-$n2:$nn]\n";
    }

    if (($br > 3) || ($br < 1)) {
	die "Back Reference Value must be LessThan 3 and GreaterThan 1! [br] [$br]\n";
    }

    if ($n2 =~ /\d+/) {
	die "Parameter Error [br:n1-n2:nn] [$br:$n1-$n2:$nn] n2 must be greater-than or equal-to n1!\n" if ($n2 < $n1);
    }
}

my ($ss, $s1, $s2, $s3);
if ($substOpt) {
    if ($substOpt =~ m/^s([\:\/\~\|])/i) {
	$ss = $1;
	(undef, $s1, $s2, $s3) = split ($ss, $substOpt);
	if (($s1 eq '') || ($s2 eq '')) {
	    # Error Condition in substituion string.
	    die "Could not parse --change|-c option [$substOpt]!";
	}
    } else {
	# Error Condition in substituion string.
	die "Could not parse --change|-c option [$substOpt]!";
    }
}

my $nDiff = $nn - $n1;

opendir(my $DF, "./") || die "Could not opendir './'!\n";
my @allfiles = readdir($DF);

# Test the Renumber/Rename Process ===============================================================================

my (%rn2, %rn3);
my @rnDone;
my %rsFn;
my %sqFn;
my @procFiles;
my @finRn;

if ($testOpt) {
    $verbOpt = 2;
}

if ($testOpt || (!$roOpt)) {
    
    &verbose(1,"--- Testing Rename Operations...\n");

    my %testRns;

    # Copy file into psuedo directory.
    foreach my $fn (@allfiles) {
	$testRns{$fn} = $fn;
    }

    @procFiles = (sort (grep m/${fnPat}/, @allfiles));
    if ($#procFiles < 0) {
        die "Your regexp --filePat \'$fnPat\' parameter does not match any files in the current directory!\n";
    }

    if ($seqOpt) {
	foreach my $fn (@procFiles) {
	    my $ln = $fn;
	    # print "> $fn\n";
	    if ($ln =~ m/${fnPat}/) {
		my $fn1 = $1;
		my $fn2 = $2;
		my $fn3 = $3;
		die "The Filename RegExp must return at least 1 Back Reference.\n" if (($br == 1) && ($fn1 eq ''));
		die "The Filename RegExp must return at least 2 Back Reference.\n" if (($br == 2) && ($fn2 eq ''));
		die "The Filename RegExp must return at least 3 Back Reference.\n" if (($br == 3) && ($fn3 eq ''));

		die "Back Reference 1 must return a integer value.\n" if (($br == 1) && ($fn1 !~ /\d+/));
		die "Back Reference 2 must return a integer value.\n" if (($br == 2) && ($fn2 !~ /\d+/));
		die "Back Reference 3 must return a integer value.\n" if (($br == 3) && ($fn3 !~ /\d+/));

		my $procFn = 0;
		my $fVal;
		if ($br == 1) {
		    if ( ($fn1 >= $n1) && (($n2 eq '') || ($fn1 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn1;
		    }
		} elsif ($br == 2) {
		    if ( ($fn2 >= $n1) && (($n2 eq '') || ($fn2 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn2;
		    }
		} elsif ($br == 3) {
		    if ( ($fn3 >= $n1) && (($n2 eq '') || ($fn3 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn3;
		    }
		}

		if ( $procFn ) {

		    my $nVal = sprintf "\%012d", $fVal;

		    $rsFn{$nVal} = $fVal;
		}
	    }    
	}

	my $seqNum = $nn;
	foreach my $k (sort (keys %rsFn)) {
	    $sqFn{$rsFn{$k}} = $seqNum;
	    $seqNum += $seqOpt;
	}

    }

    @procFiles = (sort (grep m/${fnPat}/, @allfiles));

    foreach my $fn (@procFiles) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    # print "==> $fn\n";
	    my $fn1 = $1;
	    my $fn2 = $2;
	    my $fn3 = $3;

	    die "Test: The Filename RegExp must return at least 1 Back Reference.\n" if (($br == 1) && ($fn1 eq ''));
	    die "Test: The Filename RegExp must return at least 2 Back Reference.\n" if (($br == 2) && ($fn2 eq ''));
	    die "Test: The Filename RegExp must return at least 3 Back Reference.\n" if (($br == 3) && ($fn3 eq ''));

	    die "Test: Back Reference 1 must return a integer value.\n" if (($br == 1) && ($fn1 !~ /\d+/));
	    die "Test: Back Reference 2 must return a integer value.\n" if (($br == 2) && ($fn2 !~ /\d+/));
	    die "Test: Back Reference 3 must return a integer value.\n" if (($br == 3) && ($fn3 !~ /\d+/));

	    my $procFn = 0;
	    my $fVal;
            if ($reNums) {
	        if ($br == 1) {
		    if ( ($fn1 >= $n1) && (($n2 eq '') || ($fn1 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn1;
		    }
		} elsif ($br == 2) {
		    if ( ($fn2 >= $n1) && (($n2 eq '') || ($fn2 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn2;
		    }
		} elsif ($br == 3) {
		    if ( ($fn3 >= $n1) && (($n2 eq '') || ($fn3 <= $n2)) ) {
			$procFn = 1;
			$fVal = $fn3;
		    }
		}
	    }

	    if ( $procFn || $substOpt ) {

		my $xVal = $fVal + $nDiff;
		if ($seqOpt) {
		    $xVal = $sqFn{$fVal};
		} elsif ($exclam) {
		    $xVal = $nn;
		}
		if ($fmtOpt) {
		    $xVal = sprintf "\%0".$fmtOpt."\d", $xVal;
		}
		
		# print "=> 1[$fn1] 2[$fn2] 3[$fn3] f[$fVal] nDiff[$nDiff] x[$xVal] \n";

		my $newFn;
		if ($reNums) {
		    if ($br == 1) {
			$newFn = $xVal.$fn2.$fn3;
		    }
		    if ($br == 2) {
			$newFn = $fn1.$xVal.$fn3;
		    }
		    if ($br == 3) {
			$newFn = $fn1.$fn2.$xVal;
		    }
		} elsif ($substOpt) {
		    $newFn = $ln;
		}
		
		# --change
		if ($substOpt) {
		    my $xFn;
		    my $r = eval  "\$xFn = \"$newFn\"; \$xFn =~ s$ss${s1}$ss${s2}$ss${s3};";
		    # print "==> xFn[$xFn] r[$r]\n";
		    if ($r) {
			$newFn = $xFn;
		    } else {
			die "Test: Name --change failed! [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1$ss$s2$ss$s3;] ";
		    }
		}

		# print "==> $newFn\n";
		if (! exists $testRns{$newFn}) {
		    $testRns{$newFn} = $testRns{$fn};
		    undef $testRns{$fn};
		    push (@finRn, $newFn);
		    &verbose(2,"Test: Renamed $fn to $newFn\n");
		} else {
		    # Renaming this file requires 2 stages to eliminate file overwrites.
		    &verbose(2,"Test: Renaming $fn to $newFn requires a 2-Phase Rename.\n");
		    $rn2{$fn} = $newFn;
		    if (($xVal < $n1) && ($xVal >$n2)) {
			&verbose(1,"\nTest: *** Rename would be aborted because files outside of the renamed range would be lost! ($newFn)\n");
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
		&verbose(2,"Test: Renamed $rnf to $newFn2\n");
		$rn3{$newFn2} = $rn2{$rnf};
	    } else {
		print "\nTest: *** Phase1 Existing file would be over-written lost! ($newFn2)\n";
		print "Test: ...\n";
		print "Test: Rename Actions would be undone.\n";
		if ($testOpt) {
		    print "*** Test Failed!\n";
		} else {
		    print "*** Test Failed! Actual renames will not be performed!\n";
		}
		exit;
	    }
	}
	foreach my $rnf (keys %rn3) {
	    my $newFn = $rn3{$rnf};
	    if (! exists $testRns{$newFn}) {
		$testRns{$newFn} = $testRns{$rnf};
		delete $testRns{$rnf};
		push (@finRn, $newFn);
		&verbose(2,"Test: Renamed $rnf to $newFn\n");
	    } else {
		print "\nTest: *** Phase2 Existing file would be over-written and lost! ($newFn)\n";
		print "Test: ...\n";
		print "Test: Rename Actions would be undone.\n";
		if ($testOpt) {
		    print "*** Test Failed!\n";
		} else {
		    print "*** Test Failed! Actual renames will not be performed!\n";
		}
		exit;
	    }
	}
    }

    if ($testOpt) {
	&verbose(1,"*** Only Tested, no files have been renamed.\n");
	if ($verbOpt == 2) {
	    &verbose(2,"=== Final File List...\n");
	    foreach my $fn (sort @finRn) {
		&verbose(2,"   $fn\n");
	    }
	}
	exit;
    } else {
	&verbose(1,"*** Rename Operation Test Done.\n");
    }

}

# Run the Renumber/Rename Process ===============================================================================

my (%rn2, %rn3);
my @rnDone;

&verbose(1,"--- Performing Rename Operations...\n");

foreach my $fn (@procFiles) {
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

	my $procFn = 0;
	my $fVal;
	if ($reNums) {
	    if ($br == 1) {
		if ( ($fn1 >= $n1) && (($n2 eq '') || ($fn1 <= $n2)) ) {
		    $procFn = 1;
		    $fVal = $fn1;
		}
	    } elsif ($br == 2) {
		if ( ($fn2 >= $n1) && (($n2 eq '') || ($fn2 <= $n2)) ) {
		    $procFn = 1;
		    $fVal = $fn2;
		}
	    } elsif ($br == 3) {
		if ( ($fn3 >= $n1) && (($n2 eq '') || ($fn3 <= $n2)) ) {
		    $procFn = 1;
		    $fVal = $fn3;
		}
	    }
	}

	if ( $procFn || $substOpt ) {

	    my $xVal = $fVal + $nDiff;
	    if ($seqOpt) {
		$xVal = $sqFn{$fVal};
	    } elsif ($exclam) {
		$xVal = $nn;
	    }
	    if ($fmtOpt) {
		$xVal = sprintf "\%0".$fmtOpt."\d", $xVal;
	    }

	    my $newFn;
	    if ($reNums) {
		if ($br == 1) {
		    $newFn = $xVal.$fn2.$fn3;
		}
		if ($br == 2) {
		    $newFn = $fn1.$xVal.$fn3;
		}
		if ($br == 3) {
		    $newFn = $fn1.$fn2.$xVal;
		}
	    } elsif ($substOpt) {
		    $newFn = $ln;
	    }

	    # --change
	    if ($substOpt) {
		my $xFn;
		my $r = eval  "\$xFn = \"$newFn\"; \$xFn =~ s$ss${s1}$ss${s2}$ss${s3};";
		# print "==> xFn[$xFn] r[$r]\n";
		if ($r) {
		    $newFn = $xFn;
		} else {
		    die "Test: Name --change failed! [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1$ss$s2$ss$s3;] ";
		}
	    }

	    if (! -f $newFn) {
		rename ($fn, $newFn) || print "Failed to rename file ($fn -> $newFn)\n";
		push (@rnDone, "$fn:$newFn");
		&verbose(2,"Renamed $fn to $newFn\n");
	    } else {
		# Renaming this file requires 2 stages to eliminate file overwrites.
		&verbose(2,"Renaming $fn to $newFn requires a 2-Phase Rename.\n");
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
	    if (!rename ($rnf, $newFn2)) {
		print "*** Phase 1 Rename failed! ($rnf -> $newFn2)\n";
		&undoRenames();
		exit;
	    }
	    push (@rnDone, "$rnf:$newFn2");
	    &verbose(2,"Renamed $rnf to $newFn2\n");
	    $rn3{$newFn2} = $rn2{$rnf};
	} else {
	    print "\n*** Phase1 Existing file would be over-written lost! ($newFn2)\n";
	    &undoRenames();
	    exit;
	}
    }
    foreach my $rnf (keys %rn3) {
	my $newFn = $rn3{$rnf};
	if (! -f $newFn) {
	    if (!rename ($rnf, $newFn)) {
		print "*** Phase 2 Rename failed! ($rnf -> $newFn)\n";
		&undoRenames();
		exit;
	    }
	    push (@rnDone, "$rnf:$newFn");
	    &verbose(2,"Renamed $rnf to $newFn\n");
	} else {
	    print "\n*** Phase2 Existing file would be over-written and lost! ($newFn)\n";
	    &undoRenames();
	    exit;
	}
    }
}

&verbose(1,"*** Rename Operations Completed.\n");

sub undoRenames {
    for (my $i=$#rnDone; $i>=0; $i--) {
	my ($on, $nn) = split(':', $rnDone[$i]);
	if (! -f $on) {
	    rename ($nn, $on) || die "Undo Rename failed! ($nn -> $on)\n";
	    &verbose(1,"Rename was undone [$nn back-to $on].\n");
	} else {
	    # This should not occur.
	    die "Undo Rename Failed, Existing file would be over-written and lost! ($on)";
	}
    }
    print "Rename Actions have been undone.\n";
}

sub verbose {
    my ($lvl, $msg) = @_;

    if ($verbOpt >= $lvl) {
	print $msg;
    }
}

sub helpMe {
    print << "_EOF_";

renumFiles.pl - ReNumber Files  Version ($VERSION)

  Safely renumbers and/or renames numeric portions of file(s) name in the
  current directory. Watches for filename overlap/overwrite conditions what
  would result in a loss of a file and undoes any changes if there is a chance
  that data-loss might occur.

  By default, a simulated test is run to ensure that no data-loss occurs before
  the actual file renames are performed. This default pre-test can be disabled
  by the [--run-only | -x] option.

  You may test/simulate the rename process without actually performing the file
  renames by using the -t switch. By default, the [--test | -t] option performs
  verbose output about what file rename operations would be performed.

  The -r and -c options may be used alone or in tandem to either rename or
  renumber some portion of the file name, for the set of files that match the -f
  file pattern.

  usage: renumFiles.pl [-h|-t|-v-|-x] -f [regexpWith2BackRefs] [-r [br:n1|n1-n2:nn[!]]]
                       [-s [SequentialIncrement]] [-d [ZeroPaddedLength]]
                       [-c [SubstitutionPattern]]

  Requires that the first argument, be defined as a pattern that matches to
  a set of file-names of interest, where the pattern returns upto
  3 back-reference values. The parameter br is the Back Reference value which
  will be changed into a new number.

  By only supplying the [--filePat | -f] option and a file pattern, you can test
  that your file pattern is picking up the files that you expect to rename. And,
  you can the how the file name splits up into its back-references.

\$ \./renumFiles.pl -f '(mwlog\\.wfiejb\\d+)(\\.\\d\\d\\d\\d)(08\\d\\d)' 
Testing the FilePattern...
FilePattern Test: mwlog.wfiejb1.20100810 => $1(mwlog.wfiejb1) $2(.2010) $3(0810)
FilePattern Test: mwlog.wfiejb1.20100811 => $1(mwlog.wfiejb1) $2(.2010) $3(0811)
FilePattern Test: mwlog.wfiejb1.20100812 => $1(mwlog.wfiejb1) $2(.2010) $3(0812)
...

 The file name pattern...

  -filePat|-f [filePattern RegExpp]

  '(mwlog\\.wfiejb)(\\d+)(\\..*)'
    ^------------  ^--- ^--- 
    |              |    |
    |              |    +---: BackRef \$3 -> \$fn1
    |              +--------: BackRef \$2 -> \$fn2
    +-----------------------: BackRef \$1 -> \$fn3

  In the example above...
  For our example, we want to renumber the values of the 2nd back-reference, so
  the 2nd back-reference must allways return a numeric value.
  This numberic value is compared against n1. And, if there is a match, n1 is
  substitued with the value of nn. And the new file name is built...

  \$newFn = \$fn1.(\$fn+(n2-n1)).\$fn3;

  The --reNum|-r parameter consists of... [br:n1|n1-n2:nn]

  br: Back Reference value that is the numberic value that will be changed.
  n1: The first numeric value that will be changed.
  n2: The last  numeric value that will be changed.
  nn: The numberic value that n1 will be changed to.
      Subsequent values will be changed to n2+(nn-n1) incrementing the value
      by the difference between n1 and nn.
      An exclaimation-point symbol after nn (:20!) fixes the new number to that
      single value. The "new number" value will not change relative to the 
      Back Reference value found in the file name.

  ** If n1 is specified without n2,only the files whos back-reference values
     match n1 will be change to the new number.
     If n1 is specified with a trailing dash "-" and n2 is not specified "10-",
     all values from n1 and greater are changed to the new value. 
     If n1 and n2 exist with a dash "-" between them "10-20" all values between
     and including n1 and n2 are changed to a new value.

  example: renumFiles.pl -f '(mwlog\\.wfiejb)(\\d+)(\\..*)' -r 2:5:15 

  Above, only n1 and nn are specified as options, all \$2 back-reference values
  that match 5 will be incrmented by 10 (nn-n1).

  example: renumFiles.pl -f '(mwlog\\.wfiejb)(\\d+)(\\..*)' -r 2:5-:15 

  Above, only n1 and nn are specified as options, all \$2 back-reference values
  that match 5 and above will be incrmented by 10 (nn-n1).

  example: renumFiles.pl -f '(mwlog\\.wfiejb)(\\d+)(\\..*)' -r 2:5-7:15

  Above, n1-n2 and nn are specified as options, only \$2 back-reference values
  that match 5 thru 7 are incrmented by 10. 

  The rename process watches for file name overlap conditions what would cause
  a file to be overwritten and lost. If such conditions are found, the process
  aborts after undoing all file renames that had been done thus far.

  Other options:

  --format|-d [LeadingZerosFormatLength]
  Format the new numberic value with leading zeros to a length of n.
  example: -d 5

  --change|-c [SubstitutionPattern] (-c 's/mwlog/mxx/i')
  A substitution pattern that changes some portion of the filename if found.

  --help|-h
  Output this help text.

  --reSeq|-s [SequentialIncrement] (-s 1)
  Resequence the numbers (n1-n2) begining with nn such that the new values are
  contiguous and optionaly incremented by [increment].

  --test|-t
  Test the renumbering/renaming process against the filenames in the current
  directory.

  --verbose | -v
  Print details of the renaming process.
  There are 2 levels of verbosity "-v" and "-v -v"

  (See: "perldoc renumFiles.pl" for more details and examples of use.)
_EOF_

   exit;

}

=head1 renumFiles.pl Version (0.0.2)

    Renumber Files (Safely) script.

=head1 SYNOPSIS

  usage: renumFiles.pl [-h|-t|-v-|-x]
                        -f [RegexpWithBackRefs]
                       [-r [br:n1|n1-n2:nn[!]]]
                       [-s [SequentialIncrement]]
                       [-d [ZeroPaddedLength]]
                       [-c [SubstitutionString]]

  -filePat|-f [RegexpWithBackRefs]
  A regexp that matches to a file in the current directory and splits it into as
  many as 3 back-reference values where at least one of the back-reference
  values is always an integer field, which will be renumbered.
  Using this option alone will list the files that match the regexp in the
  current directory.

  -reNum|-r [br:n1|n1-|n1-n2:nn[!]]
      br: The back-reference index whos value will change to nn 
          (which increments, or which is static).
      n1: The Only value that will change.
     n1-: Change all values from n1 and greater.
   n1-n2: Change all values from n1 to n2.
      nn: Change n1 to this new value (nn).
     nn!: Don't increment nn relative to n1-n2. nn stays static.

  --test|-t 
  Perform a test only.

  --verbose|-v
  Turn on verbose mode.

  --change|-c [SubstitutionPattern] (-c 's/mwlog/mxx/i')
  A substitution pattern that changes some portion of the filename if found.

  --help|-h
  Output this help text.

  --reSeq|-s [SequentialIncrement] (-s 1)
  Resequence the numbers (n1-n2) begining with nn such that the new values are
  contiguous and optionaly incremented by [increment].

  --run-only|-x
  Run without first testing. But, if a file over-write is detected, rename
  operations are undone, leaving the files and file names in thier original
  state.

  -d [ZeroPaddedLength]
  Format the new number with zero padding and the given fixed length.

=head1 DESCRIPTION

  The script performs flexible renumbering and resequencing of numberic values
  embeded into filenames. It performs safe rename operations by first simulating
  the rename process using all of the file names in the current directory, but
  only against a hash, so that actual renames are not done. If a file over-write
  condition is encountered, the acutal file rename process is not performed.
  If a file over-write condition is detected during the actual file renaming
  process, the process is aborted at that point, and all file renames done to
  that point are un-done.

=head1 AUTHOR - David Sidlo

    dsidlo@gmail.com

=head1 APPENDIX

=head2 Examples...

  ./renumFiles.pl -f 'mwlog'
  List the files that match to mwlog in the current directory.

  ./renumFiles.pl -f 'mwlog' -c 's/mwlog/mxlog/'
  Changes the file names that match mwlog in the current directory to mxlog.

  ./renumFiles.pl -f 'mxlog\.wfiejb(\d+)(\.\d+)'
  List the files that match to mwlog in the current directory.
  See what portions of the file name are captured in upto 3 back reference
  values.

  ./renumFiles.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1
  Renumber the value after wfiejb from 1-n to 300-n resequencing the value with
  an increment of 1.

  ./renumFiles.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/'
  Renumber the value after wfiejb from 1-n to 2-n resequencing the value with an
  increment of 2, formatting the number with 3 digits and leading zeros, and
  changing "mxlog" to "mwlog".

=cut


