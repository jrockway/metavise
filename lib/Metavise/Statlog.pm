package Metavise::Statlog;
# ABSTRACT: record process statistics to an RRD
use Moose;
use true;
use namespace::autoclean;
use RRDTool::OO;
use MooseX::Types::Path::Class qw(File);
use Scalar::Util qw(weaken);

has 'database' => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has 'rrd' => (
    is         => 'ro',
    isa        => 'RRDTool::OO',
    lazy_build => 1,
    handles    => [qw/create update/],
);

sub _build_rrd {
    my $self = shift;
    return RRDTool::OO->new( file => $self->database->stringify );
}

has 'process' => (
    is       => 'rw',
    isa      => 'Metavise::Process',
    required => 1,
    handles  => [qw/has_process top/],
);

has 'time_watcher' => (
    reader  => 'time_watcher',
    builder => '_build_time_watcher',
);

sub _build_time_watcher {
    my $self = shift;
    weaken $self;
    return AnyEvent->timer( after => 0, interval => 30, cb => sub {
        $self->tick;
    });
}

has 'metrics' => (
    isa        => 'HashRef[CodeRef]',
    traits     => ['Hash'],
    lazy_build => 1,
    handles    => {
        'list_metrics' => 'keys',
        'get_metric'   => 'get',
    },
);

has 'graphs' => (
    isa        => 'HashRef[ArrayRef]',
    traits     => ['Hash'],
    lazy_build => 1,
    handles    => {
        'list_graphs'      => 'keys',
        'params_for_graph' => 'get',
    },
);

has 'last_tick' => (
    reader  => 'last_tick',
    isa     => 'HashRef',
    traits  => ['Hash'],
    clearer => 'clear_last_tick',
    handles => {
        update_tick => 'set',
    },
);

sub _build_metrics {
    my $self = shift;

    my %result;
    for my $metric (qw/rtime utime stime/) {
        $result{$metric} = sub {
            my ($self, $cb) = @_;
            $cb->($self->top->time->$metric),
        };
    }

    for my $metric (qw/rss resident size vsize share/) {
        $result{$metric} = sub {
            my ($self, $cb) = @_;
            $cb->($self->top->mem->$metric),
        };
    }

    return \%result;
}

sub _build_graphs {
    my $self = shift;
    return {
        memory => [
            draw => { dsname => 'rss', legend => 'rss', color => 'FF0000' },
            draw => { dsname => 'resident', legend => 'resident', color => '00FF00' },
            draw => { dsname => 'size', legend => 'size', color => '0000FF' },
            draw => { dsname => 'vsize', legend => 'vsize', color => 'FF00FF' },
           # draw => { dsname => 'share', legend => 'share', color => '00FFFF'  },
        ],
        cpu => [
            draw => { dsname => 'utime', legend => 'utime', color => 'FF0000' },
            draw => { dsname => 'stime', legend => 'stime', color => '00FF00' },
            draw => { dsname => 'rtime', legend => 'rtime', color => '0000FF' },
        ],
    };
}

sub BUILD {
    my $self = shift;
    if(!-e $self->database){
        my @data = map {
            ( data_source => {
                name => $_,
                type => 'GAUGE',
            }),
        } $self->list_metrics;

        $self->create(
            step => 30,
            @data,
            archive => {
                rows    => 60480, # a week
                cpoints => 1,
            },
        );
    }
}

sub save_graph_to {
    my ($self, $graph, $file, @extra) = @_;
    $self->rrd->graph(
        image => $file,
        @extra,
        @{ $self->params_for_graph($graph) || [] },
    );
}

sub tick {
    my $self = shift;
    return unless $self->has_process;

    # write the last tick to the database
    if(my $data = $self->last_tick) {
        my $time = delete $data->{_time};
        if($time){
            $self->update(
                time   => $time,
                values => $data,
            );
        }
        $self->clear_last_tick;
    }

    # begin updating a new tick
    #
    # we do this whole two-stage thing for two reasons. one, you can
    # only call update once per time value (so you can't just call
    # update whenever the $cb is called), and we don't want to lose
    # all the data if one of the callbacks times out (as would happen
    # if we waited for all events with Event::Join)
    my $time = int AnyEvent->now;

    $self->update_tick( _time => $time );

    for my $metric ($self->list_metrics){
        my $code = $self->get_metric($metric);
        my $cb = sub {
            my $result = shift;
            $self->update_tick( $metric => $result );
        };

        $self->$code($cb);
    }
}

__PACKAGE__->meta->make_immutable;
