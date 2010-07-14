#!/usr/bin/perl

#
# Renumber files.
#

# Done:
# * Fix prob using / in -c subst with a dir in path.
# * Session Level Undo.
#   - Save Undo info into ~/.bulkrn
#   - bulkrn -undo
#     Will display what will be undone.
#   - bulkrn -undo -go
#     Will perform the real undo, but will back out if it can't be completely undone.
#   - bulkrn -undo -go --force
#     Will perform and force through as much as it can of the real undo.
# * Undo Test needs to look for existing files.
#   If file already exists, make sure it is not read-only.
# * Add read-only check for existing files in test mode.
# * Create an md5 string to ensure that undo files are not tampered with.
#   = Using Digest::MD5
# * Read Only Test: open file for append, use -w $FH to test for writeable.
#   - Needs testing.
# * Perform Session Undo test on pesudo dir to ensure that files exist
#   before being renamed.
# * Add docs for session level undo.
# * Re-Seq undo files via backticks does not work via ActiveState Perl.
#   = Make Re-Sequencing undo files a subroutine.

use Getopt::Long;
use Digest::MD5 qw(md5_hex);

use strict;

my $VERSION = "0.0.2";

my $sessionUndos  = 10;
my $mkdirStr = '.~=#[mkdir]@+-.';
my $bulkrnDir = $ENV{HOME}.'/.bulkrn';


my ($fnPat, $reNums,   $seqOpt, $helpOpt, $testOpt, $verbOpt, $fmtOpt);
my ($roOpt, $substOpt, $runOpt, $dirOpt,  $undoOpt, $doUndo);

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
			      "noUndo|n"       => \$undoOpt,  # Disable Session Undo.
			      "undo"           => \$doUndo,   # Perform the session undo.
    );

# If the noUndo option is set, we don't want to save the session undo file.
$undoOpt = !$undoOpt;

# print "==> undoOpt[$undoOpt]\n";
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
    die "The specified [SourceDir] does not exist! [$srcDir]\n";
}

# Just run a File Pattern Test...
if ( ($fnPat ne '') && ($reNums == undef) && ($substOpt eq '') ) {
    print "Testing the FilePattern...\n";
    chdir $srcDir || die "Failed to chdir to [SourceDir]! [$srcDir]\n";
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
		if ($fn[$i] ne '') {
		    print "$i\($fn[$i]\) ";
		}
	    }
	    print "\n";
        }
    }
    close $DF;
    exit;
}

if ($doUndo) {
    &undoLastSession();
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
    if ($substOpt =~ m/^s([\:\/\~\|\=\+\~\|\_\?])/i) {
	$ss = $1;
	(undef, $s1, $s2, $s3) = split (/(?<!\\)$ss/, $substOpt);
	if (($s1 eq '') || ($s2 eq '')) {
	    # Error Condition in substituion string.
	    die "Could not parse --change|-c option [$substOpt]!\n";
	}
    } else {
	# Error Condition in substituion string.
	print "Could not parse --change|-c option [$substOpt]!\n";
	print "[SubstOpt] Must be a regexp substitution operation such as s/<Str>/<Subst>/.\n";
	print "           The Separation char may be any one of [\:\/\~\|\=\+\~\|\_\?].\n";
	die;
    }
}

my $nDiff = $nn - $n1;

chdir $srcDir || die "Failed to chdir to [SourceDir]! [$srcDir]\n";
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
    $origFn{$fn} = $fn;
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


