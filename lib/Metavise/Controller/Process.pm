package Metavise::Controller::Process;
# ABSTRACT: introspect and control processes
use Moose;
use true;
use namespace::autoclean;
use JSON::XS;
use DateTime::Format::Strptime;
use File::Slurp qw(read_file);
use File::Temp qw(tempfile);
use HTTP::Date qw(time2str str2time);
use Number::Bytes::Human qw(format_bytes);
use feature 'switch';

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config( default => 'application/json' );

sub processes : Path('/process') Args(0) ActionClass('REST') {}

sub processes_GET {
    my ($self, $c) = @_;
    $self->status_ok( $c, entity => [
        map { $self->get_process_hash($_) } sort {
            return $a->name cmp $b->name if
                not($a->name =~ /log/ xor $b->name =~ /log/);

            return  1 if $a->name =~ /log/ && $b->name !~ /log/;
            return -1 if $b->name =~ /log/ && $a->name !~ /log/;
        } $c->model('Processes')->processes,
    ]);
    $c->detach;
}

sub process : PathPart Chained CaptureArgs(1) {
    my ( $self, $c, $name ) = @_;
    my $p = $c->model('Processes', $name);
    if(!$p){
        $c->res->status(404);
        $c->res->body("No process '$name'");
        $c->detach;
    }

    $c->stash->{process} = $p;
}

sub get_process_hash {
    my ($self, $p) = @_;

    my $f = DateTime::Format::Strptime->new(
        pattern => '%a %b %e %T %Z %Y',
    );

    my $top = {};
    if($p->has_process){
        for my $m (qw/mem_size mem_resident mem_rss time_utime time_stime/){
            given($m){
                when(/^mem_/){
                    $top->{$m} = format_bytes($p->top->$m);
                }
                when(/^time_/){
                    my $secs = $p->top->$m / 100;
                    $top->{$m} = $secs;
                }
            }
        }
        $top->{time_total} = $top->{time_utime} + $top->{time_stime};
    }

    my $id = $p->name;
    $id =~ s{/}{%2F}g; # OH NOES SLASHES IN URLS OH NOES !!!!11!!

    return {
        id     => scalar $id,
        name   => scalar $p->name,
        up     => scalar ($p->has_process ? 1 : 0),
        pid    => scalar $p->get_pid,
        since  => scalar $f->format_datetime($p->status->{time}),
        paused => scalar ($p->status->{paused} ? 1 : 0),
        want   => scalar $p->status->{want},
        normal => scalar ($p->status->{normally_up} ? 'u' : 'd'),
        top    => scalar $top,
    };
}

sub act : Chained('process') PathPart('') Args(0) ActionClass('REST') {}

sub act_GET {
    my ($self, $c) = @_;
    my $p = $c->stash->{process};
    $self->status_ok( $c, entity => $self->get_process_hash($p) );
    $c->detach;
}

my %actions = (
    up       => 'u',
    down     => 'd',
    pause    => 'p',
    continue => 'c',
    term     => 't',
    int      => 'i',
    kill     => 'k',
    hangup   => 'h',
    alrm     => 'a',
);

my %allowed = ( reverse %actions );

sub act_PUT {
    my ($self, $c) = @_;
    my $p = $c->stash->{process};

    # this is cool; we apply a watcher to the process, and when its
    # status changes we complete the requset.  or we decide it's been
    # too long, and respond anyway.

    $c->response->body(sub {
        my $send_headers = shift;
        my $stream = $send_headers->([202, [
            'Content-Type' => 'application/json',
        ]]);

        $p->timed_watcher( 2 => sub {
            my $p = shift;
            $stream->write(
                encode_json($self->get_process_hash($p)),
            );
            $stream->close;
        });
    });

    my @want = split //, $c->req->data->{want};
    for my $want (@want){
        if(!$allowed{$want}){
            $self->status_bad_request(
                $c,
                message => "invalid svc action $want",
            );
            $c->detach;
        }
        $p->svc($want);
    }
    $c->detach;
}

sub graphs : Chained('process') Args(2) {
    my ($self, $c, $size, $graph) = @_;
    $graph =~ s/[.]([^.]+)$//; # todo allow this to define the format

    my $proc = $c->stash->{process};
    my $mtime = $proc->statlog->rrd->last;

    my $parameterized = scalar keys %{$c->req->params};

    # be a good cache citizen; set last-modified
    $c->res->header(
        last_modified => time2str($mtime),
    );

    # and 304 if we haven't modified anything
    my $if_modified = $c->req->headers->{'if-modified-since'};
    if(!$parameterized && defined $if_modified && str2time($if_modified) >= $mtime){
        $c->res->status(304);
        $c->res->body('not modified');
        $c->detach;
    }

    my $seconds =
        $c->req->params->{seconds} ? $c->req->params->{seconds} :
        $c->req->params->{minutes} ? $c->req->params->{minutes} * 60 :
        $c->req->params->{hours}   ? $c->req->params->{hours} * 60 * 60 :
            8 * 60 * 60;

    my $width  = 500;
    my $height = 100;

    if($size =~ /^(\d+)x(\d+)$/){
        $width  = $1;
        $height = $2;
    }

    my ($fh, $file) = tempfile;

    my @params = (
        end    => 'now',
        start  => "now - $seconds seconds",
        width  => $width,
        height => $height,
    );

    $proc->statlog->save_graph_to($graph, $file, @params);

    $c->res->content_type('image/png');
    $c->res->body(scalar read_file($file));
}

__PACKAGE__->meta->make_immutable;
