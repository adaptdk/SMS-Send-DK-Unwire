#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 2;

BEGIN {
  require_ok( 'SMS::Send' );
  use_ok( 'SMS::Send::DK::Unwire' ) || print "Bail out!\n";
}

diag( "Testing SMS::Send::DK::Unwire $SMS::Send::DK::Unwire::VERSION, Perl $], $^X" );