if ($testOpt && (!$roOpt)) {
    
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
		    if (exists $FinRn{$newFn}) {
			# Overwrites because multiple files are renamed to the same file name.
			print "\nTest: *** 1) Rename would be aborted because multiple files would be renamed to a the same name! ($newFn)\n";
			die;
		    } else {
			# Perform rename operation on psudeo dir.
			$testRns{$newFn} = $testRns{$fn};
			undef $testRns{$fn};
			push (@finRn, $newFn);
			$FinRn{$newFn} = $fn;
		    }
		    &verbose(3,"Test: Renamed $fn to $newFn\n");
		} else {
		    # The new file name already exists in the current dir.
		    if (exists $FinRn{$newFn}) {
			# Overwrites because multiple files are renamed to the same file name.
			print "\nTest: *** 2) Rename would be aborted because multiple files would be renamed to a the same name! ($newFn)\n";
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
		    # Perform rename operation in psudeo dir.
		    $testRns{$newFn2} = $testRns{$rnf};
		    delete $testRns{$rnf};
		    &verbose(3,"Test: Renamed $rnf to $newFn2\n");
		    $rn3{$newFn2} = $rn2{$rnf};
		    $fileRenamed = 1;
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
		# Perform rename operation in psudeo dir.
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
		if (exists $FinRn{$newFn}) {
		    # Overwrites because multiple files are renamed to the same file name.
		    print "\n*** 1) Rename aborted because multiple files would be renamed to a the same name! ($newFn)\n";
		    &undoRenames();
		    die;
		} else {
		    # File is not in the current dir or path.
		    rename ($fn, $newFn) || print "Failed to rename file ($fn -> $newFn)\n";
		    push (@rnDone, "RN:$fn:$newFn");
		    &verbose(2,"Renamed $fn to $newFn\n");
		    $FinRn{$newFn} = $fn;
		}
	    } else {
		# File exists in the current dir or path.
		if (exists $FinRn{$newFn}) {
		    # Overwrites because multiple files are renamed to the same file name.
		    print "\n*** 2) Rename aborted because multiple files would be renamed to a the same name! ($newFn)\n";
		    &undoRenames();
		    die;
		}
		# print "==> [$newFn] origFn[".join(", ",(keys %origFn))."]\n";
		if (-f $newFn) {
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
	    push (@rnDone, "P1:$rnf:$newFn2");
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
	    push (@rnDone, "P2:$rnf:$newFn");
	    &verbose(2,"Renamed $rnf to $newFn\n");
	} else {
	    print "\n*** Phase2 Existing file would be over-written and lost! ($newFn)\n";
	    &undoRenames();
	    die;
	}
    }
}

