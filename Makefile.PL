use inc::Module::Install;
name 'Kamaitachi';
all_from 'lib/Kamaitachi.pm';

test_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
