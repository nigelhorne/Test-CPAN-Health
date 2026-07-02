# Runtime dependencies
requires 'perl', '5.014';

requires 'Carp';
requires 'CPAN::Audit';
requires 'CPAN::Meta';
requires 'DBD::SQLite';
requires 'DBI';
requires 'File::Find::Rule';
requires 'File::Spec';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'HTTP::Tiny';
requires 'JSON::MaybeXS';
requires 'Module::CPANTS::Analyse';
requires 'Params::Get';
requires 'Params::Validate', '1.29';   # consumed by the bundled Params::Validate::Strict
requires 'Perl::Critic';
requires 'Perl::Metrics::Simple';
requires 'Perl::MinimumVersion';
requires 'Pod::Checker';
requires 'Pod::Coverage';
requires 'Readonly', '2.00';
requires 'Scalar::Util';
requires 'Term::ANSIColor';
requires 'YAML::Tiny';

# Optional -- skipped when --no-cover is passed to cpan-health
recommends 'Devel::Cover';

# Test dependencies
on test => sub {
	requires 'Test::More', '0.96';
	requires 'Test::Exception';
	requires 'Test::MockObject';
};
