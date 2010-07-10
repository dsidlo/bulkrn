#!/bin/sh

rm -f ./MWLOG.*
rm -f ./mwlog.*
rm -f ./mxlog.*

./makeFiles.sh

echo '***** test 1 *****'
./bulkrn.pl -f 'mwlog'

echo '***** test 2 *****'
./bulkrn.pl -f 'mwlog' -c 's/mwlog/mxlog/' -go

echo '***** test 3 *****'
./bulkrn.pl -f 'mxlog\.wfiejb(\d+)(\.\d+)'

echo '***** test 4 *****'
./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go

echo '***** test 5 *****'
./bulkrn.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/' -go

echo '***** test 6 *****'
./bulkrn.pl -f '(mwlog.wfiejb).*' -c 's/($1)/\U$1\E/' -go

echo '***** test 7 *****'
./bulkrn.pl -f '(MWLOG.WFIEJB\d+\.)(\d\d\d\d)(\d\d\d\d)' -c 's/($3)/\.BunnyKisses\.$1/' -go