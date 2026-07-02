package Test::CPAN::Health::Check::PODCoverage;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use File::Spec;
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

Readonly::Scalar my $SCORE_PASS  => 90;   # >= this -> pass
Readonly::Scalar my $SCORE_WARN  => 50;   # >= this -> warn; below -> fail

# Subs that are never expected to have their own POD section.
Readonly::Hash my %EXEMPT_SUBS => map { $_ => 1 } qw(
	DESTROY AUTOLOAD BEGIN END INIT CHECK UNITCHECK import unimport
);

=head1 NAME

Test::CPAN::Health::Check::PODCoverage - Check that all public methods have POD

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::PODCoverage;

    my $check  = Test::CPAN::Health::Check::PODCoverage->new;
    my $result = $check->run($dist);

    printf "%s: %s\n", $result->status, $result->summary;

=head1 DESCRIPTION

Parses each C<.pm> file under C<lib/> to identify public subroutines (those
not prefixed with C<_> and not in the exempt set: DESTROY, AUTOLOAD, BEGIN,
END, etc.) and checks whether each one appears as a C<=head2>, C<=head3>, or
C<=head4> entry in the file's POD.

Score = (documented_subs / total_public_subs) * 100, averaged across all
files.  Status thresholds: pass E<ge> 90, warn E<ge> 50, fail otherwise.

=head1 LIMITATIONS

=over 4

=item * Documentation inherited from a parent class is not counted -- each
file is analysed in isolation.

=item * Only C<=head2>/C<=head3>/C<=head4> headings are matched against sub
names; C<=item> entries are not counted.

=item * Generated or XS subs not visible in the C<.pm> source are not counted.

=back

=cut

sub id          { 'pod_coverage'                                          }
sub name        { 'POD Coverage'                                          }
sub description { 'Checks that all public methods are documented in POD'  }
sub weight      { 5                                                       }
sub category    { 'quality'                                               }

=head2 run

=head3 PURPOSE

Compute the fraction of public subroutines that have a corresponding POD
heading across all C<.pm> files in the distribution.

=head3 API SPECIFICATION

=head4 INPUT

  dist     Test::CPAN::Health::Distribution  required
  context  Hashref                           optional

=head4 OUTPUT

L<Test::CPAN::Health::Result> with check_id C<'pod_coverage'>.

=head3 MESSAGES

  Code  | Severity | Message                                    | Resolution
  ------+----------+--------------------------------------------+-----------
  PC001 | SKIP     | No .pm files found under lib/              | Add lib/ modules
  PC002 | SKIP     | No public subs found in any .pm file       | Add public methods
  PC003 | PASS     | POD coverage N%                            |
  PC004 | WARN     | POD coverage N% -- some methods undocumented| Add POD
  PC005 | FAIL     | POD coverage N% -- most methods undocumented| Add POD

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  PODCoverageOp
  subs_total    : N
  subs_covered  : N
  score         : 0..100
  -------------------------------------------------------
  subs_total = 0    => status = skip
  score >= 90       => status = pass
  score >= 50       => status = warn
  score < 50        => status = fail

=head3 SIDE EFFECTS

Reads source files; no network or subprocess I/O.

=head3 USAGE EXAMPLE

    my $result = Test::CPAN::Health::Check::PODCoverage->new->run($dist);
    print $result->summary;

=cut

sub run {
	my ($self, $dist, $context) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless ref($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	my @pm_files = @{ $dist->pm_files };

	unless (@pm_files) {
		return $self->_skip('No .pm files found under lib/');
	}

	my ($total_subs, $covered_subs) = (0, 0);
	my @undocumented;

	for my $file (@pm_files) {
		my ($pub_subs_ref, $pod_names_ref) = _parse_file($file);
		for my $sub_name (@{$pub_subs_ref}) {
			$total_subs++;
			if ($pod_names_ref->{$sub_name}) {
				$covered_subs++;
			} else {
				push @undocumented, $sub_name;
			}
		}
	}

	unless ($total_subs) {
		return $self->_skip('No public subroutines found in .pm files');
	}

	my $score  = int($covered_subs / $total_subs * 100);
	my $pct    = sprintf('%d%%', $score);
	my $status = $score >= $SCORE_PASS ? 'pass'
	           : $score >= $SCORE_WARN ? 'warn'
	           :                         'fail';

	my @details = map { "Undocumented: $_" } @undocumented;

	return $self->_result(
		status  => $status,
		score   => $score,
		summary => sprintf(
			'POD coverage %s (%d of %d public sub(s) documented)',
			$pct, $covered_subs, $total_subs,
		),
		details => \@details,
		data    => {
			name        => $self->name,
			total       => $total_subs,
			covered     => $covered_subs,
			undocumented => \@undocumented,
		},
	);
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Parse a .pm file to identify public subs and POD-documented names.
# Returns (arrayref-of-public-sub-names, hashref-of-pod-names).
sub _parse_file {
	my ($file) = @_;

	open my $fh, '<', $file or return ([], {});

	my @public_subs;
	my %pod_names;
	my $in_pod = 0;

	while (my $line = <$fh>) {
		chomp $line;

		# Update POD state first, then still process the directive line itself.
		if ($line =~ /^=(\w+)/) {
			$in_pod = ($1 ne 'cut');
		}

		if ($in_pod && $line =~ /^=head[234]\s+(\w+)/) {
			$pod_names{$1}++;
		} elsif (!$in_pod && $line =~ /^sub\s+([a-zA-Z]\w*)\b/ && !$EXEMPT_SUBS{$1} && $1 !~ /^_/) {
			push @public_subs, $1;
		}
	}

	close $fh;
	return (\@public_subs, \%pod_names);
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
