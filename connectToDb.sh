#!/bin/bash

# Declarations
DB_SERVER='pampero.itba.edu.ar'
DB_ADDRESS='bd1.it.itba.edu.ar'
DB_PORT='5432'
# endDeclarations

if [ $# -lt 1 ]
then
	echo "Must provide username for $DB_SERVER"
	exit 1
fi

ssh $1@$DB_SERVER -L $DB_PORT:$DB_ADDRESS:$DB_PORT
ls