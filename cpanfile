# Generated from Makefile.PL using makefilepl2cpanfile

requires 'perl', '5.014';

requires 'CPAN::Audit';
requires 'CPAN::Meta';
requires 'Carp';
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
requires 'Params::Validate::Strict', '0.35';
requires 'Perl::Critic';
requires 'Perl::Metrics::Simple';
requires 'Perl::MinimumVersion';
requires 'Pod::Checker';
requires 'Pod::Coverage';
requires 'Readonly', '2.00';
requires 'Scalar::Util';
requires 'Term::ANSIColor';
requires 'YAML::Tiny';

on 'test' => sub {
	requires 'IPC::System::Simple';
	requires 'Test::Exception';
	requires 'Test::MockObject';
	requires 'Test::Most';
};

on 'develop' => sub {
	requires 'Devel::Cover';
	requires 'Perl::Critic';
	requires 'Test::Pod';
	requires 'Test::Pod::Coverage';
};
