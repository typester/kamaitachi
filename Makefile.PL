use inc::Module::Install;
name 'Kamaitachi';
all_from 'lib/Kamaitachi.pm';

test_requires 'Test::More';

requires 'Moose' => '0.06';
requires 'MooseX::LogDispatch';
requires 'Data::AMF' => '0.02004';
requires 'Danga::Socket';
requires 'Danga::Socket::Callback';
requires 'Text::Glob';
requires 'Path::Class';

use_test_base;
auto_include;
WriteAll;
