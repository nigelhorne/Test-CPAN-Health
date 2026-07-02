package Test::CPAN::Health;

use strict;
use warnings;
use autodie qw(:all);

use Carp qw(croak carp);
use Readonly;
use Scalar::Util qw(blessed);
use Params::Get;
use Params::Validate::Strict qw(validate_strict);

our $VERSION = '0.01';

Readonly::Hash my %DEFAULTS => (
	format     => 'terminal',
	no_network => 0,
	no_cover   => 0,
	severity   => 3,
	min_score  => 0,
);

# Canonical ordered list of checks.  The Runner loads these in sequence;
# later checks may use metadata produced by earlier ones (e.g. ReverseDeps
# count is passed as context to SecurityAdvisories to scale its weight).
Readonly::Array my @DEFAULT_CHECKS => qw(
	Test::CPAN::Health::Check::SemVer
	Test::CPAN::Health::Check::MetaJSON
	Test::CPAN::Health::Check::License
	Test::CPAN::Health::Check::MinPerl
	Test::CPAN::Health::Check::PODCoverage
	Test::CPAN::Health::Check::DocQuality
	Test::CPAN::Health::Check::Examples
	Test::CPAN::Health::Check::Benchmarks
	Test::CPAN::Health::Check::Perlcritic
	Test::CPAN::Health::Check::Complexity
	Test::CPAN::Health::Check::DuplicateCode
	Test::CPAN::Health::Check::Deprecations
	Test::CPAN::Health::Check::TestCoverage
	Test::CPAN::Health::Check::Kwalitee
	Test::CPAN::Health::Check::CIConfig
	Test::CPAN::Health::Check::StaleDeps
	Test::CPAN::Health::Check::AbandonedDeps
	Test::CPAN::Health::Check::SecurityAdvisories
	Test::CPAN::Health::Check::CPANTesters
	Test::CPAN::Health::Check::ReverseDeps
);

Readonly::Hash my %VALID_FORMATS => map { $_ => 1 } qw(terminal json html tap);

=head1 NAME

Test::CPAN::Health - Analyse a CPAN distribution and produce a comprehensive health report

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

B<Command-line (the usual entry point):>

    # Analyse the current directory
    cpan-health .

    # Analyse by CPAN dist name (downloads and unpacks automatically)
    cpan-health LWP-UserAgent

    # Analyse by module name
    cpan-health LWP::UserAgent

    # JSON output -- useful for editor or CI integration
    cpan-health --format=json My-Dist

    # Fail the build if the health score falls below 80
    cpan-health --min-score=80 --no-cover My-Dist

    # Skip slow or network-dependent checks
    cpan-health --no-network --no-cover .

    # Run only the security and versioning checks
    cpan-health --check=security_advisories,sem_ver My-Dist

    # Skip specific checks by id
    cpan-health --skip=cpan_testers,kwalitee .

    # TAP output -- pipe into any test harness
    cpan-health --format=tap My-Dist | prove --stdin

    # Write the report to a file
    cpan-health --format=json --output=report.json LWP-UserAgent

    # Show all available options
    cpan-health --help

B<Perl API (for programmatic use):>

    use Test::CPAN::Health;

    # Analyse a local unpacked distribution
    my $health = Test::CPAN::Health->new(path => '/path/to/My-Dist-1.00');
    my $report = $health->analyse;
    $health->report_to($report);

    # Analyse a distribution by CPAN dist name
    my $health = Test::CPAN::Health->new(
        dist      => 'LWP-UserAgent',
        format    => 'json',
        min_score => 80,
    );
    my $report = $health->analyse;
    exit 1 if $report->overall_score < 80;

    # Analyse by module name, skipping network-dependent checks
    my $health = Test::CPAN::Health->new(
        module     => 'LWP::UserAgent',
        no_network => 1,
        skip       => ['Test::CPAN::Health::Check::CPANTesters'],
    );

=head1 DESCRIPTION

Test::CPAN::Health is a comprehensive distribution health checker for CPAN
modules -- analogous to C<cargo audit> + C<npm audit> + C<go vet> +
C<perlcritic> + C<cpants>, all unified into a single scored report.

