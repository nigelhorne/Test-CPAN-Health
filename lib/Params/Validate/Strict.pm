package Params::Validate::Strict;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak);
use Exporter qw(import);
use Params::Validate 1.29 ();
use Readonly;

our $VERSION = '0.01';

=head1 NAME

Params::Validate::Strict - Params::Validate with unknown-parameter rejection on by default

=head1 SYNOPSIS

    use Params::Validate::Strict qw(:all);

    sub new {
        my ($class, %args) = @_;

        validate_with(params => \%args, spec => {
            name => { type => SCALAR            },
            age  => { type => SCALAR, default => 0 },
        });
        # Croaks if caller passes any key not listed in the spec.

        return bless \%args, $class;
    }

=head1 DESCRIPTION

A thin wrapper around L<Params::Validate> that changes one default:
C<allow_extra> is set to C<0> in every C<validate_with> call unless the
caller explicitly overrides it.  This means passing an unrecognised
parameter name causes an immediate C<croak> rather than being silently
ignored -- the "strict" behaviour the name implies.

All type constants (C<SCALAR>, C<ARRAYREF>, etc.) and the C<validate_with>
function are re-exported under the C<:all> and C<:types> tags, exactly as
they appear in L<Params::Validate>, so drop-in replacement requires only
changing the C<use> line.

C<validate> and C<validate_pos> are intentionally B<not> re-exported:
their C<\@> prototype is incompatible with the common
C<my ($self, %args) = @_> idiom and was the original motivation for
switching to C<validate_with> across this codebase.

=head1 LIMITATIONS

=over 4

=item * C<allow_extra> can still be overridden per-call by passing
C<< allow_extra => 1 >> to C<validate_with>.  This escape hatch is
intentional for the rare case where extra keys must be forwarded to
another layer.

=item * C<set_options> from L<Params::Validate> is not re-exported;
per-package global options should not be needed when every call site
uses C<validate_with>.

=back

=cut

# ---------------------------------------------------------------------------
# Type bitmask constants.
# We call the Params::Validate constants at compile time and re-export them
# under our own namespace so callers only need to 'use' this one module.
# ---------------------------------------------------------------------------

use constant {
	SCALAR    => Params::Validate::SCALAR(),
	ARRAYREF  => Params::Validate::ARRAYREF(),
	HASHREF   => Params::Validate::HASHREF(),
	CODEREF   => Params::Validate::CODEREF(),
	GLOB      => Params::Validate::GLOB(),
	GLOBREF   => Params::Validate::GLOBREF(),
	SCALARREF => Params::Validate::SCALARREF(),
	HANDLE    => Params::Validate::HANDLE(),
	BOOLEAN   => Params::Validate::BOOLEAN(),
	UNDEF     => Params::Validate::UNDEF(),
	OBJECT    => Params::Validate::OBJECT(),
};

Readonly::Array my @TYPE_CONSTANTS => qw(
	SCALAR ARRAYREF HASHREF CODEREF GLOB GLOBREF SCALARREF
	HANDLE BOOLEAN UNDEF OBJECT
);

our @EXPORT_OK = (@TYPE_CONSTANTS, 'validate_with');

our %EXPORT_TAGS = (
	all   => \@EXPORT_OK,
	types => \@TYPE_CONSTANTS,
);

# ---------------------------------------------------------------------------

=head2 validate_with

=head3 PURPOSE

Validate named parameters against a spec hashref, rejecting any key not
listed in the spec (C<allow_extra => 0> by default).

This is a direct delegation to C<Params::Validate::validate_with> with one
changed default.  See L<Params::Validate/validate_with> for the full spec
syntax.

=head3 API SPECIFICATION

=head4 INPUT

  params       Hashref or Arrayref  required  the parameters to validate
  spec         Hashref              required  the validation spec
  allow_extra  Boolean              optional  default 0; set 1 to permit unknown keys
  called       Scalar               optional  function name for error messages

=head4 OUTPUT

Hash (or list) of validated, possibly-defaulted parameters.

=head3 MESSAGES

  Code  | Severity | Message                               | Resolution
  ------+----------+---------------------------------------+----------------------------
  PVS01 | FATAL    | The following parameter was passed ... | Remove the unknown parameter
        |          | but was not listed in the validation  |
        |          | options: {key}                        |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  ValidateWithOp
  params      : Hashref
  spec        : Hashref
  allow_extra : Boolean  == false (default)
  output      : Hashref
  -------------------------------------------------------
  dom(output) = dom(spec)
  forall k : dom(params) | allow_extra = false @
      k in dom(spec)

=head3 SIDE EFFECTS

None.

=head3 USAGE EXAMPLE

    my %validated = validate_with(
        params => \%args,
        spec   => {
            path => { type => SCALAR },
            size => { type => SCALAR, default => 0 },
        },
    );

=cut

sub validate_with {
	my (%args) = @_;

	$args{allow_extra} //= 0;

	return Params::Validate::validate_with(%args);
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
