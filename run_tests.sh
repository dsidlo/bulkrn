#!/bin/sh

rm -f ./mwlog.*
rm -f ./mxlog.*

./makeFiles.sh

echo '***** test 1 *****'
./renumFiles.pl -f 'mwlog'

echo '***** test 2 *****'
./renumFiles.pl -f 'mwlog' -c 's/mwlog/mxlog/' -go

echo '***** test 3 *****'
./renumFiles.pl -f 'mxlog\.wfiejb(\d+)(\.\d+)'

echo '***** test 4 *****'
./renumFiles.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:300 -s 1 -go

echo '***** test 5 *****'
./renumFiles.pl -f '(mxlog\.wfiejb)(\d+)(\.\d+)' -r 2:1-:2 -s 2 -d 3 -c 's/mxlog/mwlog/' -go


