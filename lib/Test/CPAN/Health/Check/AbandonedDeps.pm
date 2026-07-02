package Test::CPAN::Health::Check::AbandonedDeps;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::AbandonedDeps - Check for dependencies with no recent releases

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::AbandonedDeps;

    my $check  = Test::CPAN::Health::Check::AbandonedDeps->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Queries the MetaCPAN API to find dependencies whose latest release is older
than a configurable threshold (default: 3 years) with no recent activity,
suggesting the dependency may be unmaintained.

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'abandoned_deps'                                          }
sub name        { 'Abandoned Dependencies'                                  }
sub description { 'Checks for dependencies that appear to be unmaintained'  }
sub weight      { 5                                                         }
sub category    { 'security'                                                }

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
