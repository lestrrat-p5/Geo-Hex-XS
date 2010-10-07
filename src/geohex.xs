#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "xshelper.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int X60POW[] = {
    1,
    60,
    3600,
    216000,
    12960000,
    77600000
};

#define H_KEY_COUNT 62
char H_KEY[] = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C',
    'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
};

#define H_BASE  (20037508.34)
#define H_DEG   (M_PI * ( 30.0 / 180.0 ))
#define H_K     (tan(H_DEG))
#define H_RANGE 21
#define GEOHEX_CODE_BUFSIZ 256

typedef struct {
    double lat;
    double lon;
    double x;
    double y;
    char code[ GEOHEX_CODE_BUFSIZ ];
} PerlGeoHexZone;

STATIC_INLINE double
hex_size (double level) {
    return (H_BASE / pow(2.0, level)) / 3.0;
}

STATIC_INLINE int
loc_2xy ( double lon, double lat, double *x, double *y ) {
    *x = lon * H_BASE / 180;
    *y = H_BASE * log( tan( (90 + lat ) * M_PI / 360 ) ) / ( M_PI / 180 ) / 180;
    return 1;
}

STATIC_INLINE int
xy_2loc ( double x, double y, double *lon, double *lat ) {
    *lon = ( x / H_BASE ) * 180;
    *lat = ( y / H_BASE ) * 180;
    *lat = 180 / M_PI * ( 2 * atan( exp( *lat * M_PI / 180 ) ) - M_PI / 2 );
    return 1;
}

STATIC_INLINE int
get_code_by_xy( char *code, int x, int y, double max, int level ) {
    int i = 0;
    char buf[3];

    snprintf(code, GEOHEX_CODE_BUFSIZ, "%c", H_KEY[ level % 60 ] );

    for ( i = 4; i > 0; i-- ) {
        double current = (double) X60POW[i];

        if (max >= current / 2) {
            int above = X60POW[i + 1];
            snprintf(buf, 3, "%c%c",
                H_KEY[ ((int) floor( ( x % above) / current )) ],
                H_KEY[ ((int) floor( ( y % above) / current )) ]
            );
            strncat(code, buf, GEOHEX_CODE_BUFSIZ);
        }
    }

    snprintf(buf, 3, "%c%c",
        H_KEY[ ((int) floor( ( x % 3600 ) % 60 ) ) ],
        H_KEY[ ((int) floor( ( y % 3600 ) % 60 ) ) ]
    );
    strncat(code, buf, GEOHEX_CODE_BUFSIZ);

    return 1;
}

static int
get_zone_by_location (PerlGeoHexZone *zone, double lat, double lon, int level) {
    double lon_grid, lat_grid;
    double unit_x, unit_y;
    double h_pos_x, h_pos_y;
    double h_x_0, h_y_0;
    double h_x_q, h_y_q;
    double h_x_abs, h_y_abs;
    double h_x, h_y;
    double h_max;
    double h_lat, h_lon;
    double z_loc_x, z_loc_y;
    double h_size = hex_size(level);

    loc_2xy( lon, lat, &lon_grid, &lat_grid );

    unit_x = 6.0 * h_size;
    unit_y = 6.0 * h_size * H_K;
    h_pos_x = ( lon_grid + lat_grid / H_K ) / unit_x;
    h_pos_y = ( lat_grid - H_K * lon_grid ) / unit_y;
    h_x_0   = floor(h_pos_x);
    h_y_0   = floor(h_pos_y);
    h_x_q   = h_pos_x - h_x_0;
    h_y_q   = h_pos_y - h_y_0;
    h_x     = round(h_pos_x);
    h_y     = round(h_pos_y);

    h_max   = round( H_BASE / unit_x + H_BASE / unit_y );
    if ( h_y_q > -1 * h_x_q + 1 ) {
        if ( ( h_y_q < 2 * h_x_q ) && ( h_y_q > 0.5 * h_x_q ) ) {
            h_x = h_x_0 + 1;
            h_y = h_y_0 + 1;
        }
    } else if ( h_y_q < -1 * h_x_q + 1.0 ) {
        if ( ( h_y_q > ( 2 * h_x_q ) - 1.0 ) && ( h_y_q < ( 0.5 * h_x_q ) + 0.5 ) ) {
            h_x = h_x_0;
            h_y = h_y_0;
        }
    }

    h_lat = ( H_K * h_x * unit_x + h_y * unit_y ) / 2.0;
    h_lon = ( h_lat - h_y * unit_y ) / H_K;

    xy_2loc( h_lon, h_lat, &z_loc_x, &z_loc_y );

    if ( H_BASE - h_lon < h_size ) {
        int tmp;
        z_loc_x = 180;
        tmp = h_x;
        h_x = h_y;
        h_y = tmp;
    }
        
    h_x_abs = abs( h_x ) * 2 + (( h_x < 0 ) ? 1 : 0);
    h_y_abs = abs( h_y ) * 2 + (( h_y < 0 ) ? 1 : 0);

    zone->lat = z_loc_y;
    zone->lon = z_loc_x;
    zone->x   = h_x == 0 ? 0 : h_x;
    zone->y   = h_y == 0 ? 0 : h_y;

    get_code_by_xy( zone->code, (int) h_x_abs, (int) h_y_abs, h_max, level );

    return 1;
}

