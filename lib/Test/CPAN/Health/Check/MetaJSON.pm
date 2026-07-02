package Test::CPAN::Health::Check::MetaJSON;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

Readonly::Scalar my $SCORE_JSON_COMPLETE   => 100;
Readonly::Scalar my $SCORE_YML_COMPLETE    =>  70;
Readonly::Scalar my $SCORE_JSON_INCOMPLETE =>  50;
Readonly::Scalar my $SCORE_YML_INCOMPLETE  =>  30;

=head1 NAME

Test::CPAN::Health::Check::MetaJSON - Check that META.json is present, valid, and complete

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::MetaJSON;

    my $check  = Test::CPAN::Health::Check::MetaJSON->new;
    my $result = $check->run($dist);

    printf "%s: %s\n", $result->status, $result->summary;

=head1 DESCRIPTION

Verifies that the distribution ships a well-formed META.json (preferred) or
META.yml (fallback) and that the required CPAN::Meta v2 fields -- name,
version, abstract, author, license -- are present and non-empty.

Score matrix:

=over 4

=item * 100 -- META.json present; all required fields populated.

=item *  70 -- Only META.yml present; all required fields populated.

=item *  50 -- META.json present; one or more required fields missing/vague.

=item *  30 -- Only META.yml present; one or more required fields missing/vague.

=item *   0 -- No META file found.

=back

=head1 LIMITATIONS

=over 4

=item * The check reads whichever META file C<Distribution-E<gt>meta> resolves
(META.json preferred).  It does not independently re-parse the file.

=item * C<abstract> is considered missing when it is the literal string
C<'unknown'>, which Dist::Zilla and MakeMaker sometimes use as a placeholder.

=back

=cut

sub id          { 'meta_json'                                              }
sub name        { 'META.json'                                              }
sub description { 'Checks that META.json is present, valid, and complete'  }
sub weight      { 5                                                        }
sub category    { 'packaging'                                              }

=head2 run

=head3 PURPOSE

Determine whether a META.json (or META.yml) exists and contains the minimum
required metadata fields.

=head3 API SPECIFICATION

=head4 INPUT

  dist     Test::CPAN::Health::Distribution  required
  context  Hashref                           optional  prior check results

=head4 OUTPUT

L<Test::CPAN::Health::Result> with check_id C<'meta_json'>.

=head3 MESSAGES

  Code  | Severity | Message                                   | Resolution
  ------+----------+-------------------------------------------+-----------
  MJ001 | FAIL     | No META.json or META.yml found            | Generate META files
  MJ002 | WARN     | META missing required fields: {list}      | Add missing fields
  MJ003 | WARN     | META.yml present but META.json is missing | Generate META.json
  MJ004 | PASS     | META.json is present and complete         |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  MetaJSONOp
  dist     : Distribution
  has_json : Boolean
  meta     : CPAN::Meta | undefined
  missing  : seq String
  -------------------------------------------------------
  meta = undefined => status = fail /\ score = 0
  #missing > 0 /\ has_json  => status = warn /\ score = 50
  #missing > 0 /\ ~has_json => status = warn /\ score = 30
  #missing = 0 /\ ~has_json => status = warn /\ score = 70
  #missing = 0 /\ has_json  => status = pass /\ score = 100

=head3 SIDE EFFECTS

None.  Uses the already-parsed META object from C<$dist->meta>.

=head3 USAGE EXAMPLE

    my $result = Test::CPAN::Health::Check::MetaJSON->new->run($dist);
    print $result->summary;

=cut

sub run {
	my ($self, $dist, $context) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless ref($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	my $has_json = defined $dist->file_path('META.json');
	my $meta     = $dist->meta;

	unless ($meta) {
		return $self->_result(
			status  => 'fail',
			score   => 0,
			summary => 'No META.json or META.yml found',
			details => ['Run "perl Makefile.PL && make manifest" or use Dist::Zilla to generate META files'],
			data    => { name => $self->name },
		);
	}

	my @authors  = $meta->author;
	my @licenses = $meta->license;

	my @missing;
	push @missing, 'name'
		unless defined $meta->name && length $meta->name;
	push @missing, 'version'
		unless defined $meta->version && length $meta->version;
	push @missing, 'abstract'
		unless defined $meta->abstract && length $meta->abstract
			&& $meta->abstract ne 'unknown';
	push @missing, 'author'  unless @authors;
	push @missing, 'license' unless @licenses;

	if (@missing) {
		my $score = $has_json ? $SCORE_JSON_INCOMPLETE : $SCORE_YML_INCOMPLETE;
		return $self->_result(
			status  => 'warn',
			score   => $score,
			summary => sprintf('META file is missing required fields: %s', join(', ', @missing)),
			details => [ map { "Add '$_' to META.json" } @missing ],
			data    => {
				name     => $self->name,
				has_json => $has_json ? 1 : 0,
				missing  => \@missing,
			},
		);
	}

	unless ($has_json) {
		return $self->_result(
			status  => 'warn',
			score   => $SCORE_YML_COMPLETE,
			summary => 'META.yml found but META.json is missing (JSON preferred for tooling compatibility)',
			details => ['Generate META.json alongside META.yml'],
			data    => { name => $self->name, has_json => 0 },
		);
	}

	return $self->_result(
		status  => 'pass',
		score   => $SCORE_JSON_COMPLETE,
		summary => 'META.json is present and contains all required fields',
		data    => { name => $self->name, has_json => 1 },
	);
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
