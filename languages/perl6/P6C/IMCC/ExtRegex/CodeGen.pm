package P6C::IMCC::ExtRegex::CodeGen;
use base 'Regex::CodeGen::IMCC';
use P6C::IMCC qw(gentmp code newtmp array_in_context tuple_in_context);
use strict;

=head1 NAME

P6C::IMCC::ExtRegex::CodeGen

=head1 SUMMARY

Subclass of Regex::CodeGen (found in languages/regex/lib) for
generating code that requires Perl6-specific functionality.

Regex::CodeGen calls methods named C<output_X> for every C<X>
generated by the rewriting phase (see
L<P6C::IMCC::ExtRegex::Rewrite>). Each method must return an array of
PIR statements implementing the "operation" C<X>.

=head1 METHODS

=over 4

=cut

sub output_code {
    my ($self, $tree_list, $ctx, $lastback) = @_;
    return sub { map { $_->val } @$tree_list; };
}

=item output_string

Convert $atom to a string and store it in $dest.

=cut

sub output_string {
    my ($self, $dest, $atom) = @_;
    my $atom_val = ref($atom) ? $atom->val : $atom;
    return ("set $dest, $atom_val");
}

=item output_array_elt

Retrieve element $index of the aggregate $array and store it into $dest.

=cut

#    return new P6C::subscript_exp thing => $thing, subscripts => [@subsc];
sub output_array_elt {
    my ($self, $dest, $array, $index, $ctx) = @_;
    return ("set $dest, $array\[$index]");
}

=item output_array_length

Compute the length of $array and store it into $dest.

=cut

sub output_array_length {
    my ($self, $dest, $array) = @_;
    return $self->output_assign($dest, $array);
}

=item output_call_rule

Generate code for calling a subrule $rule_call within a regex tree
($rule_call is of type P6C::rx_call; see L<P6C::Nodes>), passing $args
as the arguments and getting back $results.

 $args : [ <name, type, val> ]
 $results : [ <type, val> ]

=cut

sub output_call_rule {
    my ($self, $rule_call, $args, $results, $context) = @_;
    my $ctx = $self->{ctx};
#    $DB::single =1 ;

    die unless $rule_call->args->isa('P6C::ValueList');

    # Create an array of the actual values to be passed into the
    # called rule
    my @actual_vals;
    my $i = 0;
    foreach (@$args) {
        my ($name, $type, $val) = @$_;
        $val = $ctx->{$1} if $val =~ /^ \< (.*) \> $/x;
        my $literal = $rule_call->args->vals->[$i++];
        push @actual_vals, ref($literal)->new;
        while (my ($k, $v) = each %$literal) {
            $actual_vals[-1]->{$k} = $v;
        }
        $actual_vals[-1]->lval($val);
    }

    # Convert results to a simple array of variable names
    my $want_results = [ map { $_->[1] } @$results ];
    foreach (@$want_results) {
        s/^ \< (.*) \> $/$ctx->{$1}/sx;
    }

    # There must be a better way of detecting whether the called rule
    # is prototyped or not. This is miserably broken.
#     if (ref($rule_call->name)) {
#         # The name is not a simple string, so no prototype.
#         return sub {
#             # Fill in the values of the actual parameters (arguments)
#             foreach (@{ $rule_call->args->vals }) {
#                 last if (@actual_vals == 0);
#                 $_->val(shift(@actual_vals)->lval);
#             }

#             my $AV = array_in_context($rule_call->args->vals->[-1],
#                                       new P6C::Context type => 'PerlArray');
#             $rule_call->args->vals->[-1] = $AV;
#             call_rule_closure($rule_call, $rule_call->args, $want_results);
#         }
#     } else {
        # Postpone actually generating the call until this op is emitted.
        # We also must postpone assigning the actual arguments, because
        # otherwise they'll be overridden by other calls of the same rule.
        return sub {
            # Fill in the values of the arguments
            foreach (@{ $rule_call->args->vals }) {
                last if (@actual_vals == 0);
                $_->val(shift(@actual_vals)->lval);
            }

            call_rule_named($rule_call, $want_results);
        };
#     }
}

=item call_rule_closure

Helper function for output_call_rule when calling a closure.

=cut

sub call_rule_closure {
    my ($thing, $args, $want_results) = @_;
    code("\t# call_rule_closure");
    my $func = $thing->name->val;

    my $argvals = $args->val;
    code("\t.arg $_")
        foreach (reverse @$argvals);
    code("\tinvoke $func");
    code("\t.result $want_results->[$_]")
        for (reverse 0..$#$want_results);
}

=item call_rule_closure

Helper function for output_call_rule when calling a named function.

=cut

sub call_rule_named {
    my ($rule_call, $want_results) = @_;
    code("\t# call_rule_named");
#    $DB::single = 1;
    my @results = P6C::IMCC::prefix::gen_sub_call($rule_call, is_rule => 1);
    code("\tset $want_results->[$_], $results[$_]")
      for (reverse 0..$#results);
    code("\t# call_rule_named end");
}

1;

=back
