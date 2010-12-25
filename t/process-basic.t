use strict;
use warnings;
use Test::More tests => 12;
use t::lib::Supervise qw(svcdir supervise);
use EV;

use ok 'Metavise::Process';

my $done = AE::cv;
my $dir = svcdir;
my $supervise = supervise $dir, $done;

my @changes;
my @script = (['p'], ['c'], ['d'], ['u'], ['x', 'd']);

my $step = AE::cv;
$step->begin for @script;

my $process;
my $last = 'u';
my $next; $next = sub {
    my @cmd = @{shift @script || []};
    # diag (join ' ', @cmd);
    $process->svc($_) for @cmd;
    $last = $cmd[-1];
    $step->end;
};

$process = Metavise::Process->new(
    root      => $dir,
    on_change => sub {
        ok $_[0], "got change $last";
        push @changes, $_[0];
        $next->();
    },
);

my $run = $supervise->run;

$step->recv;
ok $done->recv, 'supervise exited ok';
$run->kill;

is @changes, 6, 'got 6 after-change events';

is_deeply [map { $_->{want} } @changes],
    [qw/u u u d u d/],
    'got correct sequence of normally_up';

my $initial_pid = $changes[0]->{pid};
is_deeply [map { $_->{pid} } @changes],
    [$initial_pid, $initial_pid, $initial_pid, 0, $changes[4]->{pid}, 0],
    'got sequence of pids';

is_deeply [ map { $_->{pid_ok} } @changes ],
    [ 1, 1, 1, 0, 1, 0 ],
    'got ok pids when we had pids';
