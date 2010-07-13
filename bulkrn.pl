#!/usr/bin/perl

#
# Renumber files.
#

use Getopt::Long;

use strict;

my $VERSION = "0.0.2";

my ($fnPat, $reNums, $seqOpt, $helpOpt, $testOpt, $verbOpt, $fmtOpt, $roOpt, $substOpt, $runOpt, $dirOpt);

# By Default we always only test.
$testOpt = 1;

my $retGetOpts = GetOptions ( "filePat|f=s"    => \$fnPat,    # The file name regexp.
			      "reNums|r=s"     => \$reNums,   # br:n1|n1-n2:nn
			      "format|d=s"     => \$fmtOpt,   # Use a format string
			      "reSeq|s:i"      => \$seqOpt,   # Force Sequence with Optional Increment
			      "change|c=s"     => \$substOpt, # Substitution String
			      "help|h"         => \$helpOpt,  # Output help
			      "go"             => \$runOpt,   # Run this baby!
			      "verbose|v+"     => \$verbOpt,  # Verbose Output
			      "run-only|x"     => \$roOpt,    # Run Only. No test before running 
			      "autoDir|a"      => \$dirOpt,   # Auto create missing dirs.
    );

# print "=> (\$fnPat\:$fnPat, \$reNums\:$reNums, \$seqOpt\:$seqOpt, \$helpOpt\:$helpOpt,"
#      ." \$testOpt\:$testOpt, \$verbOpt\:$verbOpt, \$fmtOpt\:$fmtOpt, \$roOpt\:$roOpt)\n";

if ($helpOpt) {
    &helpMe();
}

# We must add the -go options to run for real.
if ($runOpt) {
    $testOpt = 0;
}

my @fn; # File name back references.

# print "=> ARGV0[$ARGV[0]]\n";
my $srcDir = $ARGV[0];
if (!$srcDir) {
    $srcDir = './';
}
if (! -d $srcDir) {
    die "The specified [SourceDir] does not exist! [$srcDir]";
}

# Just run a File Pattern Test...
if ( ($fnPat ne '') && ($reNums == undef) && ($substOpt eq '') ) {
    print "Testing the FilePattern...\n";
    chdir $srcDir || die "Faile to chdir to [SourceDir]! [$srcDir]\n";
    opendir(my $DF, './') || die "Could not opendir [$srcDir]!\n";
    my @allfiles = readdir($DF);
    foreach my $fn (sort (grep m/${fnPat}/, @allfiles)) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    $fn[1] = $1; $fn[2] = $2; $fn[3] = $3;
	    $fn[4] = $4; $fn[5] = $5; $fn[6] = $6;
	    $fn[7] = $7; $fn[8] = $8; $fn[9] = $9;
	    # print "==> $fn\n";
            print "FilePattern Test: $ln =br=> ";
	    for (my $i=1; $i<=$#fn; $i++) {
		if ($fn[$i] =~ /\d+/) {
		    print "$i\($fn[$i]\) ";
		}
	    }
	    print "\n";
        }
    }
    close $DF;
    exit;
}

