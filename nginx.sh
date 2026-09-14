#!/bin/busybox sh
PERL5LIB=""
PERL5LIB=$PERL5LIB:/usr/lib/perl5/vendor_perl/armv8l-linux-thread-multi-64int
PERL5LIB=$PERL5LIB:/usr/lib/perl5/vendor_perl/x86_64-linux-thread-multi
export PERL5LIB
exec /usr/sbin/nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
