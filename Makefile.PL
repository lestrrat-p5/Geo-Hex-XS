use inc::Module::Install;

name 'Geo-Hex-XS';
all_from 'lib/Geo/Hex/XS.pm';
use_ppport;
cc_warnings;
cc_src_paths 'src';
use_xshelper '-clean';
tests 't/*.t t/*/*.t';

WriteAll;