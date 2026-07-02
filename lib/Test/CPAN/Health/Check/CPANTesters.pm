package Test::CPAN::Health::Check::CPANTesters;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::CPANTesters - Check CPAN Testers pass/fail ratio

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::CPANTesters;

    my $check  = Test::CPAN::Health::Check::CPANTesters->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Fetches the CPAN Testers summary for the most recent release from the
CPAN Testers API and computes a pass rate.  A high failure rate triggers
a hard cap on the overall report score (capped at 75).

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'cpan_testers'                                      }
sub name        { 'CPAN Testers'                                      }
sub description { 'Checks the CPAN Testers pass/fail ratio for the distribution' }
sub weight      { 8                                                   }
sub category    { 'ci'                                                }

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
