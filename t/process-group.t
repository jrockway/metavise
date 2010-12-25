use strict;
use warnings;
use Test::More;
use t::lib::Supervise qw(svcdir supervise);

use ok 'Metavise::Group';

my $done = AE::cv;

my @names = map { "service_$_" } qw/foo bar baz quux gorch OHHAI/;

my @svcs = map {
    $done->begin;
    my $dir = svcdir $_;
    my $sup = supervise $dir, $done;
    my $run = $sup->run;
    $dir;
} @names;

$done->begin for @svcs;
my %stopped;

my $g = Metavise::Group->new(
    directory => $svcs[0]->parent->resolve,
    on_change => sub { $stopped{$_[0]}++; $done->end },
);
do { $_->svc('x'); $_->svc('d') } for $g->processes;

$done->recv;
pass 'supervises exited ok';

is_deeply [sort map { m{([^/]+)$}; $1 } keys %stopped],
    [sort @names],
    'got each key';

done_testing;
