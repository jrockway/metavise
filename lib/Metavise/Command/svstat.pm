package Metavise::Command::svstat;
# ABSTRACT: monitor the status information updated by supervise(8)
use Moose;
use MooseX::Types::Path::Class qw(Dir);
use true;
use namespace::autoclean;
use AnyEvent::Subprocess;
use Time::TAI64 qw(tai64nunix);
use DateTime;
use EV 4;
use Scalar::Util qw(weaken);
use File::Which qw(which);

has 'target' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

sub status_file {
    my $self = shift;
    return $self->target->subdir('supervise')->file('status');
}

has 'on_change' => (
    is       => 'ro',
    isa      => 'CodeRef',
    required => 1,
);

has 'status' => (
    is      => 'rw',
    isa     => 'HashRef',
    builder => 'parse_status',
    lazy    => 1,
);

# in real life, 0 ("default") is perfect.  but for the tests, it's
# better to set it to something small.
has '_poll_interval' => (
    is      => 'ro',
    isa     => 'Num',
    default => sub { 0 },
);

has '_stat_watcher' => (
    reader     => 'watch',
    lazy_build => 1,
);

has '_time_watcher' => (
    reader     => 'start_timer',
    clearer    => 'clear_timer',
    lazy_build => 1,
);

sub BUILD { $_[0]->status; $_[0]->start_timer; $_[0]->watch; }

sub is_running {
    my ($self, $pid) = @_;
    return kill $pid, 0;
}

sub parse_status {
    my $self = shift;
    my $file = $self->status_file;
    return +{} unless -e $file; # perfectly legit; process is not
                                # running yet, etc.
    my $data = $file->slurp;
    my ($tai, $pid, $paused, $want) = unpack 'H24 L C C', $data;
    my $normallyup = !-e $self->target->file('down');

    # TODO: patch DateTime::Format::Epoch to understand tai64n
    # TODO: patch Time::TAI64 to understand binary tai64* times (not
    #       the hex crap we're using here)
    my $time = DateTime->from_epoch(
        epoch => tai64nunix( '@'.$tai ),
    );

    my $pid_ok = 0;
    $pid_ok = kill 0, $pid if $pid > 0;

    return +{
        time        => $time,
        pid         => $pid,
        pid_ok      => $pid_ok,
        paused      => $paused,
        want        => chr $want,
        normally_up => $normallyup ? 1 : 0,
        raw         => $data,
    };
}

sub _status_changed {
    my ($self, $a, $b) = @_;

    # if there is no status in both cases, it's unchanged
    return 0 if !exists $a->{raw} && !exists $b->{raw};

    no warnings 'uninitialized';
    return $a->{raw} ne $b->{raw};
}

sub _handle_stat_change {
    my $self = shift;
    my $old_status = $self->status;
    my $new_status = $self->parse_status;

    $self->status( $new_status );

    $self->on_change->($new_status, $old_status)
        if $self->_status_changed( $new_status, $old_status );
}

sub _build__stat_watcher {
    my $self = shift;
    weaken $self;
    return EV::stat $self->status_file->stringify, 1, sub {
        $self->clear_timer;
        $self->_handle_stat_change;
        $self->start_timer; # we start a timer in case two things
                            # happen in one second; the stat watcher
                            # is not smart enough to see this, or
                            # something.
    };
}

sub _build__time_watcher {
    my $self = shift;

    # periodic so that the timer goes off right when the clock ticks
    # to the next second.
    return EV::periodic int(AnyEvent->now) + 1, 0, 0, sub {
        $self->clear_timer;
        $self->_handle_stat_change;
    };
}

__PACKAGE__->meta->make_immutable;
