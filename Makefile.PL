use strict;
use warnings;
use ExtUtils::MakeMaker 7.00;

WriteMakefile(
	NAME             => 'Test::CPAN::Health',
	AUTHOR           => q{Nigel Horne <njh@bandsman.co.uk>},
	VERSION_FROM     => 'lib/Test/CPAN/Health.pm',
	ABSTRACT_FROM    => 'lib/Test/CPAN/Health.pm',
	LICENSE          => 'gpl_2',
	MIN_PERL_VERSION => '5.014',
	EXE_FILES        => ['scripts/cpan-health'],
	PREREQ_PM        => {
		'Carp'                  => 0,
		'CPAN::Audit'           => 0,
		'CPAN::Meta'            => 0,
		'DBD::SQLite'           => 0,
		'DBI'                   => 0,
		'File::Find::Rule'      => 0,
		'File::Spec'            => 0,
		'File::Temp'            => 0,
		'Getopt::Long'          => 0,
		'HTTP::Tiny'            => 0,
		'JSON::MaybeXS'         => 0,
		'Module::CPANTS::Analyse' => 0,
		'Params::Get'           => 0,
		'Params::Validate::Strict' => 0.35,
		'Perl::Critic'          => 0,
		'Perl::Metrics::Simple' => 0,
		'Perl::MinimumVersion'  => 0,
		'Pod::Checker'          => 0,
		'Pod::Coverage'         => 0,
		'Readonly'              => 2.00,
		'Scalar::Util'          => 0,
		'Term::ANSIColor'       => 0,
		'YAML::Tiny'            => 0,
	},
	TEST_REQUIRES => {
		'Test::More'            => 0.96,
		'Test::Exception'       => 0,
		'Test::MockObject'      => 0,
	},
	META_MERGE => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => 'https://github.com/nigelhorne/Test-CPAN-Health.git',
				web  => 'https://github.com/nigelhorne/Test-CPAN-Health',
			},
			bugtracker => {
				web => 'https://github.com/nigelhorne/Test-CPAN-Health/issues',
			},
		},
	},
	test => { TESTS => 't/*.t t/*/*.t' },
);
