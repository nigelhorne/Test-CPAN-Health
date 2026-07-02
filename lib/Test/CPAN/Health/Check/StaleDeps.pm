package Test::CPAN::Health::Check::StaleDeps;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

Readonly::Scalar my $METACPAN_API  => 'https://fastapi.metacpan.org/v1';
Readonly::Scalar my $HTTP_TIMEOUT  => 30;
Readonly::Scalar my $SCORE_PASS    => 80;
Readonly::Scalar my $SCORE_WARN    => 60;

=head1 NAME

Test::CPAN::Health::Check::StaleDeps - Check for dependencies pinned to old major versions

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::StaleDeps;

    my $check  = Test::CPAN::Health::Check::StaleDeps->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Compares the minimum declared version for each runtime dependency against the
latest release on MetaCPAN.  A dependency is flagged as I<stale> when:

=over 4

=item * It has a declared minimum version greater than zero, AND

=item * The latest release's leading integer (the component before the first
decimal point) is strictly greater than the declared minimum's leading integer.

=back

The score is the fraction of non-stale dependencies expressed as a 0-100
integer.  Perl built-in pragmas (lowercase names) and core modules (identified
via L<Module::CoreList> when available, or a hardcoded fallback set) are
excluded from analysis.

Status thresholds: pass E<ge> 80, warn E<ge> 60, fail otherwise.

=head1 LIMITATIONS

=over 4

=item * Heuristic leading-integer comparison may produce false positives for
modules that use date-based (C<20250101>-style) versioning where each year is a
new "major".

=item * Dependencies declared with version C<0> (any version acceptable) are
not flagged even if the module has advanced significantly.

=item * MetaCPAN is queried serially for each dependency.

=back

=cut

sub id          { 'stale_deps'                                                  }
sub name        { 'Stale Dependencies'                                          }
sub description { 'Checks for dependencies pinned to significantly old versions' }
sub weight      { 5                                                              }
sub category    { 'security'                                                    }

=head2 run

=head3 PURPOSE

Compare declared dependency versions against the latest MetaCPAN releases and
return a scored result listing stale dependencies.

=head3 API SPECIFICATION

=head4 INPUT

  dist     Test::CPAN::Health::Distribution  required
  context  Hashref                           optional

=head4 OUTPUT

L<Test::CPAN::Health::Result> with check_id C<'stale_deps'>.

=head3 MESSAGES

  Code  | Severity | Message                               | Resolution
  ------+----------+---------------------------------------+-----------
  SD001 | SKIP     | Network checks disabled               | Remove --no-network
  SD002 | SKIP     | No META file found                    | Add META.yml / META.json
  SD003 | SKIP     | No checkable runtime dependencies     | n/a
  SD004 | PASS     | All N dependencies are current        |
  SD005 | WARN     | N of M dependencies may be stale      | Update declared versions
  SD006 | FAIL     | N of M dependencies may be stale      | Update declared versions

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  StaleDepsOp
  stale   : N    -- count of stale deps
  total   : N    -- count of checked deps
  score   : 0..100
  -------------------------------------------------------
  no_network    => status = skip
  meta = undef  => status = skip
  total = 0     => status = skip
  score >= 80   => status = pass
  score >= 60   => status = warn
  score < 60    => status = fail

=head3 SIDE EFFECTS

Makes one HTTPS GET request to C<fastapi.metacpan.org> per dependency.

=head3 USAGE EXAMPLE

    my $result = Test::CPAN::Health::Check::StaleDeps->new->run($dist);
    printf "Stale: %s\n", $result->summary;

=cut

sub run {
	my ($self, $dist, $context) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless ref($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	return $self->_skip('Network checks disabled (--no-network)')
		if $self->no_network;

	my $meta = $dist->meta;
	return $self->_skip('No META file found') unless $meta;

	my $prereqs  = $meta->prereqs;
	my $runtime  = $prereqs->requirements_for('runtime', 'requires');
	my %deps     = %{ $runtime->as_string_hash };

	my $use_corelist = eval { require Module::CoreList; 1 };

	# Collect deps that are worth checking (non-core, non-pragma, versioned)
	my %checkable;
	for my $mod (sort keys %deps) {
		next if $mod eq 'perl';
		next if $mod =~ /^[a-z]/;    # lowercase = pragma (strict, warnings, etc.)
		if ($use_corelist) {
			next if Module::CoreList->first_release($mod);
		}
		$checkable{$mod} = $deps{$mod};
	}

	return $self->_skip('No checkable runtime dependencies found')
		unless %checkable;

	my (@stale_mods, @current_mods);

	for my $mod (sort keys %checkable) {
		my $declared = $checkable{$mod} // '0';

		# Skip deps with no meaningful version constraint ("0" means "any")
		next if $declared == 0;

		my ($data, $err) = _http_get("$METACPAN_API/module/$mod");
		next if $err;    # skip quietly if module not indexed
		next unless defined $data->{version};

		my $dec_major    = _major($declared);
		my $latest_major = _major($data->{version});

		if ($latest_major > $dec_major) {
			push @stale_mods, sprintf('%s (declared >= %s, latest %s)',
				$mod, $declared, $data->{version});
		} else {
			push @current_mods, $mod;
		}
	}

	my $total = @stale_mods + @current_mods;
	return $self->_skip('No versioned runtime dependencies found') unless $total;

	my $n_stale = scalar @stale_mods;
	my $score   = int(($total - $n_stale) / $total * 100);
	my $status  = $score >= $SCORE_PASS ? 'pass'
	            : $score >= $SCORE_WARN ? 'warn'
	            :                         'fail';

	my $summary = $n_stale
		? "$n_stale of $total runtime dependencies may be stale (major version behind)"
		: "All $total checked runtime dependencies are current";

	return $self->_result(
		status  => $status,
		score   => $score,
		summary => $summary,
		details => [ map { "Stale: $_" } sort @stale_mods ],
		data    => {
			name         => $self->name,
			total        => $total,
			stale        => $n_stale,
			stale_mods   => \@stale_mods,
			current_mods => \@current_mods,
		},
	);
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Extract the leading integer component ("major") from a version string.
# Examples: "1.23" -> 1, "v2.0.0" -> 2, "0.99" -> 0, "10.00" -> 10.
sub _major {
	my ($v) = @_;
	return 0 unless defined $v && length $v;
	my ($n) = $v =~ /^[v]?(\d+)/;
	return $n // 0;
}

sub _http_get {
	my ($url) = @_;

	require HTTP::Tiny;
	require JSON::MaybeXS;

	my $ua  = HTTP::Tiny->new(timeout => $HTTP_TIMEOUT);
	my $res = $ua->get($url, { headers => { 'Accept' => 'application/json' } });

	return (undef, "HTTP $res->{status} $res->{reason}") unless $res->{success};

	my $data = eval { JSON::MaybeXS::decode_json($res->{content}) };
	return (undef, "JSON parse error: $@") if $@;

	return ($data, undef);
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
