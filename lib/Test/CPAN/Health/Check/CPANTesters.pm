package Test::CPAN::Health::Check::CPANTesters;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Params::Validate::Strict qw(validate_strict);

use parent 'Test::CPAN::Health::Check';

our $VERSION = '0.01';

Readonly::Scalar my $METACPAN_API   => 'https://fastapi.metacpan.org/v1';
Readonly::Scalar my $HTTP_TIMEOUT   => 30;
Readonly::Scalar my $SCORE_PASS     => 80;
Readonly::Scalar my $SCORE_WARN     => 60;

=head1 NAME

Test::CPAN::Health::Check::CPANTesters - Check CPAN Testers pass/fail ratio

=head1 SYNOPSIS

    use Test::CPAN::Health::Check::CPANTesters;

    my $check  = Test::CPAN::Health::Check::CPANTesters->new;
    my $result = $check->run($dist);

=head1 DESCRIPTION

Fetches test statistics for the distribution's latest CPAN release via the
MetaCPAN release search API (which embeds aggregated CPAN Testers data).

Score = C<int(pass / (pass + fail) * 100)>.  C<na> and C<unknown> results are
not counted in the denominator so that untested platforms do not artificially
lower the score.

A C<fail> status from this check triggers a hard cap on the overall Report
score at 75 (applied by L<Test::CPAN::Health::Report>).

=head1 LIMITATIONS

=over 4

=item * The check can only run against a distribution that has been released
to CPAN and indexed by MetaCPAN.  Unreleased local distributions will be
skipped.

=item * CPAN Testers data in MetaCPAN may lag a few days behind the live
CPAN Testers database.

=item * Only pass and fail grades are used; C<na> (platform not applicable)
and C<unknown> (incomplete reports) are excluded from the denominator.

=back

=cut

sub id          { return 'cpan_testers'                                              }
sub name        { return 'CPAN Testers'                                              }
sub description { return 'Checks the CPAN Testers pass/fail ratio for the distribution' }
sub weight      { return 8                                                           }
sub category    { return 'ci'                                                        }

=head2 run

=head3 PURPOSE

Fetch the CPAN Testers statistics for the latest release of this distribution
and compute a pass-rate score.

=head3 API SPECIFICATION

=head4 INPUT

  dist     Test::CPAN::Health::Distribution  required
  context  Hashref                           optional

=head4 OUTPUT

L<Test::CPAN::Health::Result> with check_id C<'cpan_testers'>.

=head3 MESSAGES

  Code  | Severity | Message                                    | Resolution
  ------+----------+--------------------------------------------+-----------
  CT001 | SKIP     | Network checks disabled                    | Remove --no-network
  CT002 | SKIP     | Distribution name not available            | Add META.yml
  CT003 | SKIP     | Distribution not found on MetaCPAN         | Release to CPAN first
  CT004 | SKIP     | No CPAN Testers data available yet         | Wait for smoke reports
  CT005 | ERROR    | MetaCPAN API error: ...                    | Transient; retry
  CT006 | PASS     | CPAN Testers: N pass, M fail (P%)          |
  CT007 | WARN     | CPAN Testers: N pass, M fail (P%)          | Investigate failures
  CT008 | FAIL     | CPAN Testers: N pass, M fail (P%)          | Fix failing platforms

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  CPANTestersOp
  pass   : N
  fail   : N
  score  : 0..100
  -------------------------------------------------------
  no_network          => status = skip
  dist_name = undef   => status = skip
  not on MetaCPAN     => status = skip
  pass + fail = 0     => status = skip (no data)
  score >= 80         => status = pass
  score >= 60         => status = warn
  score < 60          => status = fail  (Report hard-caps at 75)

=head3 SIDE EFFECTS

Makes one HTTPS POST request to C<fastapi.metacpan.org>.

=head3 USAGE EXAMPLE

    my $result = Test::CPAN::Health::Check::CPANTesters->new->run($dist);
    printf "Pass rate: %d%%\n", $result->score;

=cut

sub run {
	my ($self, $dist, $context) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless ref($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	return $self->_skip('Network checks disabled (--no-network)')
		if $self->no_network;

	my $dist_name = $dist->name;
	return $self->_skip('Distribution name not available')
		unless defined $dist_name && length $dist_name;

	(my $dist_slug = $dist_name) =~ s/ :: /-/gx;

	# Search MetaCPAN for the latest indexed release of this distribution.
	# MetaCPAN embeds aggregated CPAN Testers pass/fail/na/unknown counts in
	# the 'tests' field of each release document.
	my ($data, $err) = _http_post(
		"$METACPAN_API/release/_search",
		{
			query => {
				bool => {
					must => [
						{ term => { distribution => $dist_slug } },
						{ term => { status       => 'latest'   } },
					],
				},
			},
			size    => 1,
			_source => [ 'tests', 'version', 'date' ],
		},
	);
	return $self->_error("MetaCPAN API error: $err") if $err;

	my $hits = $data->{hits}{hits} // [];
	return $self->_skip('Distribution not found on MetaCPAN') unless @$hits;

	my $release = $hits->[0]{_source} // {};
	my $tests   = $release->{tests}   // {};

	my $n_pass    = $tests->{pass}    // 0;
	my $n_fail    = $tests->{fail}    // 0;
	my $n_na      = $tests->{na}      // 0;
	my $n_unknown = $tests->{unknown} // 0;
	my $total     = $n_pass + $n_fail;

	return $self->_skip(
		sprintf('No CPAN Testers data yet for %s-%s',
			$dist_slug, $release->{version} // '?')
	) unless $total;

	my $score  = int($n_pass / $total * 100);
	my $status = $score >= $SCORE_PASS ? 'pass'
	           : $score >= $SCORE_WARN ? 'warn'
	           :                         'fail';

	return $self->_result(
		status  => $status,
		score   => $score,
		summary => sprintf(
			'CPAN Testers: %d pass, %d fail (%d%% pass rate) for v%s',
			$n_pass, $n_fail, $score, $release->{version} // '?',
		),
		details => (
			$n_fail > 0
				? [ "CPAN Testers reports $n_fail failure(s) -- see https://www.cpantesters.org/" ]
				: []
		),
		data    => {
			name      => $self->name,
			pass      => $n_pass,
			fail      => $n_fail,
			na        => $n_na,
			unknown   => $n_unknown,
			pass_rate => $score,
			version   => $release->{version},
		},
	);
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

sub _http_post {
	my ($url, $body) = @_;

	require HTTP::Tiny;
	require JSON::MaybeXS;

	my $ua  = HTTP::Tiny->new(timeout => $HTTP_TIMEOUT);
	my $res = $ua->post($url, {
		headers => {
			'Content-Type' => 'application/json',
			'Accept'       => 'application/json',
		},
		content => JSON::MaybeXS::encode_json($body),
	});

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
