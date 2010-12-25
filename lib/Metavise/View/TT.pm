package Metavise::View::TT;
# ABSTRACT: TT view
use Moose;
use true;
use namespace::autoclean;

extends 'Catalyst::View::TT';

my @ext_methods = qw/css js png swf/;
__PACKAGE__->config(
    expose_methods     => [@ext_methods],
    TEMPLATE_EXTENSION => '.tt',
    CATALYST_VAR       => 'c',
    render_die         => 1,
    WRAPPER            => 'wrapper.tt',
    INCLUDE_PATH       => [
        Metavise->path_to( 'share', 'tt' ),
        Metavise->path_to( 'share', 'tt', 'lib' ),
    ],
);

sub html {
    my $_ = shift;
    s/&/&quot;/g;
    s/</&gt;/g;
    s/>/&lt;/g;
    s/"/&quot;/g;
    s/'/&apos;/g;
    return $_;
}

for my $ext (@ext_methods) {
    __PACKAGE__->meta->add_method( $ext => sub {
        my ($self, $c, $arg) = @_;
        return html($c->uri_for("/static/$ext/$arg.$ext"));
    });
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
