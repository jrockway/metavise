package Metavise::Group;
# ABSTRACT: a group of processes
use Moose;
use true;
use namespace::autoclean;

use Metavise::Process;
use MooseX::Types::Path::Class qw(Dir);
use Scalar::Util qw(weaken);

has 'process_set' => (
    init_arg => 'processes',
    isa      => 'HashRef[Metavise::Process]',
    default  => sub { +{} },
    traits   => ['Hash'],
    handles  => {
        processes     => 'keys',
        process_count => 'count',
        get_process   => 'get',
        _add_process  => 'set',
    },
);

has 'directory' => (
    is        => 'ro',
    isa       => Dir,
    predicate => 'has_directory',
    coerce    => 1,
);

has 'on_change' => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
);

sub add_process {
    my ($self, $process, $name) = @_;
    $name ||= $process->name;
    $self->_add_process($name, $process);
}

sub BUILD {
    my $self = shift;
    if($self->has_directory){
        $self->add_directory($self->directory);
    }
}

sub handle_change {
    my ($self, $dir, @rest) = @_;
    $self->on_change->($dir, @rest);
}

sub add_directory {
    my ($self, $dir) = @_;
    weaken $self;

    while (my $p = $dir->next) {
        if(-d $p && -e $p->file('run')){
            my $d = $p->resolve->stringify;
            $self->add_process(
                Metavise::Process->new(
                    root => $p,
                    on_change => sub { $self->handle_change($d, @_) },
                ),
            );
        }
        # if(-d $p && -e -d $p->subdir('log')){
        #     $self->_add_directory($p);
        # }
    }
}

__PACKAGE__->meta->make_immutable;
