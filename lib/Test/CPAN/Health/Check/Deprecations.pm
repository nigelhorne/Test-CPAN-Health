package Test::CPAN::Health::Check::Deprecations;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::Deprecations - Detect use of deprecated Perl features or modules

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::Deprecations;

    my $check  = Test::CPAN::Health::Check::Deprecations->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Scans source code for uses of deprecated Perl built-ins (e.g. C<POSIX::strftime>
format strings, C<given>/C<when>), deprecated CPAN modules, and modules listed
in L<Module::CoreList> as removed from core.

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'deprecations'                                              }
sub name        { 'Deprecations'                                              }
sub description { 'Detects use of deprecated Perl features or removed-from-core modules' }
sub weight      { 4                                                           }
sub category    { 'quality'                                                   }

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
