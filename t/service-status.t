use strict;
use warnings;
use Test::More;
use t::lib::Supervise qw(svcdir supervise svc);

use ok 'Metavise::Command::svstat';

my $done = AE::cv;
my $dir = svcdir;

# make the watcher
my $change = AE::cv;
my @status = ();
my $status = Metavise::Command::svstat->new(
    target         => $dir,
    on_change      => sub { push @status, $_[0]; $change->send($_[0]) },
    _poll_interval => 0.01, # after supervise starts, then we switch to inotify anyway
);

ok !-e $status->status_file, 'no status file yet';

# then start the supervise process
my $supervise = supervise $dir, $done;

my $s_run = $supervise->run;

my $stat = $change->recv;
ok -e $status->status_file, 'have status file now';
$change = AE::cv; # get ready for the next change

ok $stat->{normally_up}, 'normally up';
ok $stat->{pid}, 'is up';
is $stat->{want}, 'u', 'want up';

ok my $start_time = $stat->{time}, 'has start time';
cmp_ok $start_time, '<=', DateTime->now, 'in the past';

(svc $dir)->run('p');

$stat = $change->recv;
$change = AE::cv;

ok my $end_time = $stat->{time}, 'has start time';
cmp_ok $start_time, '<=', $end_time, 'started before it ended';


(svc $dir)->run('d');
$stat = $change->recv;
ok !$stat->{pid}, 'down';

$s_run->kill;
$done->recv;

done_testing;
