use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# Every module has a $VERSION, the distribution's, so a caller can ask
# for the version a module's feature came in, as
# `use Ekorn::Pipeline::Tooling v0.3.15 qw(:context)`. minil prepare
# sets $VERSION in every module that declares one, so they stay in step
# as long as each declares one, for its own package, and no other
# package does (roadmap 2026-0053, D5).

use File::Find qw(find);
use Ekorn::Pipeline;

my $want = Ekorn::Pipeline->VERSION;

# The modules, by their files under lib/, as installed or as here.
my($lib) = grep { -e "$_/Ekorn/Pipeline.pm" } @INC;
my @files;
find(sub { push @files, $File::Find::name if m( \.pm \z )x }, "$lib/Ekorn");

# Return the code of a module's file, before its POD.
sub code_of ($path) {
    open my $in, '<', $path or die "Can't read $path: $!";
    local $/ = undef;
    my $text = <$in>;
    close $in;
    return $text =~ s( ^ __END__ $ .* )()xmsr;
}

# The module each file holds, by its package.
my %module_of
    = map { $_ => s( \A \Q$lib\E / )()xr =~ s( \.pm \z )()xr =~ s( / )(::)xgr }
    @files;
my %is_module = map { $_ => 1 } values %module_of;

for my $path (sort @files) {
    my $module   = $module_of{$path};
    my $code     = code_of($path);
    my @versions = $code =~ m( ^ \s* our \s+ \$VERSION \b )xmg;
    is scalar @versions, 1, "$module declares one \$VERSION";
    require $path =~ s( \A \Q$lib\E / )()xr;
    is $module->VERSION, $want, "$module is at the distribution's version";
    # The packages it defines inside, which a $VERSION would stray to;
    # Operators reopens other modules' packages, which have their own.
    for my $inner (grep { !$is_module{$_} }
        $code =~ m( ^ \s* package \s+ ([\w:]+) \s* \{ )xmg)
    {
        is $inner->VERSION, undef, "$inner, inside $module, has none";
    }
}

ok scalar @files >= 23, 'every module was found';

done_testing;
