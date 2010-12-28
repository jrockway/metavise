package Metavise::Command::top;
# ABSTRACT: monitor the vital signs of a running process
use Moose;
use MooseX::ClassAttribute;
use true;
use namespace::autoclean -also => ['_delegate'];
use GTop;

has 'pid' => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
    trigger  => sub {
        my ($self, $new, $old) = @_;
        no warnings 'uninitialized';
        $self->_change_pid($new) if $old && $new != $old;
    },
);

my @things = qw/args map mem segment state time uid/;

class_has 'gtop' => (
    is         => 'ro',
    isa        => 'GTop',
    lazy_build => 1,
    handles    => { map { ("_proc_$_" => "proc_$_") } @things },
);

sub _build_gtop {
    my $class = shift;
    return GTop->new;
}

sub _delegate {
    my ($attr, $them) = @_;
    my $prefix = $attr->name;
    return map { ("${prefix}_$_" => $_) }
        grep { !/DESTROY/ } $them->get_method_list;
}

for my $thing (@things) {
    # this used to create an attribute
    __PACKAGE__->meta->add_method( "$thing" => sub {
        my $self = shift;
        my $method = "_proc_$thing";
        return $self->$method($self->pid);
    });

    # and this used to be delegation
    my $meta = Class::MOP::Class->initialize("GTop::Proc\u$thing");
    for my $method (grep { !/DESTROY/ } $meta->get_method_list){
        __PACKAGE__->meta->add_method( "${thing}_$method" => sub {
            my $self = shift;
            return $self->$thing->$method(@_);
        });
    }

    # but it seems GTop captures all the data at GTop->$thing($pid)
    # time, caching it forever.  so you need to create a new instance
    # every time, which is what this code does.
}

__PACKAGE__->meta->make_immutable;
