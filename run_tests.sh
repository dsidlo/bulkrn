#!/bin/sh

rm -f ./MWLOG.*
rm -f ./mwlog.*
rm -f ./mxlog.*
rm -fr ./testdir
rm -f lastTest.out

if [ "$1" == "clean" ]
then
  exit 1;
fi

if [ "$1" == "" ]
then
    prog="./bulkrn.pl"
    echo "Running test using unix/cygwin Perl..."
else
    if [ "$1" == "active" ]
    then
	prog="/cygdrive/c/Perl/bin/perl ./bulkrn.pl"
	echo "Running test using ActiveState Perl..."
    else
	echo "Unknown parameter [$1]!"
	exit
    fi
fi

./makeFiles.sh

echo '***** test 1 *****'
# File Pattern test.
$prog -f 'mwlog' > lastTest.out
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 1"
    cat lastTest.out
    exit 1;
fi

echo '***** test 2 *****'
# Change mwlog to mxlog.
$prog -f 'mwlog' -c 's/mwlog/mxlog/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 2"
    cat lastTest.out
    exit 1;
fi

echo '***** test 3 *****'
# File Pattern test with Back-Refs.
$prog -f 'mxlog\.wfiejb(\d+)(\.\d+)' > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 3"
    cat lastTest.out
    exit 1;
fi

echo '***** test 4 *****'
# Resequence wfiejb<value> from 1-n to 300-n, incrementing by 1.
$prog -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 4"
    cat lastTest.out
    exit 1;
fi

echo '***** test 5 *****'
# Resequence wfiejb<value> from 1-n to 2-n, incrementing by 1, formating 3 digits zero padded.
$prog -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 5"
    cat lastTest.out
    exit 1;
fi

echo '***** test 6 *****'
# Upper-case the (mwlog.wfiejb) portion of the file name.
$prog -f '(mwlog.wfiejb).*' -c 's/($1)/\U$1\E/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 6"
    cat lastTest.out
    exit 1;
fi

echo '***** test 7 *****'
# Add ".BunnyKisses." after WFIEJB<value> and <Date>.
$prog -f '(MWLOG.WFIEJB\d+\.)(\d\d\d\d)(\d\d\d\d)' -c 's/($3)/\.BunnyKisses\.$1/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 7"
    cat lastTest.out
    exit 1;
fi

echo '***** test 8 *****'
# Try to rename all files to README. (We Expect a Failure Result).
$prog -f '(MWLOG.WFIEJB\d+\.)(\d\d\d\d).*(\d\d\d\d)' -c 's/.*/README/' -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 8 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 9 *****'
# File Pattern will not pick up a file. (We Expect a Failure Result).
$prog -f 'MWLOG.WFIEJB(\d+)(\.\d\d\d\d)(\d\d\d\d)' -r 2:1-8:20 -s 1 -d 3 -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 9 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 10 *****'
# Resquence files to existing file names. (We Expect a Failure Result).
$prog -f '(MWLOG.WFIEJB)(\d+)(\.\d\d\d\d)(.*)(\d\d\d\d)' -r 2:1-8:20 -s 1 -d 3 -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 10 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 11 *****'
# Multiple file names would be renamed the same name. (Expected to Fail)
$prog -f 'MWLOG.WFIEJB(\d+)\..*' -r 1:1-:200 -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 11 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 12 *****'
# Moves files into a sub dirs "testdirs/<date>" based on date from the file name.
# Strip the date and "BunnyKisses" from the file name.
$prog -f 'MWLOG.WFIEJB\d+\.(\d+)\.(\D+)\.(\d+)$' -c 's:((.*)\.(\d+)\.(\D+)\.(\d+))$:testdir\/$3$5\/$2:' -a -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 12."
    cat lastTest.out
    exit 1;
fi

ls -aRF testdir

./run_tests.sh clean
