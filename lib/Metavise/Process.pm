package Metavise::Process;
# ABSTRACT: control and monitor one supervise(8) process
use Moose;
use true;
use namespace::autoclean;

use Scalar::Util qw(weaken);

use Metavise::Command::svstat;
use Metavise::Command::svc;
use Metavise::Command::top;
use Metavise::Statlog;

use MooseX::Types::Set::Object;
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

has 'on_change' => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
);

has 'log_to' => (
    is        => 'ro',
    isa       => Dir,
    coerce    => 1,
    predicate => 'has_log_to',
);

has 'svstat' => (
    reader     => 'svstat',
    isa        => 'Metavise::Command::svstat',
    handles    => [qw/status/],
    lazy_build => 1,
);

sub has_process {
    my $self = shift;
    return eval { $self->status->{pid_ok} };
}

sub get_pid {
    my $self = shift;
    return unless $self->has_process;
    return $self->status->{pid};
}

has 'svc' => (
    handles    => { svc => 'run' },
    isa        => 'Metavise::Command::svc',
    lazy_build => 1,
);

has 'top' => (
    reader     => 'top',
    isa        => 'Metavise::Command::top',
    handles    => { set_pid => 'pid' },
    lazy_build => 1,
);

has 'statlog' => (
    reader     => 'statlog',
    isa        => 'Metavise::Statlog',
    lazy_build => 1,
);

has 'watchers' => (
    isa     => 'Set::Object',
    default => sub { Set::Object->new },
    handles => {
        add_watcher    => 'insert',
        delete_watcher => 'delete',
        watchers       => 'members',
    },
);

sub BUILD { $_[0]->svstat; $_[0]->statlog }

sub _build_svstat {
    my $self = shift;
    return Metavise::Command::svstat->new(
        target    => $self->root,
        on_change => sub { $self->handle_change('change', @_) },
    );
}

sub _build_svc {
    my $self = shift;
    return Metavise::Command::svc->new(
        target => $self->root,
    );
}

sub _build_top {
    my $self = shift;
    confess 'no process running, therefore cannot build top object'
        unless $self->status->{pid_ok};

    return Metavise::Command::top->new(
        pid => $self->status->{pid},
    );
}

sub _build_statlog {
    my $self = shift;
    my $dir = $self->log_to;
    confess 'no place to log to' unless $self->has_log_to;

    my $name = $self->name;
    $name =~ s{/}{_}g;

    weaken $self;
    my $statlog = Metavise::Statlog->new(
        database => $dir->file("$name.rrd"),
        process  => $self,
    );

    return $statlog;
}

sub handle_change {
    my $self = shift;
    my $type = shift;
    my ($new, $old) = @_;

    eval {
        no warnings;
        $self->clear_top if !$new->{pid_ok};
        $self->set_pid($new->{pid})
            if $new->{pid} && $new->{pid} != $old->{pid};
    };

    $self->on_change->($new, $old);

    my $pid_changed = $new->{pid_ok} ?
        ( $old->{pid_ok} ? $new->{pid} != $old->{pid} : 1 ) :
        ( $old->{pid_ok} ? 1 : 0 );

    if($pid_changed || $new->{paused} ne $old->{paused}){
        for my $w ($self->watchers){
            $self->delete_watcher($w);
            $w->();
        }
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

__PACKAGE__->meta->make_immutable;
