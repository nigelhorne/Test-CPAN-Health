package Test::CPAN::Health::Runner;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Scalar::Util qw(blessed);
use Params::Validate::Strict qw(:all);

our $VERSION = '0.01';

=head1 NAME

Test::CPAN::Health::Runner - Orchestrate health checks against a distribution

=head1 SYNOPSIS

    use Test::CPAN::Health::Runner;

    my $runner = Test::CPAN::Health::Runner->new(
        checks => \@check_objects,
        cache  => $cache,
    );

    my $report = $runner->run($distribution);

=head1 DESCRIPTION

The Runner iterates over an ordered list of L<Test::CPAN::Health::Check>
objects, invokes each against a L<Test::CPAN::Health::Distribution>, wraps
any exceptions so a single failing check cannot abort the run, and collects
the L<Test::CPAN::Health::Result> objects into a L<Test::CPAN::Health::Report>.

Context propagation: after each check completes its result is stored, and
subsequent checks can inspect previously-completed results via the context
hashref passed to C<run>.  This is how C<ReverseDeps> count reaches
C<SecurityAdvisories> to scale its weight.

=head1 LIMITATIONS

=over 4

=item * Checks run sequentially.  Parallel execution via C<Parallel::ForkManager>
is planned for a future release.

=item * A check that calls C<exit> directly will terminate the entire run.

=back

=cut

sub new {
	my ($class, %args) = @_;

	validate_with(params => \%args, spec => {
		checks => { type => ARRAYREF, default => []    },
		cache  => { isa  => 'Test::CPAN::Health::Cache', optional => 1 },
	});

	my $self = bless {
		_checks  => $args{checks},
		_cache   => $args{cache},
	}, $class;

	return $self;
}

=head2 run

=head3 PURPOSE

Execute all configured checks against the given distribution and return a
populated L<Test::CPAN::Health::Report>.

Each check is wrapped in an eval block: exceptions produce an C<error>-status
Result rather than aborting the run.  Checks may return C<undef> to indicate
they are not applicable; those are silently skipped.

=head3 API SPECIFICATION

=head4 INPUT

  dist  Test::CPAN::Health::Distribution  required

=head4 OUTPUT

L<Test::CPAN::Health::Report> object with all results attached.

=head3 MESSAGES

  Code  | Severity | Message                              | Resolution
  ------+----------+--------------------------------------+------------------------
  RUN01 | WARNING  | Check {id} failed with exception {e} | Fix check or report bug

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  RunOp
  checks      : seq Check
  dist        : Distribution
  report!     : Report
  -------------------------------------------------------
  #report!.results <= #checks
  forall c : checks @
    (exists r : report!.results @ r.check_id = c.id)
    \/ c returned undefined

=head3 SIDE EFFECTS

Runs each check, which may have network, filesystem, and subprocess side
effects.  Writes check results to the cache if a cache is configured.

=head3 USAGE EXAMPLE

    my $report = $runner->run($dist);
    printf "%d checks run\n", scalar @{$report->results};

=cut

sub run {
	my ($self, $dist) = @_;

	croak 'dist must be a Test::CPAN::Health::Distribution'
		unless blessed($dist) && $dist->isa('Test::CPAN::Health::Distribution');

	require Test::CPAN::Health::Report;

	my $report  = Test::CPAN::Health::Report->new(checks => $self->{_checks});
	my %context;    # shared state for inter-check communication

	for my $check (@{$self->{_checks}}) {
		my $result = $self->_run_one($check, $dist, \%context);
		next unless defined $result;

		# Stamp the check category onto the result's data hash so the
		# Report can group by category without holding a reference to checks.
		$result->data->{category} = $check->category;

		$report->add_result($result);

		# Publish to context so later checks can observe earlier outcomes.
		$context{ $check->id } = $result;
	}

	return $report;
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# Attempt to run one check, catching any exception and converting it to an
# error Result.  Also handles the cache lookup/store cycle.
sub _run_one {
	my ($self, $check, $dist, $context) = @_;

	my $cache_key = $self->_cache_key($check, $dist);

	# Cache hit: deserialise and return early -- avoids network/disk work.
	if ($self->{_cache} && defined $cache_key) {
		my $cached = $self->{_cache}->get($cache_key);
		if (defined $cached) {
			require Test::CPAN::Health::Result;
			return Test::CPAN::Health::Result->new(%{$cached});
		}
	}

	my $result;
	eval {
		local $SIG{__DIE__} = sub { };   # suppress autodie noise inside eval
		$result = $check->run($dist, $context);
	};

	if ($@) {
		carp sprintf("Check '%s' failed with exception: %s", $check->id, $@);
		$result = $check->_error("Internal check error: $@");
	}

	# Cache successful (non-error) results with network data so they can be
	# reused across runs without hitting rate-limited APIs every time.
	if ($self->{_cache} && defined $result && !$result->is_error && defined $cache_key) {
		$self->{_cache}->set($cache_key, $result->as_hash);
	}

	return $result;
}

# Build a cache key from the dist name+version and check id.
# Returns undef for checks that should never be cached (future: per-check flag).
sub _cache_key {
	my ($self, $check, $dist) = @_;

	my $name    = $dist->name    // return undef;
	my $version = $dist->version // 'UNKNOWN';

	return join(':', $check->id, $name, $version);
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
