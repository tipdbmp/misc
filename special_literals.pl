use Cwd (); use File::Basename ();
my $__DIR__  = File::Basename::dirname(Cwd::abs_path(__FILE__));
my $__NAME__ = File::Basename::basename(__FILE__) =~ s/\.pm$//r;
