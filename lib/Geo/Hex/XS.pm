package Geo::Hex::XS;
use strict;
use XSLoader;
use Exporter 'import';
BEGIN {
    our $VERSION = '0.00001';

    # XXX This EXPORT sucks.
    our @EXPORT = qw(
        getZoneByLocation
        getZoneByCode
        getZoneByXY
        getSteps
        latlng2geohex
        geohex2latlng
    );

    our @EXPORT_OK = qw(
        encode_geohex
        decode_geohex
        get_zone_by_code
        get_zone_by_location
        getZoneByLocation
        getZoneByCode
        getSteps
    );
    XSLoader::load(__PACKAGE__, $VERSION);
}

*getZoneByLocation = \&get_zone_by_location;
*getZoneByCode = \&get_zone_by_code;
*getZoneByXY   = \&get_zone_by_xy;
*latlng2geohex = \&encode_geohex;
*geohex2latlng = \&decode_geohex;

sub getSteps {
    return get_steps( $_[0]->{x}, $_[0]->{y}, $_[1]->{x}, $_[1]->{y} );
}

package
    Geo::Hex::XS::Zone;
sub new {
    my $class = shift;
    bless { @_ }, $class
}
sub lat { $_[0]->{lat} }
sub lon { $_[0]->{lon} }
sub x { $_[0]->{x} }
sub y { $_[0]->{y} }
sub code{ $_[0]->{code} }

1;