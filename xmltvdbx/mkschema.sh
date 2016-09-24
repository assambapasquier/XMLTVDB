#!/bin/bash

cat schema.sql \
	| sed -e "s/@@SCHEMA@@/$1/g"
