=head1 TITLE

Iterator - Perl 6 Iterator (abstract) class

=head1 DESCRIPTION

Iterator is the base class for creating iterators.
(Currently I've defined it as a class; eventually it
may be a role.)  Subclasses are required to override
the .get method; other methods may also be overridden.

Conjecturally, Iterators are also Iterable -- i.e., they
flatten in list context.

=head2 Methods

=over 4

=cut

.namespace ['Iterator']
.sub 'onload' :anon :init :load
    .local pmc p6meta, proto, pos_role
    p6meta = get_hll_global ['Mu'], '$!P6META'
    pos_role = get_hll_global 'Positional'
    pos_role = pos_role.'!select'()
    proto = p6meta.'new_class'('Iterator', 'parent'=>'Iterable', 'does_role'=>pos_role)
.end

=item eager()

Returns a Parcel containing all of the remaining items
in the Iteration.  If the invocant is infinite, then
continue until memory is exhausted.

=cut

.namespace ['Iterator']
.sub 'eager' :method
    .local pmc parcel, true
    parcel = new ['Parcel']
  iter_loop:
    .local pmc item
    item = self.'get'()
    $I0 = isa item, ['EMPTY']
    if $I0 goto iter_done
    push parcel, item
    goto iter_loop
  iter_done:
    .return (parcel)
.end


.namespace ['Iterator']
.sub 'batch' :method
    .param int n
    .local pmc parcel

    parcel = new ['Parcel']
  batch_loop:
    unless n > 0 goto batch_done
    .local pmc item
    item = self.'get'()
    $I0 = isa item, ['EMPTY']
    unless $I0 goto batch_next
    if parcel goto batch_done
    .return (item)
  batch_next:
    push parcel, item
    dec n
    goto batch_loop
  batch_done:
    .return (parcel)
.end


.sub 'iterator' :method
    .return (self)
.end


# TimToady suggests this should be on Cool, but it makes more
# sense to me here.
.sub 'postcircumfix:<[ ]>' :method
    .param pmc args    :slurpy
    .param pmc adverbs :slurpy :named
    $P0 = self.'Seq'()
    .tailcall $P0.'postcircumfix:<[ ]>'(args :flat, adverbs :flat :named)
.end

.namespace ['Iterator']
.sub 'Bool' :method :vtable('get_bool')
    .local pmc item
    item = self.'get'()
    $I0 = isa item, ['EMPTY']
    .tailcall '&prefix:<!>'($I0)
.end

=back

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
