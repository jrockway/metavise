use strict;
use Plack::Builder;
use Plack::App::Directory;

use lib 'lib';
use Metavise;

Metavise->setup_engine('PSGI');

my $static = Plack::App::Directory->new( root => 'share/static' )->to_app;
my $app = sub { Metavise->run(@_) };
builder {
    mount '/static' => $static;
    mount '/'       => $app;
};

