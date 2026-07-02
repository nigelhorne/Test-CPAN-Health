package Test::CPAN::Health::Check::PODCoverage;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::PODCoverage - Check that all public methods have POD

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::PODCoverage;

    my $check  = Test::CPAN::Health::Check::PODCoverage->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Uses L<Pod::Coverage> to measure what fraction of public methods in each
C<.pm> file have POD documentation.  Score is proportional to coverage.

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'pod_coverage'                                      }
sub name        { 'POD Coverage'                                      }
sub description { 'Checks that all public methods are documented in POD' }
sub weight      { 5                                                   }
sub category    { 'quality'                                           }

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