STATIC_INLINE int
get_index_of_h_key( char k ) {
    int i;
    for ( i = 0; i < H_KEY_COUNT; i++ ) {
        if (H_KEY[i] == k) {
            return i;
        }
    }
    croak("Could not find appropriate H_KEY in given code");
}

static int
get_zone_by_code( PerlGeoHexZone *zone, char *code ) {
    int i;
    int level = get_index_of_h_key( *code );
    double h_size;
    double h_max;
    double unit_x, unit_y;
    double h_x = 0, h_y = 0;
    double h_lon, h_lat;
    double h_lon_x, h_lat_y;

    h_size = hex_size(level);
    unit_x = h_size * 6.0;
    unit_y = h_size * 6.0 * H_K;
    h_max  = round( H_BASE / unit_x + H_BASE / unit_y );

    for (i = 4; i >= 0; i--) {
        if ( h_max >= X60POW[i] / 2 ) {
            int j;
            for ( j = i; j >= 0; j-- ) {
                h_x += get_index_of_h_key( *(code + (i - j) * 2 + 1) ) * X60POW[j];
                h_y += get_index_of_h_key( *(code + (i - j + 1) * 2) ) * X60POW[j];
            }
            break;
        }
    }

    h_x = ((int) h_x % 2) ? -1 * (h_x - 1) / 2.0 : h_x / 2.0;
    h_y = ((int) h_y % 2) ? -1 * (h_y - 1) / 2.0 : h_y / 2.0;

    h_lat_y = ( H_K * h_x * unit_x + h_y * unit_y ) / 2.0;
    h_lon_x = ( h_lat_y - h_y * unit_y ) / H_K;

    xy_2loc( h_lon_x, h_lat_y, &h_lon, &h_lat );

    Copy( code, zone->code, strlen(code), char );
    zone->lat  = h_lat;
    zone->lon  = h_lon;
    zone->x    = h_x == 0 ? 0 : h_x;
    zone->y    = h_y == 0 ? 0 : h_y;

    return 1;
}

static int
get_steps( double start_x, double start_y, double end_x, double end_y ) {
    double x = end_x - start_x;
    double y = end_y - start_y;
    double x_abs = abs(x);
    double y_abs = abs(y);
    double m = 0;

    if (x_abs != 0 && x_abs != 0) {
        if ( x / x_abs > y / y_abs ) {
            m = x;
        } else {
            m = y;
        }
    }

    return x_abs + y_abs + abs(m) + 1;
}

static int
get_zone_by_xy( PerlGeoHexZone *zone, double x, double y, int level ) {
    double h_size = hex_size( level );
    double unit_x = 6 * h_size;
    double unit_y = 6 * h_size * H_K;
    double h_max = round( H_BASE / unit_x + H_BASE / unit_y );
    double h_lat_y = ( H_K * x * unit_x + y * unit_y ) / 2;
    double h_lon_x = ( h_lat_y - y * unit_y ) / H_K;
    double h_lat, h_lon;
    int x_p = x < 0 ? 1 : 0;
    int y_p = y < 0 ? 1 : 0;
    double h_x_abs = abs(x) * 2 + x_p;
    double h_y_abs = abs(y) * 2 + y_p;
    xy_2loc( h_lon_x, h_lat_y, &h_lon, &h_lat );

    get_code_by_xy( zone->code, (int) h_x_abs, (int) h_y_abs, h_max, level );

    zone->lat = h_lat;
    zone->lon = h_lon;
    zone->x = x;
    zone->y = y;
    
    return 1;
}

MODULE = Geo::Hex::XS   PACKAGE = Geo::Hex::XS

PROTOTYPES: DISABLE

