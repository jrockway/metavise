package Metavise::App::Statlog;
# ABSTRACT: MooseX::Runnable app to rrdlog a bunch of processes
use Moose;
use true;
use namespace::autoclean;
use MooseX::Types::Path::Class qw(Dir);
use MooseX::Types::Set::Object;
use EV;
use Metavise::Group;
use Metavise::Statlog;

with 'MooseX::Runnable', 'MooseX::Getopt::Dashes';

has 'services' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

has 'group' => (
    reader     => 'group',
    isa        => 'Metavise::Group',
    lazy_build => 1,
    handles    => [qw/processes/],
);

has 'databases' => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => sub { '.' },
);

sub _build_group {
    my $self = shift;
    return Metavise::Group->new(
        directory     => $self->services,
        log_directory => $self->databases,
        on_change => sub { },
    );
}

sub run {
    my $self = shift;
    $_->statlog for $self->processes;
    EV::run();
}

__PACKAGE__->meta->make_immutable;
