# app.psgi
use strict;
use Metavise;

Metavise->setup_engine('PSGI');
my $app = sub { Metavise->run(@_) };
