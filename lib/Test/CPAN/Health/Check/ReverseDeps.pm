package Test::CPAN::Health::Check::ReverseDeps;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::ReverseDeps - Report the number of reverse dependencies

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::ReverseDeps;

    my $check  = Test::CPAN::Health::Check::ReverseDeps->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Queries the MetaCPAN API to count how many other CPAN distributions declare
a dependency on this one.  Higher reverse-dependency counts are a quality
signal (widely depended-upon code is more likely to be well-maintained).

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'reverse_deps'                                        }
sub name        { 'Reverse Dependencies'                                }
sub description { 'Reports the number of CPAN distributions that depend on this one' }
sub weight      { 2                                                     }
sub category    { 'quality'                                             }

sub run {
	my ($self, $dist, $context) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless ref($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	return $self->_skip('Not yet implemented');
}

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Nigel Horne.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

=cut

1;
