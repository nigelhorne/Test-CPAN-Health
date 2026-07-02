package Test::CPAN::Health::Check::CIConfig;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Check::CIConfig - Check that a CI configuration is present and valid

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::CIConfig;

    my $check  = Test::CPAN::Health::Check::CIConfig->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Checks for the presence of a recognised CI configuration file such as
C<.github/workflows/*.yml>, C<.travis.yml>, C<.circleci/config.yml>, or
C<Jenkinsfile>, and validates basic YAML well-formedness where applicable.

I<Not yet implemented.  Returns a skip result.>

=cut

sub id          { 'ci_config'                                              }
sub name        { 'CI Configuration'                                       }
sub description { 'Checks that a valid CI configuration file is present'   }
sub weight      { 4                                                        }
sub category    { 'ci'                                                     }

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
