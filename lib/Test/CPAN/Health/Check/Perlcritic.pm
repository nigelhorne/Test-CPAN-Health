package Test::CPAN::Health::Check::Perlcritic;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::Perlcritic - Run Perl::Critic and report policy violations

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::Perlcritic;

    my $check  = Test::CPAN::Health::Check::Perlcritic->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Runs L<Perl::Critic> at the distribution's declared or default severity level
and scores proportionally to the fraction of files that pass without
violations.

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'perlcritic'                                     }
sub name        { 'Perl::Critic'                                   }
sub description { 'Runs Perl::Critic and reports policy violations' }
sub weight      { 6                                                }
sub category    { 'quality'                                        }

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