# If we make it this far, renames completed successfully.
# Now save out undos to a file "Session Undos".
if ($undoOpt) {
    &verbose(1,"=== Saving session undo file.\n");
    
    if (! -d "$bulkrnDir") {
	&verbose(0,"--- Created bulkrnDir [$bulkrnDir].\n");
	mkdir "$bulkrnDir" || warn "*** Could not create $bulkrnDir directory!\n";
    }
    if (-d "$bulkrnDir") {
	# Save the undo array to a file.
	# - Read undo files in the dir.
	my @undoFiles = (sort glob "$bulkrnDir/undo_*");
	my ($lastFile, $undoDir, $lastNum);
	if (@undoFiles) {
	    &verbose(0,"--- Found [@".@undoFiles."|\$\#".$#undoFiles."] undo files found in [$bulkrnDir].\n");
	    $lastFile = $undoFiles[$#undoFiles];
	    if ($lastFile =~ /^(.*)\/(undo_)(\d+)$/) {
		($undoDir, $lastNum) = ($1, $3);
		$lastNum++;
	    } else {
		warn "*** Failed to parse Session Undo file name [$lastFile]!";
	    }
	} else {
	    &verbose(0,"--- No undo files found in [$bulkrnDir].\n");
	    $lastNum = 1;
	    $undoDir = $bulkrnDir;
	}
	# - Create next file name.
	my $nextFile = $undoDir.'/undo_'.sprintf "%05d",$lastNum;
	# - Dump data into file.
	&verbose(0,"--- Creating a new undo file. [$nextFile]\n");
	if (open(my $UF, "> $nextFile")) {
	    #   - Make sure file begins with SourceDir.
	    my $dt = `date`; chop $dt;
	    unshift(@rnDone, "UndoSession: $dt");
	    unshift(@rnDone, "SourceDir: $srcDir");
	    my $undoTxt = join("\n",@rnDone)."\n";
	    my $digest = md5_hex($undoTxt);
	    unshift(@rnDone, "MD5 Sig: $digest");
	    $undoTxt = join("\n",@rnDone)."\n";
	    printf $UF $undoTxt;
	    close $UF;
	} else {
	    warn "*** Failed to create a new session undo file! [$nextFile]\n";
	}
	
	# - Make sure that there are only n undo session files
	#   - Too many, delete older ones, renumber.
	my $filesUnlinked = 0;
	if (($#undoFiles+1) >= $sessionUndos) {
	    &verbose(0,"--- Deleting some session undo files.\n");
	    for (my $i=0; $i<=($#undoFiles - ($sessionUndos - 1)); $i++) {
		unlink($undoFiles[$i]) || warn "Failed to remove bulkrn undo session file ($undoFiles[$i])!\n";
		$filesUnlinked ++;
	    }
	    &verbose(0,"Unlinked [$filesUnlinked] files.\n");
	}
	if ($filesUnlinked) {
	    # Renumber session files.
	    &verbose(0,"--- Re-Sequencing session undo files.\n");
	    my $retVal = &reseqUndoFiles($bulkrnDir, '(undo_)(\\d+)');
	    if (!$retVal) {
		warn "*** Failed to resequence undo session files!\n";
	    }
	}

    } else {
	warn "*** $bulkrnDir directory does not exist! Session Undo file was not saved!\n";
    }
}

&verbose(1,"*** Rename Operations Completed.\n");

sub undoLastSession {

    # Read undo file.
    my @undoFiles = (sort glob "$bulkrnDir/undo_*");
    my $lastFile = $undoFiles[$#undoFiles];

    my @undoOps;

    if ($lastFile eq '') {
	die "*** There are No more bulkrn Session Files available!\n";
    } elsif (open(my $UF, "< $lastFile")) {
	@undoOps = <$UF>;
	@undoOps = grep s/\n//g, @undoOps;
	my $digest = shift(@undoOps);
	# print "==> digest:[$digest]\n";
	if ($digest =~ /^MD5 Sig: ([0-9a-f]+)/) {
	    $digest = $1;
	    my $undoTxt = join("\n",@undoOps)."\n";
	    my $digest2 = md5_hex($undoTxt);
	    if ($digest ne $digest2) {
		print "==> [$digest] [$digest2]\n";
		print "================\n$undoTxt===============\n";
		die "*** Session Undo File [$lastFile] seems to have been altered! Session will not be undone!\n";
	    } else {
		&verbose(2,"--- Digest Value is OK.\n");
	    }
	} else {
	    die "Failed to recognize This bulkrn Undo Session File! [$lastFile]\n";
	}
    } else {
	warn "*** Failed to open undo session file! [$lastFile]\n";
    }

    my $srcDir   = shift @undoOps;
    my $undoSess = shift @undoOps;
    if (    ($undoSess !~ /UndoSession: /)
	 || ($srcDir   !~ /SourceDir: /  ) ) {
	die "Failed to recognize This bulkrn Undo Session File! [$lastFile]\n";
    }
    &verbose(0,"=== [$undoSess]\n");
    $srcDir =~ s/SourceDir: //;
    &verbose(1,"chdir [$srcDir]\n");
    # ChDir to SourceDir.
    chdir $srcDir || die "Undo Session failed to chdir to [$srcDir]!\n";

    # Execute Undos.
    # - Failure (Log it and Continue)
    # Delete Undo Session File.
    # --undo (test and see undo final results)
    # --undo -go Do the operations on the fs.
    @rnDone = @undoOps;
    &undoRenames();
    if (!$testOpt) {
	unlink ($lastFile) || die "*** Failed to removed bulkrn Undo Session File! [$lastFile]\n";
	&verbose(0,"*** Session Undo file removed after being processed. [$lastFile]\n");
    }
}

sub undoRenames {

    my %testRns; # psuedo dir for testing file system operations.

    for (my $i=$#rnDone; $i>=0; $i--) {
	$rnDone[$i] =~ m/^([^\:]+)\:([^\:]+)\:(.*)$/;
	my ($fop, $on, $nn) = ($1, $2, $3);
	if ($testOpt) {
	    if ($on eq $mkdirStr) {
		# Make sure dir exists.
		# - Fail if it does not.
		# Make sure that dir is writable.
		# - Fail if not.
		if (-d $nn) {
		    if (-w $nn) {
			&verbose(0, "Test Undo: Directory Creation [$nn].\n");
		    } else {
			&verbose(0, "*** Test Undo: Directory Creation can not be undone because directory [$nn] is not writeable!\n");
		    }
		} else {
		    &verbose(0, "*** Test Undo: Directory Creation can not be undone because directory [$nn] does not exist!\n");
		}
	    } elsif ($fop =~ /(RN|P1|P2)/) {
		# Make sure that new file exists and old does not.
		# Make sure that file is writable.
		# - Fail if not.
		if ($fop eq 'P2') {
		    # Expect file to be there.
		    # - Perform operation on pseudo dir.
		    # - When P1 operation occurs $on should exist on the pseudo dir.
		    if (-f $on) {
			if (-w $nn) {
			    $testRns{$nn} = $on;
			    &verbose(1, "Test Undo: Phase2-Rename [$on] to [$nn]\n");
			} else {
			    &verbose(0, "*** Test Undo: Phase2-Rename can not be undone because file [$nn] is not writeable!\n");
			}
		    } else {
			&verbose(0, "*** Test Undo: Phase2-Rename Undo Failed! Original File [$on] was not on found on the file system!\n");
		    }
		} elsif ($fop eq 'P1') {
		    if (exists $testRns{$on}) {
			# This is good, we expect the old name to exist for the Phase1 rename.
			delete $testRns{$on};
			$testRns{$nn} = $on;
			&verbose(1, "Test Undo: Phase1-Rename [$on] to [$nn]\n");
		    } else {
			&verbose(0, "*** Test Undo: Phase1-Rename Undo Failed! Original File [$on] was not on found in the pseudo dir!\n");
		    }
		} elsif ($fop eq 'RN') {
		    if (-f $nn) {
			if (-w $nn) {
			    &verbose(0, "Test Undo: Rename [$nn =BackTo= $on].\n");
			} else {
			    &verbose(0, "*** Test Undo: Rename can not be undone because file [$nn] is not writeable!\n");
			}
		    } else {
			&verbose(0, "*** Test Undo: Rename can not be undone because file [$nn] does not exist!\n");
		    }
		}
	    } else {
		die "*** Test Undo: Unknown file operation [$fop] in undo line [$rnDone[$i]]!\n";
	    }
	} else {
	    if ($on eq $mkdirStr) {
		# Undo Created Dir (If Empty)
		my $dir = $nn;
		# regular files...
		push (my @files, glob $dir."*");
		# + hidden files...
		push (   @files, glob $dir.".*");
		# less . (currentDir) and .. (priorDir)
		@files = grep $_ !~ /\.{1,2}$/, @files;
		if ($#files < 0) {
		    rmdir $dir || die "*** Undo unlink dir failed! ($dir)\n";
		    &verbose(1,"Created Dir [$dir] was empty and was removed.\n");
		} else {
		    print "*** Failed to undo dir creation! Dir was not empty! ($dir)\n";
		}
	    } elsif (! -f $on) {
		if (-f $nn) {
		    rename ($nn, $on) || die "Undo Rename failed! ($nn -> $on)\n";
		    &verbose(1,"Rename was undone [$nn =BackTo= $on].\n");
		} else {
		    die "*** Undo Rename Failed, file does not exist ($nn)!\n";
		}
	    } else {
		# This should not occur.
		die "*** Undo Rename Failed, Existing file would be over-written and lost! ($on)\n";
	    }
	}
    }
    if ($testOpt) {
	&verbose(0,"*** Rename Actions have been Tested. No actions have been performed on the file system.\n");
    } else {
	&verbose(0,"*** Rename Actions have been undone.\n");
    }
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
	    if (-d $dp) {
		# If the directory exists, push the dirs files
		# into 
	    }
	    if (!exists $nd->{$dp}) {
		$nd->{$dp} = 1;
		$madeNewDir = 1;
	    }
	} elsif ($dirOpt) {
	    if (! -d $dp) {
		mkdir $dp || die "Failed to create directory ($dp) for ($newFn)!\n";
		$nd->{$dp} = 1;
		push(@rnDone, 'MD:'.$mkdirStr.':'.$dp);
		$madeNewDir = 1;
	    }
	} elsif (!$testOpt) {
	    if (! -d $dp) {
		die "The directory ($dp) does not exist! Perhapse you need to use the -autoDir option!\n";
	    }
	}
    }

    # print "=> madeNewDir[$madeNewDir]\n";
    return $madeNewDir;
}

sub reseqUndoFiles {
    my ($dir) = @_;
    chdir $dir || die "*** \&reseqUndoFiles() chdir Failed: Could not chdir to [$dir]!\n";
    my @files = (sort glob "undo_*");
    for (my $i=0; $i<=$#files; $i++) {
	my $on = $files[$i];
	my $nn = $on;
	my $num = sprintf "%05d", $i+1;
	$nn =~ s/(\D+\_)(\d+)/$1${num}/;
	rename ($on, $nn) || die "*** \&reseqUndoFiles() Rename Failed: Could not rename [$on] to [$nn]!\n";
    }
    return 1;
}

sub verbose {
    my ($lvl, $msg) = @_;

    if (($lvl == 0) || ($verbOpt >= $lvl)) {
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

  An additional level of safety is maintained with regard to file name
  information through session level undo. Consider that a session is when
  bulkrn.pl is called with the -go parameter. If all rename operations occur
  successfully for that session, the undo script for that execution of
  the bulkrn.pl program is saved out to a file in ~/.bulkrn/. Thus executing
  "bulkrn.pl -undo" will rollback the operations of the most recent execution
  of bulkrn.pl. By default, up to 10 prior sessions are saved may be undone.

  usage: bulkrn.pl [SourceDir]
                   [-a|-h|-t|-v-|-x] 
                   -f [FilePattern] 
                   [-r [br:n1|n1-n2:nn[!]]]
                   [-s [SequentialIncrement]]
                   [-d [ZeroPaddedLength]]
                   [-c [SubstitutionPattern]]
                   [-go]
		   [-noUndo]
		   [-undo]

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

\$ \.\/bulkrn.pl -f '(mwlog\\.wfiejb\\d+)(\\.\\d\\d\\d\\d)(08\\d\\d)' 
Testing the FilePattern...
FilePattern Test: applog.cluster1.20100810 => $1(applog.cluster1) $2(.2010) $3(0810)
FilePattern Test: applog.cluster1.20100811 => $1(applog.cluster1) $2(.2010) $3(0811)
FilePattern Test: applog.cluster1.20100812 => $1(applog.cluster1) $2(.2010) $3(0812)
...

 The file name pattern...

  -filePat|-f [filePattern RegExpp]

  '(applog\\.cluster)(\\d+)(\\..*)'
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

  --change|-c [SubstitutionPattern] (-c 's/applog/mxx/i')
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
  6. An additional level of safety is maintained with regard to file name
     information through session level undo. Consider that a session is when
     bulkrn.pl is called with the -go parameter. If all rename operations occur
     successfully for that session, the undo script for that execution of
     the bulkrn.pl program is saved out to a file in ~/.bulkrn/. Thus executing
     "bulkrn.pl -undo" will rollback the operations of the most recent execution
     of bulkrn.pl. By default, up to 10 prior sessions are saved may be undone.

  Works on unix and cygwin and with ActiveState-Perl.

=head1 SYNOPSIS

  usage: bulkrn.pl [SourceDir]
                   [-h|-t|-v-|-x]
                    -f [FilePattern]
                   [-r [br:n1|n1-n2:nn[!]]]
                   [-s [SequentialIncrement]]
                   [-d [ZeroPaddedLength]]
                   [-c [SubstitutionString]]
                   [-go]
                   [-noUndo]
                   [-undo]

  If not specified [SourceDir] defaults to the current dir './'.

  -filePat|-f [FilePattern]
  A regexp that matches to a file in the current directory and splits it into as
  many as 9 back-reference values where the back-reference values 
  (referenced by the -reNum/br) must always be an integer field, which will
  be renumbered. Using this option alone will list the files that match the
  regexp in the current directory.  Every portion of the file name that will
  become part of the new name must be held in a back reference. If it is not,
  that portion of the file name will be removed from the new file name.

  -reNum|-r [br:n1|n1-|n1-n2:nn[!]]
      br: The back-reference index whos value will change to nn 
          (which increments, or which is static).
      n1: The Only value that will change.
     n1-: Change all values from n1 and greater.
   n1-n2: Change all values from n1 to n2.
      nn: Change n1 to this new value (nn).
     nn!: Don\'t increment nn relative to n1-n2. nn stays static.

  Perform a test only.

=head2 [--verbose | -v]

  Print details of the renaming process.
  There are 3 levels of verbosity "-v", "-v -v" and "-v -v -v"

=head2 [--change | -c] [SubstitutionPattern] (-c 's/applog/mxx/i')

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

=head2 [--undo]

  Session level undo files are saved to ~/.bulkrn/undo_*.
  These undo bulk-rename operations that have been committed to the file
  system. By default, bulkrn.pl will save upto 10 session level undo files.
  (See the \$sessionUndos variable in the source code).

=head2 [--noUndo]

  This option can be used when bulkrn is used within a script.
  With this option specified, bulkrn.pl will not save off session level
  undo files. 

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

=head1 AUTHOR -


=head1 APPENDIX

=head2 Examples

  List the files that match to applog in the current directory:
  ./bulkrn.pl -f 'applog'

  Changes the file names that match applog in the current directory to mxlog:
  ./bulkrn.pl -f 'applog' -c 's/applog/mxlog/' -go

  List the files that match to applog in the current directory.
  See what portions of the file name are captured in upto 9 back reference
  values:
  ./bulkrn.pl -f 'mxlog\.cluster(\d+)(\.\d+)'

  Renumber the value after cluster from 1-n to 300-n resequencing the value with
  an increment of 1:
  ./bulkrn.pl -f '(mxlog\.cluster)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go

  Renumber the value after cluster from 1-n to 2-n resequencing the value with
  an increment of 2, formatting the number with 3 digits and leading zeros, and
  changing "mxlog" to "applog":
  ./bulkrn.pl -f '(mxlog\.cluster)(\d+)(\.\d+)' \
              -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/applog/' -go

  Uppercase the text portion of the file name.
  ./bulkrn.pl -f '(applog.cluster).*' -c 's/($1)/\U$1\E/' -go

  Run a test to renumber the value after "cluster" from 1 to 30, resequencing
  the value in incrments of 2; Placing the file into testdir/<date> where date
  comes from the file name; And strip the date from the file name when it is
  placed into its destination directory:
  ./bulkrn.pl -f '(applog.cluster)(\d+)(\.\d+)$' -r 2:1-:30 -s 2 -d 3 \
              -c 's:((.*)\.(\d+))$:testdir\/$3\/$2:' -a
--- Testing Rename Operations...
*** Only Tested, no files have been renamed.
=== Bulk Renames will be Successful. Final File List...
   testdir/20100701/applog.cluster030  =was=  applog.cluster1.20100701
   testdir/20100701/applog.cluster032  =was=  applog.cluster2.20100701
   testdir/20100701/applog.cluster034  =was=  applog.cluster3.20100701
   testdir/20100701/applog.cluster036  =was=  applog.cluster4.20100701
   testdir/20100701/applog.cluster038  =was=  applog.cluster5.20100701

  Test Session Level Undo of the last set of file operations actually performed
  to the file system:
  ./bulkrn.pl -undo
 
=head2 References

  man perlre - Perl Regular Expressions

=cut


