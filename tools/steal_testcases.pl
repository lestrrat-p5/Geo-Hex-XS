use strict;
use File::Spec;

my $steal_from = '../Geo-Hex/t/';

opendir(DIR, $steal_from) or die;
while ( my $e = readdir(DIR) ) {
    next if $e =~ /^\.+/;

    my $src = File::Spec->catfile($steal_from, $e);
    my $dst = File::Spec->catfile('t', $e);

    next unless -f $src;

    open my $src_fh, '<', $src or die "Couldn't open $src";
    open my $dst_fh, '>', $dst or die "Couldn't open $dst";

    while ( <$src_fh> ) {
        s/(Geo::Hex1?)/$1::XS/g;
        print $dst_fh $_;
    }

    close $dst_fh;
    close $src_fh;
}