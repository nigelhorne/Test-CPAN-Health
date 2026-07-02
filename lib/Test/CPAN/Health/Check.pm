package Test::CPAN::Health::Check;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(:all);

our $VERSION = '0.01';

# Valid categories for grouping checks in the report.
Readonly::Array my @VALID_CATEGORIES => qw(packaging quality security ci);
Readonly::Hash  my %CATEGORY_SET     => map { $_ => 1 } @VALID_CATEGORIES;

=head1 NAME

Test::CPAN::Health::Check - Abstract base class for all health checks

=head1 SYNOPSIS

    package Test::CPAN::Health::Check::MyCheck;

    use parent 'Test::CPAN::Health::Check';

    sub id          { 'my_check'                }
    sub name        { 'My Check'                }
    sub description { 'Checks something useful' }
    sub weight      { 4                         }
    sub category    { 'quality'                 }

    sub run {
        my ($self, $dist) = @_;

        # ... perform analysis on $dist ...

        return $self->_result(
            status  => 'pass',
            score   => 100,
            summary => 'Everything looks good',
        );
    }

    1;

=head1 DESCRIPTION

Every health check in C<Test::CPAN::Health> is a subclass of this base class.
Subclasses B<must> override C<id>, C<name>, and C<run>.  Overriding
C<description>, C<weight>, and C<category> is recommended.

The base class provides C<_result> as a convenience constructor for
L<Test::CPAN::Health::Result> objects, and enforces the abstract interface.

=head1 LIMITATIONS

=over 4

=item * This is not a Moo/Moose role -- inheritance is via C<use parent>.

=item * The C<run> method receives a fully-constructed
L<Test::CPAN::Health::Distribution> object; checks that need network access
should honour C<no_network>.

=back

=cut

sub new {
	my ($class, %args) = @_;

	validate_with(params => \%args, spec => {
		severity   => { type => SCALAR, default => 3 },
		no_network => { type => SCALAR, default => 0 },
		no_cover   => { type => SCALAR, default => 0 },
	});

	my $self = bless {
		_severity   => $args{severity},
		_no_network => $args{no_network},
		_no_cover   => $args{no_cover},
	}, $class;

	return $self;
}

=head2 id

=head3 PURPOSE

Returns a stable, lowercase_underscore string that uniquely identifies
this check.  Used as the hash key in Report results and in --skip/--check
CLI flags.

=head3 API SPECIFICATION

=head4 INPUT

None.

=head4 OUTPUT

Non-empty scalar string; lowercase alphanumeric and underscores only.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
  CHK01 | FATAL    | id() not implemented in subclass   | Override id() in subclass

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  id : String
  -------------------------------------------------------
  id /= ""
  id matches /^[a-z][a-z0-9_]*$/

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    print $check->id;    # 'sem_ver'

=cut

sub id { croak ref($_[0]) . ' must implement id()' }

=head2 name

=head3 PURPOSE

Returns a short human-readable display name for use in report headers.

=head3 API SPECIFICATION

=head4 INPUT

None.

=head4 OUTPUT

Non-empty scalar string.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
  CHK02 | FATAL    | name() not implemented in subclass | Override name() in subclass

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  name : String
  -------------------------------------------------------
  name /= ""

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    print $check->name;    # 'Semantic Versioning'

=cut

sub name { croak ref($_[0]) . ' must implement name()' }

=head2 description

=head3 PURPOSE

Returns a one-sentence description of what the check measures.

=head3 API SPECIFICATION

=head4 INPUT

None.

=head4 OUTPUT

Scalar string.  Empty string is acceptable but discouraged.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
        |          |                                    |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  description : String

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    print $check->description;

=cut

sub description { return '' }

=head2 weight

=head3 PURPOSE

Returns the numeric weight applied to this check's score in the weighted
average that produces the overall Report score.  Higher weights make a
check more influential.  Defaults to 1.

=head3 API SPECIFICATION

=head4 INPUT

None.

=head4 OUTPUT

Positive integer or float.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
        |          |                                    |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  weight : N1    -- positive natural number
  -------------------------------------------------------
  weight > 0

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    print $check->weight;    # 8

=cut

sub weight { return 1 }

=head2 category

=head3 PURPOSE

Returns the category string used to group checks in the report.
Must be one of: C<packaging>, C<quality>, C<security>, C<ci>.

=head3 API SPECIFICATION

=head4 INPUT

None.

=head4 OUTPUT

One of: packaging, quality, security, ci.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
        |          |                                    |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  category : {packaging, quality, security, ci}

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    print $check->category;    # 'quality'

=cut

sub category { return 'quality' }

=head2 run

=head3 PURPOSE

Executes the check against a distribution and returns a Result.  May return
C<undef> when the check is not applicable (e.g. CPANTesters for a dist
that has never been released).

=head3 API SPECIFICATION

=head4 INPUT

  dist  Test::CPAN::Health::Distribution  required

=head4 OUTPUT

L<Test::CPAN::Health::Result> object, or C<undef> if not applicable.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
  CHK03 | FATAL    | run() not implemented in subclass  | Override run() in subclass

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  RunOp
  dist   : Distribution
  result : Result | undefined
  -------------------------------------------------------
  result /= undefined => result.check_id = self.id

=head3 SIDE EFFECTS

May perform network I/O, filesystem reads, and subprocess invocations.

=head3 USAGE EXAMPLE

    my $result = $check->run($dist);
    print $result->summary if defined $result;

=cut

sub run { croak ref($_[0]) . ' must implement run()' }

# ---------------------------------------------------------------------------
# Protected helpers for subclasses
# ---------------------------------------------------------------------------

# Convenience wrapper so subclasses do not need to 'use' Result themselves.
sub _result {
	my ($self, %args) = @_;

	require Test::CPAN::Health::Result;

	return Test::CPAN::Health::Result->new(
		check_id => $self->id,
		%args,
	);
}

# Convenience: return a skip result with an explanatory message.
sub _skip {
	my ($self, $reason) = @_;

	return $self->_result(
		status  => 'skip',
		summary => $reason // 'Not applicable',
	);
}

# Convenience: return an error result (check itself encountered a problem).
sub _error {
	my ($self, $message) = @_;

	return $self->_result(
		status  => 'error',
		summary => $message // 'Unknown error',
	);
}

sub severity   { return $_[0]->{_severity}   }
sub no_network { return $_[0]->{_no_network} }
sub no_cover   { return $_[0]->{_no_cover}   }

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
