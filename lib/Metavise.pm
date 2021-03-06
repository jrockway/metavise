package Metavise;
# ABSTRACT: web app for monitoring a group of processes started with svscan(8)
use Moose;
use true;
use namespace::autoclean;

use Catalyst qw/
    -Debug ConfigLoader
/;

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(
    name                                        => 'Metavise',
    disable_component_resolution_regex_fallback => 1,
);
