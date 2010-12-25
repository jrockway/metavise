package Metavise::Command::svc;
# ABSTRACT: emulate svc(8) in perl space
use Moose;
use Metavise::Types qw(SvcCommand);
use MooseX::Types::Path::Class qw(Dir);
use AnyEvent::Util qw(fh_nonblocking);
use true;
use namespace::autoclean;

has 'target' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

has 'on_completion' => (
    is      => 'ro',
    isa     => 'CodeRef',
    default => sub { sub {} },
);

sub run {
    my ($self, $command) = @_;

    confess 'need command' unless length $command > 0;
    confess "'$command' is too long" unless length $command == 1;

    my $pipe = $self->target->subdir('supervise')->file('control');

    my ($fd, $sw);
    my ($start, $read);

    $start = sub {
        undef $sw; # keep the stat watcher in scope
        confess "$pipe is not a writable FIFO" unless -p -w $pipe;

        $fd = $pipe->openw;
        fh_nonblocking $fd, 1;

        $read->();
    };

    $read = sub {
        my $bytes = syswrite( $fd, $command, 1 );

        if( $bytes < 1 ) {
            my $w; $w = AnyEvent->io( fd => $fd, poll => 'w', cb => sub {
                undef $w;
                goto $read;
            });
        }

        $self->on_completion->();
    };

    if( -e $pipe ){
        $start->();
    }
    else {
        $sw = EV::stat($pipe->stringify, 1, sub {
            $start->();
        });
    }
}

__PACKAGE__->meta->make_immutable;
