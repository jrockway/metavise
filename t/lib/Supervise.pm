package t::lib::Supervise;
use strict;
use warnings;
use true;

use AnyEvent;
use AnyEvent::Subprocess;
use Directory::Scratch;
use Metavise::Command::svc;
use File::Which qw(which);

use Sub::Exporter -setup => {
    exports => [qw/tmp svcdir supervise svc/],
};

my $tmp = Directory::Scratch->new;

sub tmp() { $tmp };

sub svcdir(;$) {
    my $name = shift || 'sample_process';
    $tmp->mkdir($name);
    $tmp->touch( "$name/run" =>
        '#!/bin/sh',
        'perl -e "sleep 60"',
    );

    my $dir = $tmp->exists($name);
    my $file = $tmp->exists("$name/run");
    chmod 0755, $file or die "failed to chmod: $!";

    return ($dir, $file) if wantarray;
    return $dir;
}

sub cb($){
    my $cv = shift;
    return sub { $cv->end } if $cv->{_ae_counter};
    return sub { $cv->send(1) };
}

sub supervise($$) {
    my ($dir, $done) = @_;
    return AnyEvent::Subprocess->new(
        code          => [ which('supervise'), $dir->stringify ],
        on_completion => cb $done,
    );
}

sub svc($;$) {
    my ($dir, $done) = @_;

    return Metavise::Command::svc->new(
        target     => $dir,
        $done ? (on_completion => cb($done)) : (),
    );
}
