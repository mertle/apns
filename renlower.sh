#!/bin/sh
l=`echo $1 | tr A-Z a-z`
echo $l
mv $1 $l
