use strict;
use warnings;
use Test::More;
use Test::Exception;
use t::lib::Supervise qw(svcdir supervise);
use EV;

use ok 'Metavise::Process';

my $done = AE::cv;
my $dir = svcdir;

my $supervise = supervise $dir, $done;
$supervise->run;

my $pid_ready = AE::cv;
my $pid_done  = AE::cv;

my $process = Metavise::Process->new(
    root      => $dir,
    on_change => sub {
        my ($new, $old) = @_;
        if($new->{pid_ok}){
            $pid_ready->send;
        }
        else {
            $pid_done->send;
        }
    },
);

$process->svc('u');

$pid_ready->recv;
ok $process->has_process, 'has process';
like $process->get_pid, qr/^\d+$/, 'got pid';

my $mem = $process->top->mem_vsize;
like $mem, qr/^\d+$/, "got mem_vsize ($mem) ok";

$process->svc('x');
$process->svc('d'); # BAI

$pid_done->recv;

ok !$process->has_process, 'BAI?';
throws_ok { $process->top } qr/no process running/,
    'top cannot be created anymore';

$done->recv;

done_testing;
