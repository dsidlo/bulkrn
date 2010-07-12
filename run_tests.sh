#!/bin/sh

rm -f ./MWLOG.*
rm -f ./mwlog.*
rm -f ./mxlog.*

./makeFiles.sh

echo '***** test 1 *****'
./bulkrn.pl -f 'mwlog' > lastTest.out
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 1"
    cat lastTest.out
    exit 1;
fi

echo '***** test 2 *****'
./bulkrn.pl -f 'mwlog' -c 's/mwlog/mxlog/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 2"
    cat lastTest.out
    exit 1;
fi

echo '***** test 3 *****'
./bulkrn.pl -f 'mxlog\.wfiejb(\d+)(\.\d+)' > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 3"
    cat lastTest.out
    exit 1;
fi

echo '***** test 4 *****'
./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 4"
    cat lastTest.out
    exit 1;
fi

echo '***** test 5 *****'
./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 5"
    cat lastTest.out
    exit 1;
fi

echo '***** test 6 *****'
./bulkrn.pl -f '(mwlog.wfiejb).*' -c 's/($1)/\U$1\E/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 6"
    cat lastTest.out
    exit 1;
fi

echo '***** test 7 *****'
./bulkrn.pl -f '(MWLOG.WFIEJB\d+\.)(\d\d\d\d)(\d\d\d\d)' -c 's/($3)/\.BunnyKisses\.$1/' -go > lastTest.out 2>&1
if [ $? -ne 0 ]
then
    echo "+++ Failed: test 7"
    cat lastTest.out
    exit 1;
fi

echo '***** test 8 *****'
./bulkrn.pl -f '(MWLOG.WFIEJB\d+\.)(\d\d\d\d)(\d\d\d\d)' -c 's/.*/README/' -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 8 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 9 *****'
./bulkrn.pl -f 'MWLOG.WFIEJB(\d+)\.(\d\d\d\d)(\d\d\d\d)' -r 1:1-:200 -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 9 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi

echo '***** test 10 *****'
./bulkrn.pl -f 'MWLOG.WFIEJB(\d+)\..*' -r 1:1-:200 -go > lastTest.out 2>&1
if [ $? -eq 0 ]
then
    echo "+++ Failed: test 10 (Program should have failed)."
    cat lastTest.out
    exit 1;
fi
