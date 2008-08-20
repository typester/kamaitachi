use inc::Module::Install;
name 'Kamaitachi';
all_from 'lib/Kamaitachi.pm';

test_requires 'Test::More';

requires 'Moose';
requires 'Data::AMF' => '0.02004';
requires 'Danga::Socket';
requires 'Danga::Socket::Callback';

use_test_base;
auto_include;
WriteAll;