SV *
get_zone_by_code( code )
        char *code;
    PREINIT:
        PerlGeoHexZone zone;
    CODE:
        get_zone_by_code( &zone, code);
        {
            dSP;
            int count = 0;
            SV *zone_sv;

            ENTER;
            SAVETMPS;
            PUSHMARK(SP);
            mXPUSHp( "Geo::Hex::XS::Zone", 18 );
            mXPUSHp( "lat",  3 );
            mXPUSHn( zone.lat );
            mXPUSHp( "lon",  3 );
            mXPUSHn( zone.lon );
            mXPUSHp( "x",  1 );
            mXPUSHn( zone.x );
            mXPUSHp( "y",  1 );
            mXPUSHn( zone.y );
            mXPUSHp( "code",  4 );
            mXPUSHp( zone.code, strlen(zone.code) );
            PUTBACK;

            count = call_method( "new", G_SCALAR );
            SPAGAIN;

            if (count < 1) {
                croak("Geo::Hex::XS::Zone::new did not return an object");
            }

            zone_sv = newSVsv(POPs);
            PUTBACK;
            FREETMPS;
            LEAVE;

            RETVAL = zone_sv;
        }
    OUTPUT:
        RETVAL

SV *
get_zone_by_location( lat, lon, level = 16)
        NV lat;
        NV lon;
        IV level;
    PREINIT:
        PerlGeoHexZone zone;
    CODE:
        get_zone_by_location( &zone, lat, lon, level );
        {
            dSP;
            int count = 0;
            SV *zone_sv;

            ENTER;
            SAVETMPS;
            PUSHMARK(SP);
            mXPUSHp( "Geo::Hex::XS::Zone", 18 );
            mXPUSHp( "lat",  3 );
            mXPUSHn( zone.lat );
            mXPUSHp( "lon",  3 );
            mXPUSHn( zone.lon );
            mXPUSHp( "x",  1 );
            mXPUSHn( zone.x );
            mXPUSHp( "y",  1 );
            mXPUSHn( zone.y );
            mXPUSHp( "code",  4 );
            mXPUSHp( zone.code, strlen(zone.code) );
            PUTBACK;

            count = call_method( "new", G_SCALAR );
            SPAGAIN;

            if (count < 1) {
                croak("Geo::Hex::XS::Zone::new did not return an object");
            }

            zone_sv = newSVsv(POPs);
            PUTBACK;
            FREETMPS;
            LEAVE;

            RETVAL = zone_sv;
        }

    OUTPUT:
        RETVAL

SV *
get_zone_by_xy( x, y, level = 16)
        NV x;
        NV y;
        IV level;
    PREINIT:
        PerlGeoHexZone zone;
    CODE:
        get_zone_by_xy( &zone, x, y, level );
        {
            dSP;
            int count = 0;
            SV *zone_sv;

            ENTER;
            SAVETMPS;
            PUSHMARK(SP);
            mXPUSHp( "Geo::Hex::XS::Zone", 18 );
            mXPUSHp( "lat",  3 );
            mXPUSHn( zone.lat );
            mXPUSHp( "lon",  3 );
            mXPUSHn( zone.lon );
            mXPUSHp( "x",  1 );
            mXPUSHn( zone.x );
            mXPUSHp( "y",  1 );
            mXPUSHn( zone.y );
            mXPUSHp( "code",  4 );
            mXPUSHp( zone.code, strlen(zone.code) );
            PUTBACK;

            count = call_method( "new", G_SCALAR );
            SPAGAIN;

            if (count < 1) {
                croak("Geo::Hex::XS::Zone::new did not return an object");
            }

            zone_sv = newSVsv(POPs);
            PUTBACK;
            FREETMPS;
            LEAVE;

            RETVAL = zone_sv;
        }

    OUTPUT:
        RETVAL

NV
get_steps( start_x, start_y, end_x, end_y )
        NV start_x;
        NV start_y;
        NV end_x;
        NV end_y;

SV *
encode_geohex( lat, lon, level = 16)
        NV lat;
        NV lon;
        IV level;
    PREINIT:
        PerlGeoHexZone zone;
    CODE:
        get_zone_by_location( &zone, lat, lon, level );
        RETVAL = newSV(0);
        sv_setpv( RETVAL, zone.code );
    OUTPUT:
        RETVAL

void
decode_geohex( code )
        char *code;
    PREINIT:
        PerlGeoHexZone zone;
        int level;
    PPCODE:
        get_zone_by_code( &zone, code );
        level = get_index_of_h_key( *code );

        mXPUSHn( zone.lat );
        mXPUSHn( zone.lon );
        mXPUSHi( level );
        XSRETURN(3);



