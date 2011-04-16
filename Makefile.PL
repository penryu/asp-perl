use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME' => 'ASP',
	'VERSION_FROM' => 'ASP.pm',
	'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
	($] ge '5.005')
	? (
	 'AUTHOR' => 'Tim Hammerquist (tim@dichosoft.com)',
	 'ABSTRACT' => 'Simplify ASP PerlScript programming',
	) : (),
);
