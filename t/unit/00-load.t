use strict;
use warnings;

use Test::More;

my @modules = qw(
	Params::Validate::Strict
	Test::CPAN::Health
	Test::CPAN::Health::Cache
	Test::CPAN::Health::Check
	Test::CPAN::Health::Distribution
	Test::CPAN::Health::Report
	Test::CPAN::Health::Reporter::JSON
	Test::CPAN::Health::Reporter::Terminal
	Test::CPAN::Health::Result
	Test::CPAN::Health::Runner
	Test::CPAN::Health::Check::SecurityAdvisories
	Test::CPAN::Health::Check::SemVer
);

plan tests => scalar @modules;

use_ok($_) for @modules;
