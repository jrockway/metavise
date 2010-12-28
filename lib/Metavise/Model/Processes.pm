package Metavise::Model::Processes;
# ABSTRACT: glue the Processes to Catalyst
use strict;
use warnings;
use true;
use namespace::autoclean;
use Metavise::Group;
use Metavise::App::Statlog;
use RRDTool::OO;
use Carp qw(confess);

use parent 'Catalyst::Model';

sub COMPONENT {
    my ($class, $app, $args) = @_;
    return bless $args, $class;
}

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my $l = $c->model('Listeners');

    $self->{group} ||= Metavise::Group->new(
        directory     => $self->{directory},
        log_directory => $self->{rrd},
        on_change     => sub { }, #$l->post_event('process', @_) },
    );

    if(my $name = shift @args){
        return $self->{group}->get_process($name);
    }

    return $self->{group};
}
