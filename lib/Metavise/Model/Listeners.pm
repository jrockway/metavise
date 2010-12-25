package Metavise::Model::Listeners;
# ABSTRACT: manage the details of sending streaming JSON
use Moose;
use true;
use namespace::autoclean;
use MooseX::Types::Set::Object;
use JSON::XS;

BEGIN { extends 'Catalyst::Model' }

has 'listeners' => (
    is      => 'ro',
    isa     => 'Set::Object',
    default => sub { Set::Object->new },
    handles => { insert_listener => 'insert' },
);

has 'mongrel2' => (
    is        => 'rw',
    isa       => 'AnyEvent::Mongrel2',
    predicate => 'has_mongrel2',
);

has 'uuid' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_uuid',
);

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    $self->mongrel2( $c->req->env->{'mongrel2'} ) unless $self->has_mongrel2;
    $self->uuid( $c->req->env->{'mongrel2.uuid'} ) unless $self->has_uuid;
    return $self;
}

sub post_event {
    my ($self, $type, @args) = @_;

    my ($dir, $stats) = @args;
    $stats->{time} = q{}.$stats->{time};
    my $res = {
        $type => {
            directory => $dir,
            %$stats,
        },
    };

    $self->send_to( $res, $self->listeners->members );
}

sub send_to {
    my ($self, $data, @to) = @_;
    confess 'no mongrel2' unless $self->has_mongrel2;
    $self->mongrel2->send_response(
        encode_json($data)."\r\n",
        $self->uuid,
        @to,
    );
}

__PACKAGE__->meta->make_immutable;
