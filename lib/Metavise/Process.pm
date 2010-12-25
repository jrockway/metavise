package Metavise::Process;
# ABSTRACT: control and monitor one supervise(8) process
use Moose;
use true;
use namespace::autoclean;

use Metavise::Command::svstat;
use Metavise::Command::svc;

use MooseX::Types::Path::Class qw(Dir);

use 5.010;

has 'root' => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

has 'name' => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_name {
    my ($self) = @_;
    return Path::Class::file($self->root)->basename;
}

has 'watcher' => (
    reader     => 'watcher',
    isa        => 'Metavise::Command::svstat',
    handles    => [qw/status/],
    lazy_build => 1,
);

has 'svc' => (
    handles    => { svc => 'run' },
    isa        => 'Metavise::Command::svc',
    lazy_build => 1,
);

has 'on_change' => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
);

sub BUILD { $_[0]->watcher }

sub _build_watcher {
    my $self = shift;
    return Metavise::Command::svstat->new(
        target    => $self->root,
        on_change => sub { $self->handle_change('change', @_) },
    );
}

sub _build_svc {
    my $self = shift;
    return Metavise::Command::svc->new(
        target        => $self->root,
        on_completion => sub { $self->handle_change('svc-done', @_) },
    );
}

sub handle_change {
    my $self = shift;
    my $type = shift;

    given($type){
        when(/change/){
            my ($new, $old) = @_;
            $self->on_change->($new, $old);
        }
        when(/^svc-/){
            # TODO: relate svc calls and status changes?
        }
    }
}

__PACKAGE__->meta->make_immutable;
