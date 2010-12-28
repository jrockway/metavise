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
        process_names => 'keys',
        processes     => 'values',
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


has 'log_directory' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
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

    while (my $path = $dir->next) {
        if(-d $path && -e $path->file('run')){
            my $svcdir = $path->resolve->stringify;
            next if Path::Class::file($svcdir)->basename =~ /^[.]/;

            my $p = Metavise::Process->new(
                root      => $path,
                on_change => sub { $self->handle_change($svcdir, @_) },
                log_to    => $self->log_directory,
            );
            $self->add_process( $p );

            my $logpath = $path->subdir('log');
            if( -d $logpath && -e $logpath->file('run') ){
                my $logsvcdir = $logpath->resolve->stringify;
                $self->add_process(
                    Metavise::Process->new(
                        root      => $logpath,
                        log_to    => $self->log_directory,
                        name      => $p->name . "/log",
                        on_change => sub { $self->handle_change($logsvcdir, @_) },
                    ),
                );
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;
