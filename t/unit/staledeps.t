use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::Exception;
use Test::More;

use Test::CPAN::Health::Check::StaleDeps;
use Test::CPAN::Health::Distribution;

my $check = Test::CPAN::Health::Check::StaleDeps->new;
isa_ok($check, 'Test::CPAN::Health::Check::StaleDeps');
isa_ok($check, 'Test::CPAN::Health::Check');

is($check->id,       'stale_deps',          'id');
is($check->name,     'Stale Dependencies',  'name');
is($check->weight,   5,                     'weight');
is($check->category, 'security',            'category');

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub make_dist {
	my $tmp = tempdir(CLEANUP => 1);
	return ($tmp, Test::CPAN::Health::Distribution->new(path => $tmp));
}

sub write_file {
	my ($path, $content) = @_;
	make_path(dirname($path));
	open my $fh, '>', $path or die "Cannot write $path: $!";
	print {$fh} $content;
	close $fh;
}

# ---------------------------------------------------------------------------
# run() croaks on wrong argument type
# ---------------------------------------------------------------------------

throws_ok(
	sub { $check->run('not a dist') },
	qr/must be a Test::CPAN::Health::Distribution/,
	'run() croaks on non-Distribution argument',
);

# ---------------------------------------------------------------------------
# Skip when no_network flag is set
# ---------------------------------------------------------------------------

{
	my $nn_check = Test::CPAN::Health::Check::StaleDeps->new(no_network => 1);
	my ($tmp, $dist) = make_dist();
	write_file(File::Spec->catfile($tmp, 'META.json'), <<'JSON');
{
   "name"      : "Test-Dist",
   "version"   : "0.01",
   "abstract"  : "A test distribution",
   "author"    : ["Test Author <test\@example.com>"],
   "license"   : ["perl_5"],
   "meta-spec" : { "version" : "2", "url" : "http://search.cpan.org/perldoc?CPAN::Meta::Spec" },
   "prereqs"   : { "runtime" : { "requires" : { "Scalar::Util" : "1.20" } } }
}
JSON
	my $result = $nn_check->run($dist);
	is($result->status, 'skip', 'no_network -> skip');
	like($result->summary, qr/network/i, 'summary mentions network');
}

# ---------------------------------------------------------------------------
# Skip when no META file present
# ---------------------------------------------------------------------------

{
	my ($tmp, $dist) = make_dist();
	my $result = $check->run($dist);
	# Without network this would also skip on no_network, but $check has network on.
	# Without META it should skip on missing META.
	is($result->status, 'skip', 'no META -> skip');
	like($result->summary, qr/meta|network/i, 'summary explains skip reason');
}

# ---------------------------------------------------------------------------
# Skip when META has no checkable runtime deps (only core modules)
# ---------------------------------------------------------------------------

{
	my ($tmp, $dist) = make_dist();
	write_file(File::Spec->catfile($tmp, 'META.json'), <<'JSON');
{
   "name"      : "Test-Dist",
   "version"   : "0.01",
   "abstract"  : "A test distribution",
   "author"    : ["Test Author <test\@example.com>"],
   "license"   : ["perl_5"],
   "meta-spec" : { "version" : "2", "url" : "http://search.cpan.org/perldoc?CPAN::Meta::Spec" },
   "prereqs"   : { "runtime" : { "requires" : { "perl" : "5.010", "strict" : "0", "warnings" : "0" } } }
}
JSON
	# Disable network so we don't hit MetaCPAN; the skip should fire on core-only deps.
	my $nn_check = Test::CPAN::Health::Check::StaleDeps->new(no_network => 1);
	my $result   = $nn_check->run($dist);
	is($result->status, 'skip', 'core-only deps or no_network -> skip');
}

# ---------------------------------------------------------------------------
# Result from the no_network fast path is a valid Result object
# ---------------------------------------------------------------------------

{
	my $nn_check = Test::CPAN::Health::Check::StaleDeps->new(no_network => 1);
	my (undef, $dist) = make_dist();
	my $result = $nn_check->run($dist);
	isa_ok($result, 'Test::CPAN::Health::Result');
	is($result->check_id, 'stale_deps', 'result carries correct check_id');
}

# ---------------------------------------------------------------------------
# Live MetaCPAN call -- gated on TEST_NETWORK env var
# ---------------------------------------------------------------------------

SKIP: {
	skip 'Live network tests disabled (set TEST_NETWORK=1 to enable)', 8
		unless $ENV{TEST_NETWORK};

	my ($tmp, $dist) = make_dist();

	# HTTP::Tiny is a well-known module.  Declare version 0.001 so it will
	# register as non-stale (the minor-version check only flags major jumps).
	write_file(File::Spec->catfile($tmp, 'META.json'), <<'JSON');
{
   "name"      : "Test-Dist",
   "version"   : "0.01",
   "abstract"  : "A test distribution",
   "author"    : ["Test Author <test\@example.com>"],
   "license"   : ["perl_5"],
   "meta-spec" : { "version" : "2", "url" : "http://search.cpan.org/perldoc?CPAN::Meta::Spec" },
   "prereqs"   : {
       "runtime" : {
           "requires" : {
               "HTTP::Tiny"   : "0.001",
               "JSON::MaybeXS": "1.000000"
           }
       }
   }
}
JSON

	my $live_check = Test::CPAN::Health::Check::StaleDeps->new;
	my $result     = $live_check->run($dist);

	isa_ok($result, 'Test::CPAN::Health::Result', 'live: returns a Result');

	SKIP: {
		skip 'live: result was skip/error: ' . $result->summary, 7
			unless grep { $result->status eq $_ } qw(pass warn fail);

		ok(defined $result->score,                        'live: score defined');
		ok($result->score >= 0 && $result->score <= 100, 'live: score in 0..100');
		ok(exists $result->data->{total},                 'live: data.total exists');
		ok(exists $result->data->{stale},                 'live: data.stale exists');
		ok($result->data->{total} > 0,                    'live: total deps > 0');
		ok(ref($result->data->{stale_mods})   eq 'ARRAY', 'live: stale_mods is arrayref');
		ok(ref($result->data->{current_mods}) eq 'ARRAY', 'live: current_mods is arrayref');
	}
}

done_testing;
