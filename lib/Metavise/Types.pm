package Metavise::Types;
# ABSTRACT:
use strict;
use warnings;

use MooseX::Types -declare => [qw/SvcCommand/];
use true;

enum SvcCommand, qw(u d o p c a i k t h x); # udop cai kthx