if ($fnPat eq '') {
    die "You must specify the file name pattern option! [-filePat|-f] [FilePattern]\n";
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

    if (($br > 9) || ($br < 1)) {
	die "Back Reference Value must be between 9 and 1! [br] [$br]\n";
    }

    if ($n2 =~ /\d+/) {
	die "Parameter Error [br:n1-n2:nn] [$br:$n1-$n2:$nn] n2 must be a numberic value!\n" if ($n2 < $n1);
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

chdir $srcDir || die "Faile to chdir to [SourceDir]! [$srcDir]\n";
opendir(my $DF, './') || die "Could not opendir [$srcDir]!\n";
my @allfiles = readdir($DF);

# Test the Renumber/Rename Process ===============================================================================

my (%rn2, %rn3);
my @rnDone;
my %rsFn;
my %sqFn;
my @procFiles;
my @finRn;
my %FinRn;
my %newDirs;

if ($testOpt) {
    $verbOpt = 2 if ($verbOpt < 2);
}

@procFiles = (sort (grep m/${fnPat}/, @allfiles));

# Create a hash of the original matching file names.
my %origFn;
foreach my $fn (@procFiles) {
    $origFn{$srcDir.'/'.$fn} = $fn;
}

if ($#procFiles < 0) {
    die "Your regexp --filePat \'$fnPat\' parameter does not match any files in the current directory!\n";
}

if ($reNums && $seqOpt) {
    foreach my $fn (@procFiles) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    $fn[1] = $1; $fn[2] = $2; $fn[3] = $3;
	    $fn[4] = $4; $fn[5] = $5; $fn[6] = $6;
	    $fn[7] = $7; $fn[8] = $8; $fn[9] = $9;

	    for (my $i=$#fn; $i>0; $i--) {
		if ($fn[$i]) {
		    if ($br > $i) {
			die "The Filename RegExp must return at least [$i] Back References.\n";
		    }
		    last;
		}
	    }
	    die "Back Reference [$br] must return a integer value.\n" if ($fn[$br] !~ /\d+/);

 	    my $procFn = 0;
	    my $fVal;
	    # print "-> fn[$br]: ($fn[$br])\n";
            if ($reNums) {
		if (($fn[$br] >= $n1) && (($n2 eq '') || ($fn[$br] <= $n2))) {
		    $procFn = 1;
		    $fVal = $fn[$br];
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


if ($testOpt || (!$roOpt)) {
    
    &verbose(1,"--- Testing Rename Operations...\n");

    my %testRns;

    # Copy file into psuedo directory.
    foreach my $fn (@allfiles) {
	$testRns{$fn} = $fn;
    }

    foreach my $fn (@procFiles) {
	my $ln = $fn;
	# print "> $fn\n";
	if ($ln =~ m/${fnPat}/) {
	    # print "==> $fn\n";
	    $fn[1] = $1; $fn[2] = $2; $fn[3] = $3;
	    $fn[4] = $4; $fn[5] = $5; $fn[6] = $6;
	    $fn[7] = $7; $fn[8] = $8; $fn[9] = $9;

	    if ($reNums) {
		for (my $i=$#fn; $i>0; $i--) {
		    if ($fn[$i]) {
			if ($br > $i) {
			    die "The Filename RegExp must return at least [$i] Back References.\n";
			}
			last;
		    }
		}
		die "Back Reference [$br] must return a integer value.\n" if ($fn[$br] !~ /\d+/);
	    }

	    my $procFn = 0;
	    my $fVal;
 	    my $procFn = 0;
	    my $fVal;
            if ($reNums) {
		if (($fn[$br] >= $n1) && (($n2 eq '') || ($fn[$br] <= $n2))) {
		    $procFn = 1;
		    $fVal = $fn[$br];
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

		my $newFn = "";
		if ($reNums) {
		    # Bring back regs together to rebuild the file name...
		    for (my $i=1; $i<=$#fn; $i++) {
			if ($br == $i) {
			    # but, use the new number in place of (br).
			    $newFn .= $xVal;
			} else {
			    $newFn .= $fn[$i];
			}
		    }
		} elsif ($substOpt) {
		    $newFn = $ln;
		}

		# print "..> newFn[$newFn]\n";
		
		# --change
		if ($substOpt) {
		    my $xFn;
		    
		    my $s1a = $s1;
		    # Replace $1..9 to Captured BackRefs for match portion of -c substitution.
		    for (my $i=1; $i<=$#fn; $i++) {
			if ($s1a =~ /[\$\\]${i}/) {
			    my $fx = $fn[$i];
			    $s1a =~ s/[\$\\]${i}/\(${fx}\)/g;
			}
		    }

		    eval  "\$xFn = \"$newFn\"; \$xFn =~ s$ss${s1a}$ss${s2}$ss${s3};";
		    # print "==> [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1a$ss$s2$ss$s3;] xFn[$xFn] \$\@[$@]\n";
		    if (!$@) {
			$newFn = $xFn;
		    } else {
			die "Test: Name --change failed! [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1$ss$s2$ss$s3;] ($@)\n";
		    }
		}

		# print "==> [$newFn] Exists:".(exists $testRns{$newFn})." [$testRns{$newFn}]\n";
		if (! exists $testRns{$newFn}) {
		    # See if file-path directories already exists.
		    my $chkd = &checkDirs(1, $newFn, \%newDirs);
		    # print "==> chkd[$chkd] dirOpt[$dirOpt]\n";
		    if ($chkd && ($dirOpt eq '')) {
			print "Test: *** New directory(ies) ($newFn) would have to be created, perhaps you should use the -autoDir option!\n";
		    }
		    # Perform rename operation on psudeo dir.
		    $testRns{$newFn} = $testRns{$fn};
		    undef $testRns{$fn};
		    push (@finRn, $newFn);
		    if (exists $FinRn{$newFn}) {
			# Overwrites because multiple files are renamed to the same file name.
			print "\nTest: *** Rename would be aborted because multiple files would be renamed to a the same name! ($newFn)\n";
			die;
		    } else {
			$FinRn{$newFn} = $fn;
		    }
		    &verbose(3,"Test: Renamed $fn to $newFn\n");
		} else {
		    # The new file name already exists in the current dir.
		    if (exists $FinRn{$newFn}) {
			# Overwrites because multiple files are renamed to the same file name.
			print "\nTest: *** Rename would be aborted because multiple files would be renamed to a the same name! ($newFn)\n";
			die;
		    }
		    if (exists $origFn{$newFn}) {
			# Renaming this file requires 2 stages to eliminate file overwrites.
			&verbose(3,"Test: Renaming $fn to $newFn requires a 2-Phase Rename.\n");
			$rn2{$fn} = $newFn;
			$FinRn{$newFn} = $fn;
		    } else {
			# New file name does not occur in the original file set.
			# If Clashing file name is not a file in our set of files, we have an over-write condition.
			print "\nTest: *** Rename would be aborted because files outside of the renamed [file set] would be lost! ($newFn)\n";
			die;
		    }
		    if (($xVal < $n1) && ($xVal >$n2)) {
			print "\nTest: *** Rename would be aborted because files outside of the renamed [number range] would be lost! ($newFn)\n";
			die;
		    }
		}
		
	    }
	}
    }

    if (keys %rn2) {

	# 2-Phase Rename - Phase 1: Rename files to a random file name.
	#                           to avoid overwrite conditions.
	foreach my $rnf (keys %rn2) {
	    my $fileRenamed = 0;
	    do {
		my $newFn2 = $rnf."_".time()."_".rand(time());
		if (! exists $testRns{$newFn2}) {
		    # Perform rename operation on psudeo dir.
		    $testRns{$newFn2} = $testRns{$rnf};
		    delete $testRns{$rnf};
		    &verbose(3,"Test: Renamed $rnf to $newFn2\n");
		    $rn3{$newFn2} = $rn2{$rnf};
		} else {
		    warn "--- Unexpectedly, the random file name exists ($newFn2)! Will try a new random name...";
		}
	    } until ($fileRenamed);
	}
	# 2-Phase Rename - Phase 2: Rename files to from random file names
        #                           to their final names.
	foreach my $rnf (keys %rn3) {
	    my $newFn = $rn3{$rnf};
	    if (! exists $testRns{$newFn}) {
		# Perform rename operation on psudeo dir.
		$testRns{$newFn} = $testRns{$rnf};
		delete $testRns{$rnf};
		push (@finRn, $newFn);
		&verbose(3,"Test: Renamed $rnf to $newFn\n");
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
	    &verbose(2,"=== Source Dir: [$srcDir]\n");
	    &verbose(2,"=== Bulk Renames will be Successful. Final File List...\n");
	    foreach my $fn (sort @finRn) {
		&verbose(2,"   $fn  =was=  $FinRn{$fn}\n");
	    }
	    if (keys %newDirs) {
		&verbose(2,"=== New Dirs to Create...\n");
		foreach my $dir (sort (keys %newDirs)) {
		    &verbose(2,"   $dir\n");
		}
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
my %FinRn;
my %newDirs;

&verbose(1,"--- Performing Rename Operations...\n");

foreach my $fn (@procFiles) {
    my $ln = $fn;
    # print "> $fn\n";
    if ($ln =~ m/${fnPat}/) {
	# print "==> $fn\n";
	$fn[1] = $1; $fn[2] = $2; $fn[3] = $3;
	$fn[4] = $4; $fn[5] = $5; $fn[6] = $6;
	$fn[7] = $7; $fn[8] = $8; $fn[9] = $9;

	if ($reNums) {
	    for (my $i=$#fn; $i>0; $i--) {
		if ($fn[$i]) {
		    if ($br > $i) {
			die "The Filename RegExp must return at least [$i] Back References.\n";
		    }
		    last;
		}
	    }
	    die "Back Reference [$br] must return a integer value.\n" if ($fn[$br] !~ /\d+/);
	}

	my $procFn = 0;
	my $fVal;
	if ($reNums) {
	    if (($fn[$br] >= $n1) && (($n2 eq '') || ($fn[$br] <= $n2))) {
		$procFn = 1;
		$fVal = $fn[$br];
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
		# Bring back regs together to rebuild the file name...
		for (my $i=1; $i<=$#fn; $i++) {
		    if ($br == $i) {
			# but, use the new number in place of (br).
			$newFn .= $xVal;
		    } else {
			$newFn .= $fn[$i];
		    }
		}
	    } elsif ($substOpt) {
		$newFn = $ln;
	    }

	    # --change
	    if ($substOpt) {
		my $xFn;

		my $s1a = $s1;
		# Replace $1..9 to Captured BackRefs for match portion of -c substitution.
		for (my $i=1; $i<=$#fn; $i++) {
		    if ($s1a =~ /[\$\\]${i}/) {
			my $fx = $fn[$i];
			$s1a =~ s/[\$\\]${i}/\(${fx}\)/g;
		    }
		}

		eval  "\$xFn = \"$newFn\"; \$xFn =~ s$ss${s1a}$ss${s2}$ss${s3};";
		# print "==> [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1a$ss$s2$ss$s3;] xFn[$xFn] \$\@[$@]\n";
		if (!$@) {
		    $newFn = $xFn;
		} else {
		    die "Test: Name --change failed! [\$xFn = \"$newFn\"; \$xFn =~ s$ss$s1$ss$s2$ss$s3;] ($@)\n";
		}
	    }

	    # print "==> newFN[$newFn] exists(".(-f $newFn).")\n";
	    if (! -f $newFn) {
		# See if file-path directories already exists.
		my $chkd = &checkDirs(0, $newFn, \%newDirs);
		# print "==> chkd[$chkd] dirOpt[$dirOpt]\n";
		if ($chkd && ($dirOpt eq '')) {
		    print "Test: *** New directory(ies) ($newFn) would have to be created, perhaps you should use the -autoDir option!\n";
		}
		# File is not in the current dir or path.
		rename ($fn, $newFn) || print "Failed to rename file ($fn -> $newFn)\n";
		push (@rnDone, "$fn:$newFn");
		&verbose(2,"Renamed $fn to $newFn\n");
		if (exists $FinRn{$newFn}) {
		    # Overwrites because multiple files are renamed to the same file name.
		    die "\n*** Rename aborted because multiple files would be renamed to a the same name! ($newFn)\n";
		} else {
		    $FinRn{$newFn} = $fn;
		}
	    } else {
		# File exists in the current dir or path.
		if (exists $FinRn{$newFn}) {
		    # Overwrites because multiple files are renamed to the same file name.
		    die "\n*** Rename aborted because multiple files would be renamed to a the same name! ($newFn)\n";
		}
		# print "==> [$newFn] origFn[".join(", ",(keys %origFn))."]\n";
		if (exists $origFn{$newFn}) {
		    # Renaming this file requires 2 stages to eliminate file overwrites.
		    &verbose(2,"Renaming $fn to $newFn requires a 2-Phase Rename.\n");
		    $rn2{$fn} = $newFn;
		} else {
		    # New file name does not occur in the original file set.
		    # If Clashing file name is not a file in our set of files, we have an over-write condition.
		    # With Window/Dos We can end up here even if the newFile does not actually exist.
		    # This is because the Windows/Dos fs does not distinguish between upper and lower case file names.
		    if (   ($ENV{OS} =~ /(windows|dos)/i)
			&& ( (-f $fn) && (-f $newFn) && ($fn =~ /${newFn}/i) ) ){
			# print "*** You are receiving this error because, on a Windows system, file names are not distiguished by case!\n";
			# print "*** Thus, there is an overwrite condition! Original File:[$fn] New File:[$newFn]\n";
			# Renaming this file requires 2 stages to eliminate file overwrites.
			&verbose(2,"Windows\|DOS: Renaming $fn to $newFn requires a 2-Phase Rename.\n");
			$rn2{$fn} = $newFn;
		    } else {
			print "\n*** Rename aborted because files outside of the renamed [set] would be lost! ($newFn)\n";
			&undoRenames();
			die;
		    }
		}
		if (($xVal < $n1) && ($xVal >$n2)) {
		    print "\n*** Rename aborted because files outside of the renamed [range] would be lost! ($newFn)\n";
		    &undoRenames();
		    die;
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
		die;
	    }
	    push (@rnDone, "$rnf:$newFn2");
	    &verbose(2,"Renamed $rnf to $newFn2\n");
	    $rn3{$newFn2} = $rn2{$rnf};
	} else {
	    print "\n*** Phase1 Existing file would be over-written lost! ($newFn2)\n";
	    &undoRenames();
	    die;
	}
    }
    foreach my $rnf (keys %rn3) {
	my $newFn = $rn3{$rnf};
	if (! -f $newFn) {
	    if (!rename ($rnf, $newFn)) {
		print "*** Phase 2 Rename failed! ($rnf -> $newFn)\n";
		&undoRenames();
		die;
	    }
	    push (@rnDone, "$rnf:$newFn");
	    &verbose(2,"Renamed $rnf to $newFn\n");
	} else {
	    print "\n*** Phase2 Existing file would be over-written and lost! ($newFn)\n";
	    &undoRenames();
	    die;
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

sub checkDirs () {
    my ($tst, $newFn, $nd) = @_;

    my $fromRoot = 0;
    if ($newFn =~ /^\//) {
	$fromRoot = 1;
    }
    my @dirs = split('\/', $newFn);
    # Assume last item in the array is the file name.
    my $fn = pop @dirs;
    my $madeNewDir = 0;
    my $dp = "";
    for (my $i=0; $i<=$#dirs; $i++) {
	if ($fromRoot) {
	    $dp .= '/';
	}
	$dp .= $dirs[$i].'/';
	if ($tst) {
	    if (!exists $nd->{$dp}) {
		$nd->{$dp} = 1;
		$madeNewDir = 1;
	    }
	} elsif ($dirOpt) {
	    if (! -d $dp) {
		mkdir $dp || die "Failed to create directory ($dp) for ($newFn)!\n";
		$nd->{$dp} = 1;
		$madeNewDir = 1;
	    }
	} elsif (!$testOpt) {
	    if (! -d $dp) {
		die "The directory ($dp) does not exist! Perhapse you need to use the -autoDir option!";
	    }
	}
    }

    # print "=> madeNewDir[$madeNewDir]\n";
    return $madeNewDir;
}

sub verbose {
    my ($lvl, $msg) = @_;

    if ($verbOpt >= $lvl) {
	print $msg;
    }
}

sub helpMe {
    print << "_EOF_";

bulkrn.pl - ReNumber Files  Version ($VERSION)

  A general purpose file name and file path transformation utility.
  Works on unix and cygwin and with ActiveState-Perl.

  Safely renumbers (numeric portions of a file(s) name) and/or renames files
  in the current directory. Watches for filename overlap/overwrite conditions
  what would result in a loss of a file and undoes any changes if there is a
  chance that data-loss might occur.

  By default, the rename process only runs in "test" mode, and you must add the
  -go option to perform the actual rename commands against the file system.
  This guards against the possibility of loosing file data (due to file a 
  overwrites occuring), or loosing file name information (in the case where the
  rename parameters are incorrect, and all files have been renamed as simple
  numeric strings).
  So, we always try to ensure that you check your final results first before
  committing your bulk file name changes with the -go option.

  Again, by default (even with the -go option), a simulated test is always
  run to ensure that no data-loss occurs before the actual file renames are
  performed. This default pre-test can be disabled by the [--run-only | -x]
  option. This is especially useful when using this program within a script.

  The -r and -c options may be used alone or in tandem to either rename or
  renumber some portion of the file name, given the set of files that match
  the -f file pattern.

  usage: bulkrn.pl [SourceDir]
                   [-a|-h|-t|-v-|-x] 
                   -f [FilePattern] 
                   [-r [br:n1|n1-n2:nn[!]]]
                   [-s [SequentialIncrement]]
                   [-d [ZeroPaddedLength]]
                   [-c [SubstitutionPattern]]
                   [-go]

  If not specified [SourceDir] defaults to the current dir './'.

  Requires that the first argument, be defined as a pattern that matches to
  a set of file-names of interest, where the pattern returns upto
  9 back-reference values. The parameter br is the Back Reference value which
  will be changed into a new number. So the return value of that back reference
  must be an integer value. Every portion of the file name that will
  become part of the new name must be held in a back reference. If it is not,
  that portion of the file name will be removed from the new file name.

  By only supplying the [--filePat | -f] option and a file pattern, you can test
  that your file pattern is picking up the files that you expect to rename. And,
  you can the how the file name splits up into its back-references.

\$ \./bulkrn.pl -f '(mwlog\\.wfiejb\\d+)(\\.\\d\\d\\d\\d)(08\\d\\d)' 
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


  -reNum|-r [br:n1|n1-|n1-n2:nn[!]]

      br: The back-reference index whos value will change to nn 
          (which increments, or which is static).
      n1: The Only value that will change.
     n1-: Change all values from n1 and greater.
   n1-n2: Change all values from n1 to n2.
      nn: Change n1 to this new value (nn).
     nn!: Don't increment nn relative to n1-n2. nn stays static.

  --reSeq|-s [SequentialIncrement] (-s 1)
  Resequence the numbers (n1-n2) begining with nn such that the new values are
  contiguous and optionaly incremented by [increment].

  --format|-d [LeadingZerosFormatLength]
  Format the new numberic value with leading zeros to a length of n.
  example: -d 5

  --change|-c [SubstitutionPattern] (-c 's/mwlog/mxx/i')
  A substitution pattern that changes some portion of the filename if found.
  The back-references \$1..\$9 may be used in the "matching" portion of the
  string substitution equation to refer to the back-refs in the original
  --filePat parameter. This is useful for upper and lowercasing portions of
  a filename.

  Other options:

  --autoDir|-a
  Automatically create directories along new file paths.
  With out this option, if new file paths do not exist, the rename operation
  will fail.

  --test|-t
  Test the renumbering/renaming process against the filenames in the current
  directory.

  --verbose | -v
  Print details of the renaming process.
  There are 3 levels of verbosity "-v", "-v -v" and "-v -v -v"

  --help|-h
  Output this help text.

  (See: "perldoc $0" for more details and examples of use.)
_EOF_

   exit;

}

=head1 bulkrn.pl Version (0.0.2)

  A general purpose file name and file path transformation utility.
  Performs file name and file path transformations SAFELY by:
  1. Using renaming methods that avoid file overwrite conditions.
  2. Tests file name transformations for file overwrite conditions before the
     rename actions are committed against the file system.
  3. Allows the user to walk through the process of developing the required
     file name transformations, giving feed back on errors and final results.
  4. Avoids the loss of file data and file name information by requiring the
     user to test the file name transformation and validating results.
     Actual file name transformations are not committed to the file system
     unless the -go option is added to the command line.
  5. If an overwrite condition or error occurs during the file rename process
     all actions performed thus far are rolled back.

  Works on unix and cygwin and with ActiveState-Perl.

=head1 SYNOPSIS

  usage: bulkrn.pl [SourceDir]
                   [-h|-t|-v-|-x]
                    -f [FilePattern]
                   [-r [br:n1|n1-n2:nn[!]]]
                   [-s [SequentialIncrement]]
                   [-d [ZeroPaddedLength]]
                   [-c [SubstitutionString]]

  If not specified [SourceDir] defaults to the current dir './'.

  -filePat|-f [FilePattern]
  A regexp that matches to a file in the current directory and splits it into as
  many as 9 back-reference values where the back-reference values 
  (referenced by the -reNum/br) must always be an integer field, which will
  be renumbered. Using this option alone will list the files that match the
  regexp in the current directory.  Every portion of the file name that will
  become part of the new name must be held in a back reference. If it is not,
  that portion of the file name will be removed from the new file name.

=head2 The [--reNum | -r] parameter consists of... [br:n1|n1-n2:nn]

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

  The regexp file pattern must contain back-references for all portions of the
  original file name that you want to preserve, including a back reference for
  the portion that contains all numerics (that will be renumbered).

  For example: bulkrn.pl -f '(mwlog\.wfiejb)(\d+)(\..*)' -r 2:5:15 
  Will change mwlog.wfiejb5.20100701 to mwlog.wfiejb5.20100701.

  But,: bulkrn.pl -f 'mwlog\.wfiejb(\d+)(\..*)' -r 1:5:15 
  Will change mwlog.wfiejb5.20100701 to 5.20100701.
  Because, the "mwlog\.wfiejb" portion of the file name is not enclosed in
  parens and will not be preserved.
   
  example: bulkrn.pl -f '(mwlog\.wfiejb)(\d+)(\..*)' -r 2:5:15 

  Above, only n1 and nn are specified as options, all \$2 back-reference values
  that match 5 will be incrmented by 10 (nn-n1).

  example: bulkrn.pl -f '(mwlog\.wfiejb)(\d+)(\..*)' -r 2:5-:15 

  Above, only n1 and nn are specified as options, all \$2 back-reference values
  that match 5 and above will be incrmented by 10 (nn-n1).

  example: bulkrn.pl -f '(mwlog\.wfiejb)(\d+)(\..*)' -r 2:5-7:15

  Above, n1-n2 and nn are specified as options, only \$2 back-reference values
  that match 5 thru 7 are incrmented by 10. 

  The rename process watches for file name overlap conditions what would cause
  a file to be overwritten and lost. If such conditions are found, the process
  aborts after undoing all file renames that had been done thus far.

=head2 [--test | -t] 

  Perform a test only.

=head2 [--verbose | -v]

  Print details of the renaming process.
  There are 3 levels of verbosity "-v", "-v -v" and "-v -v -v"

=head2 [--change | -c] [SubstitutionPattern] (-c 's/mwlog/mxx/i')

  A substitution pattern that changes some portion of the filename if found.
  The back-references \$1..\$9 may be used in the "matching" portion of the
  string substitution equation to refer to the back-refs in the original
  --filePat parameter. This is useful for upper and lowercasing portions of
  a filename.

=head2 [--reSeq | -s] [SequentialIncrement] (-s 1)

  Resequence the numbers (n1-n2) begining with nn such that the new values are
  contiguous and optionaly incremented by [increment].

=head2 [--format | -d] [ZeroPaddedLength]

  Format the new number with zero padding and the given fixed length.

=head2 [--autoDir | -a]

  Automatically create directories along new file paths.
  With out this option, if new file paths do not exist, the rename operation
  will fail.

=head2 [--run-only | -x]

  Run without first testing. But, if a file over-write is detected, rename
  operations are undone, leaving the files and file names in thier original
  state.

=head2 [--help | -h]

  Output help text.

=head1 DESCRIPTION

  A general purpose file name and file path transformation utility.

  This script performs flexible renaming, renumbering and resequencing of
  numberic values embeded in filenames. It performs safe rename operations
  by first simulating the rename process using all of the file names in the
  current directory, but only against a hash, so that actual renames are not
  done. If a file over-write condition is encountered, the acutal file rename
  process is not performed. If a file over-write condition is detected during
  the actual file renaming process, the process is aborted at that point, and
  all file renames done to that point are un-done.

  By default, the rename process only runs in "test" mode, and you must add the
  -go option to perform the actual rename commands against the file system.
  This guards against the possibility of loosing "file name" information in the
  case where the rename parameters are incorrect, and the renames are performed
  (with no overwrite conditions, and are not undone), and as a result, all
  files have been renamed as simple number strings.
  So, Always check your final results first before committing with the -go
  option.

  Again, by default (even with the -go option), a simulated test is always
  run to ensure that no data-loss occurs before the actual file renames are
  performed. This default pre-test can be disabled by the [--run-only | -x]
  option. This is especially useful when using this program within a script.

=head1 AUTHOR - David Sidlo

    dsidlo@gmail.com

=head1 APPENDIX

=head2 Examples

  List the files that match to mwlog in the current directory:
  ./bulkrn.pl -f 'mwlog'

  Changes the file names that match mwlog in the current directory to mxlog:
  ./bulkrn.pl -f 'mwlog' -c 's/mwlog/mxlog/' -go

  List the files that match to mwlog in the current directory.
  See what portions of the file name are captured in upto 9 back reference
  values:
  ./bulkrn.pl -f 'mxlog\.wfiejb(\d+)(\.\d+)'

  Renumber the value after wfiejb from 1-n to 300-n resequencing the value with
  an increment of 1:
  ./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go

  Renumber the value after wfiejb from 1-n to 2-n resequencing the value with an
  increment of 2, formatting the number with 3 digits and leading zeros, and
  changing "mxlog" to "mwlog":
  ./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' \
              -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/' -go

  Uppercase the text portion of the file name.
  ./bulkrn.pl -f '(mwlog.wfiejb).*' -c 's/($1)/\U$1\E/' -go

  Run a test to renumber the value after "wfiejb" from 1 to 30, resequencing the
  value in incrments of 2; Placing the file into testdir/<date> where date comes
  from the file name; And strip the date from the file name when it is placed
  into its destination directory:
  ./bulkrn.pl -f '(mwlog.wfiejb)(\d+)(\.\d+)$' -r 2:1-:30 -s 2 -d 3 \
              -c 's:((.*)\.(\d+))$:testdir\/$3\/$2:' -a
--- Testing Rename Operations...
*** Only Tested, no files have been renamed.
=== Bulk Renames will be Successful. Final File List...
   testdir/20100701/mwlog.wfiejb030  =was=  mwlog.wfiejb1.20100701
   testdir/20100701/mwlog.wfiejb032  =was=  mwlog.wfiejb2.20100701
   testdir/20100701/mwlog.wfiejb034  =was=  mwlog.wfiejb3.20100701
   testdir/20100701/mwlog.wfiejb036  =was=  mwlog.wfiejb4.20100701
   testdir/20100701/mwlog.wfiejb038  =was=  mwlog.wfiejb5.20100701

=head2 References

  man perlre - Perl Regular Expressions

=cut


