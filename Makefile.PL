use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'			=> 'ASP',
	'VERSION_FROM'	=> 'ASP.pm',
	'dist'			=> {COMPRESS => 'gzip -9f', SUFFIX => '.gz'},
	($] ge '5.005')
		? (
			'AUTHOR'	=> 'Tim Hammerquist (timmy@cpan.org)',
			'ABSTRACT_FROM'	=> 'ASP.pm',
		) : (),
);
