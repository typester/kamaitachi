use Test::Base;

plan 'no_plan';

use_ok('Kamaitachi::IOStream');

my $stub_socket = bless {};
my $io = Kamaitachi::IOStream->new( socket => $stub_socket );

isa_ok($io, 'Kamaitachi::IOStream');

my $str1 = join '', 'A'..'Z';
my $str2 = join '', 'a'..'z';

$io->push($str1);
$io->push($str2);

is($io->buffer, $str1 . $str2, 'buffer ok');
is($io->buffer_length, bytes::length($str1 . $str2), 'buffer length ok');

is(${ $io->read(1) }, 'A', 'read 1byte ok');
is(${ $io->read(2) }, 'BC', 'read 2bytes ok');

is($io->cursor, 3, 'cursor ok');

is($io->spin, 'ABC', 'spin ok');

is($io->cursor, 0, 'cursor ok after spin');
is($io->buffer_length, bytes::length($str1 . $str2) - 3, 'buffer length ok after spin');

is(${ $io->read(3) }, 'DEF', 'read ok');
$io->reset;
is(${ $io->read(3) }, 'DEF', 'read again ok');
$io->reset;

ok( !$io->read( $io->buffer_length + 1 ), 'return false if read larger data than buffer ok');
is( $io->cursor, 0, 'cursor still 0 ok');

$io->clear;
is( $io->cursor, 0, 'cursor should be 0 after clear');
is( $io->buffer, '', q[buffer should be '' after clear]);
is( $io->buffer_length, 0, 'buffer_length should be 0 after clear');