It accepts a distribution as a local path, a CPAN distribution name, or a
module name.  It runs a configurable battery of checks (POD coverage, CPAN
Testers pass rate, kwalitee, CI configuration, META validity, SPDX license,
stale and abandoned dependencies, known CVEs, reverse dependency count,
documentation quality, examples, benchmarks, semantic versioning, perlcritic
violations, code complexity, duplicate code, test coverage, minimum Perl
version, and deprecation warnings) and returns a weighted score out of 100.

The report can be rendered as coloured terminal output, JSON, HTML, or TAP
(allowing cpan-health to run inside a standard test harness).

=head1 LIMITATIONS

=over 4

=item * The C<TestCoverage> check requires C<Devel::Cover> and must run the
distribution's own test suite, which is slow and may have side effects.

=item * Network-dependent checks (CPANTesters, StaleDeps, AbandonedDeps,
SecurityAdvisories, ReverseDeps) require internet access and are subject to
upstream API availability and rate limits.

=item * The C<DuplicateCode> check uses a token-fingerprint algorithm via
C<PPI> and may produce false positives on generated or data-heavy code.

=back

=cut

sub new {
	my $class;
	my $args;

	$args = validate_strict(
		schema => {
			distribution => { type => 'object', isa => 'Test::CPAN::Health::Distribution', optional => 1 },
			path         => { type => 'string',   optional => 1 },
			module       => { type => 'string',   optional => 1 },
			dist         => { type => 'string',   optional => 1 },
			format       => { type => 'string',   optional => 1 },
			checks       => { type => 'arrayref', optional => 1 },
			skip         => { type => 'arrayref', optional => 1 },
			no_network   => { type => 'scalar',   optional => 1 },
			no_cover     => { type => 'scalar',   optional => 1 },
			severity     => { type => 'integer',  min => 1, max => 5, optional => 1 },
			min_score    => { type => 'integer',  min => 0, max => 100, optional => 1 },
			cache_dir    => { type => 'string',   optional => 1 },
		},
		input => Params::Get::get_params(undef, \@_) || {}
	);

	croak 'One of path, module, dist, or distribution is required'
		unless $args && ($args->{path} || $args->{module} || $args->{dist} || $args->{distribution});

	my $format = lc($args->{format} // $DEFAULTS{format});
	croak "Unknown format '$format'; expected one of: " . join(', ', sort keys %VALID_FORMATS)
		unless $VALID_FORMATS{$format};

	my $self = bless {
		_distribution => $args->{distribution},
		_runner       => undef,
		_reporter     => undef,
		_cache        => undef,
		_format       => $format,
		_no_network   => $args->{no_network} // $DEFAULTS{no_network},
		_no_cover     => $args->{no_cover}   // $DEFAULTS{no_cover},
		_severity     => $args->{severity}   // $DEFAULTS{severity},
		_min_score    => $args->{min_score}  // $DEFAULTS{min_score},
		_cache_dir    => $args->{cache_dir},
		_checks       => $args->{checks}     // [@DEFAULT_CHECKS],
		_skip         => { map { $_ => 1 } @{ $args->{skip} // [] } },
		_path         => $args->{path},
		_module       => $args->{module},
		_dist         => $args->{dist},
	}, $class;

	return $self;
}

=head2 analyse

Runs all configured checks against the distribution and returns a Report.

All components (Distribution, Cache, Runner, Reporter) are initialised
lazily on the first call so that construction is always cheap.

=head3 API SPECIFICATION

=head4 INPUT

No arguments.  Configuration comes from the constructor.

=head4 OUTPUT

Returns a L<Test::CPAN::Health::Report> object.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
        |          |                                    |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  AnalyseOp
  Test::CPAN::Health
  Report'
  -------------------------------------------------------
  distribution /= undefined
  Report' = Runner.run(distribution)
  overall_score(Report') in 0..100

=head3 SIDE EFFECTS

May download the distribution from CPAN, run its test suite (if
C<TestCoverage> is enabled), and write to the local HTTP cache.

=head3 USAGE EXAMPLE

    my $report = $health->analyse;
    print 'Score: ', $report->overall_score, "\n";

=cut

sub analyse {
	my $self = $_[0];

	$self->_init_distribution unless $self->{_distribution};
	$self->_init_cache         unless $self->{_cache};
	$self->_init_runner        unless $self->{_runner};
	$self->_init_reporter      unless $self->{_reporter};

	return $self->{_runner}->run($self->{_distribution});
}

=head2 report_to

=head3 PURPOSE

Render a Report to the configured output format and return the result
as a string.  Printing to STDOUT (for terminal/TAP formats) is the
responsibility of the caller or the CLI script.

=head3 API SPECIFICATION

=head4 INPUT

  report  Test::CPAN::Health::Report  required

=head4 OUTPUT

Scalar string containing the rendered report.

=head3 MESSAGES

  Code  | Severity | Message                            | Resolution
  ------+----------+------------------------------------+---------------------
        |          |                                    |

=head3 FORMAL SPECIFICATION

  -- Z schema (placeholder) --
  RenderOp
  reporter : Reporter
  report   : Report
  output   : String
  -------------------------------------------------------
  output = reporter.render(report)

=head3 SIDE EFFECTS

None beyond invoking the reporter.

=head3 USAGE EXAMPLE

    my $text = $health->report_to($report);
    print $text;

=cut

sub report_to {
	my ($self, $report) = @_;

	croak 'report must be a Test::CPAN::Health::Report'
		unless blessed($report) && $report->isa('Test::CPAN::Health::Report');

	$self->_init_reporter unless $self->{_reporter};

	return $self->{_reporter}->render($report);
}

# Read-only accessors

sub distribution { return $_[0]->{_distribution} }
sub runner       { return $_[0]->{_runner}       }
sub reporter     { return $_[0]->{_reporter}     }
sub cache        { return $_[0]->{_cache}        }
sub format       { return $_[0]->{_format}       }
sub min_score    { return $_[0]->{_min_score}    }

# ---------------------------------------------------------------------------
# Private initialisation helpers
# Each is idempotent: call as many times as needed, only runs once.
# ---------------------------------------------------------------------------

sub _init_distribution {
	my $self = $_[0];

	require Test::CPAN::Health::Distribution;

	if ($self->{_path}) {
		$self->{_distribution} = Test::CPAN::Health::Distribution->new(
			path => $self->{_path},
		);
	} elsif ($self->{_dist}) {
		$self->{_distribution} = Test::CPAN::Health::Distribution->from_cpan(
			$self->{_dist},
		);
	} elsif ($self->{_module}) {
		$self->{_distribution} = Test::CPAN::Health::Distribution->from_module(
			$self->{_module},
		);
	}

	return $self;
}

sub _init_cache {
	my $self = $_[0];

	require Test::CPAN::Health::Cache;

	$self->{_cache} = Test::CPAN::Health::Cache->new(
		$self->{_cache_dir} ? (cache_dir => $self->{_cache_dir}) : (),
	);

	return $self;
}

sub _init_runner {
	my $self = $_[0];

	require Test::CPAN::Health::Runner;

	my @checks;
	for my $check_class (@{$self->{_checks}}) {
		next if $self->{_skip}{$check_class};

		# Defer require so a missing optional check module does not abort
		# the whole run -- emit a warning and continue instead.
		eval { (my $file = "$check_class.pm") =~ s{::}{/}g; require $file };
		if ($@) {
			carp "Skipping check $check_class (cannot load): $@";
			next;
		}

		push @checks, $check_class->new(
			severity   => $self->{_severity},
			no_network => $self->{_no_network},
			no_cover   => $self->{_no_cover},
		);
	}

	$self->{_runner} = Test::CPAN::Health::Runner->new(
		checks => \@checks,
		cache  => $self->{_cache},
	);

	return $self;
}

sub _init_reporter {
	my $self = $_[0];

	Readonly::Hash my %REPORTER_MAP => (
		terminal => 'Test::CPAN::Health::Reporter::Terminal',
		json     => 'Test::CPAN::Health::Reporter::JSON',
		html     => 'Test::CPAN::Health::Reporter::HTML',
		tap      => 'Test::CPAN::Health::Reporter::TAP',
	);

	my $reporter_class = $REPORTER_MAP{ $self->{_format} }
		or croak "No reporter for format '$self->{_format}'";

	eval { (my $file = "$reporter_class.pm") =~ s{::}{/}g; require $file };
	croak "Cannot load reporter $reporter_class: $@" if $@;

	$self->{_reporter} = $reporter_class->new;

	return $self;
}

=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Nigel Horne.

Usage is subject to the GPL2 licence terms.
If you use it,
please let me know.

=cut

1;
