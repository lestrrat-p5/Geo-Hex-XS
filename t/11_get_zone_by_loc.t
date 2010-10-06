#!perl

use strict;
use Test::More;
use Geo::Hex::XS;

require 't/location_data.pl';

my @data = location_data();

plan tests => scalar( @data );

for my $d ( @data ) {
    my ( $lat, $lng, $level, $code ) = @$d;
    my $zone = Geo::Hex::XS::getZoneByLocation( $lat, $lng, $level );
    is( $zone->{ code }, $code, $code );
}

