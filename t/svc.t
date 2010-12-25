use strict;
use warnings;
use Test::More;
use Test::Exception;
use t::lib::Supervise qw(svcdir supervise svc);

use ok 'Metavise::Command::svc';

{ # now create a supervise'd process and try to kill it
    my $done = AE::cv;
    my $dir = svcdir;

    my $cv = AE::cv;
    $cv->begin for 1..2;

    my $svc = svc $dir, $cv;

    # this is queued to run right after the process starts
    $svc->run('p');

    my $perl = (supervise $dir, $done)->run;

    $svc->run('x');
    $svc->run('d');

    lives_ok {
        $cv->recv;
    } 'ran svcs ok';

    ok $done->recv, 'condvar called because supervise exited';
    $perl->kill; # just in case;
}

done_testing;
