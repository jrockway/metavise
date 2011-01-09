package Metavise::Role::AdHocWatcher;
# ABSTRACT: add one-shot watchers
use Moose::Role;
use true;
use namespace::autoclean;

use AnyEvent;
use Scalar::Util qw(weaken);

has 'watchers' => (
    isa     => 'Set::Object',
    default => sub { Set::Object->new },
    handles => {
        add_watcher    => 'insert',
        delete_watcher => 'delete',
        watchers       => 'members',
    },
);

sub run_watchers {
    my ($self, @args) = @_;
    for my $w ($self->watchers){
        $self->delete_watcher($w);
        $w->(@args);
    }
}

sub timed_watcher {
    my ($self, $time, $cb) = @_;
    weaken $self;
    my $t; $t = AnyEvent->timer(
        after => $time,
        cb    => sub {
            undef $t;
            $cb->($self);
        },
    );
    $self->add_watcher(sub {
        undef $t;
        $cb->($self);
    });
}
