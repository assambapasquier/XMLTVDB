#!/bin/bash

set -x

(
	pg_dump --username wwwdata --no-owner --no-privileges --schema-only \
		--schema xmltv --format p fastcat
	pg_dump --username wwwdata --no-owner --no-privileges --data-only \
		--schema xmltv --table xmltv.cv_interest --format p fastcat
) \
	| grep -v ^-- \
	| sed -e 's/xmltv/@@SCHEMA@@/g' \
	| perl -e '$/=undef;while(<>){s/\r\n/\n/g;s/\n\n\n/\n/g;print}' \
	>schema.sql

