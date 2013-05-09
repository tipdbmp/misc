package SetTheory;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);
BEGIN
{
    require Exporter;
    $VERSION   = 1.00;
    @ISA       = qw|Exporter|;
    @EXPORT    = qw||;
    @EXPORT_OK = qw||;
}

# ∪, ∩, -, ^
# ∪ : union                (elements that are both in A or B)
# ∩ : intersection         (elements incommon)
# - : difference           (elements that are members of A but not members of B)
# ^ : symmetric difference (only in A or only in B but not both)

use strictures 1;
use v5.14;
use List::MoreUtils qw|uniq|;

sub set_theory
{
    my @array1 = @{+shift};
    my $op     = shift;
    my @array2 = @{+shift};

    @array1 = uniq @array1; @array2 = uniq @array2;

    my (@union, @intersection, @difference, %count);
    @union = @intersection = @difference = ();
    %count = ();
    foreach my $element (@array1, @array2) { $count{$element}++ }
    foreach my $element (keys %count)
    {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
    }

    # union
    # $A = (0 .. 4);  $B = (5 ..  9); $C = $A U $B => $C = (0 .. 9)
    #
    return sort @union if $op eq '∪';

    # incommon, intersection
    # $A = (1, 2, 3); $B = (3, 4, 5); $C = $A & $B => $C = (3)
    #
    return sort @intersection if $op eq '∩';

    # difference, the elements which $B doesn't have but are found in $A
    # or (i.e) the elements $A which are not found in $B
    # $A = (1, 2, 3); $B = (2, 3);    $C = $A - $B => $C = (1)
    #
    return grep { ! ($_ ~~ @array2) } @array1 if $op eq '-';

    # only in A or only in B but not both
    # $A = (1, 2, 3); $B = (3, 4, 5); $C = $A ^ $B => $C = (1, 2, 4, 5)
    return sort @difference if $op eq '^';
}

1;
