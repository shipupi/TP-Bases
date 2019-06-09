#!/bin/bash

if [ $# -lt 1 ]
then
	echo "Must provide username"
	exit 1
fi

psql -h bd1.it.itba.edu.ar -U $1 -f runImport.sql PROOF
