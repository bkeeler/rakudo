=head1 NAME

past-compiler-regex.pir - Compiler for the PAST::Regex interpolator type

=head1 DESCRIPTION

Implements the interpolator pasttype of PAST::Regex node.  This has to be in Rakudo rather than
NQP-RX as it calls the Rakudo regex compiler.

Scalar values are interpolated as literal strings or regexes, depending on the subtype.  Array values
(or any Iterable) are interpolated as ||-type alternations.

Subtype can be any of:

=over 4

=item zerowidth

Only test for truthiness and fail or not.  No interpolation.

=item compile_regex

String values should be compiled into regexes and then interpolated.

=item literal

String values should be treated as literals.

=item literal_i

String values should be treated as literals and matched case-insensitively.

=back

=head2 Methods

=over 4

=item interpolator(PAST::Regex node)

=cut

.HLL 'parrot'

.namespace ['PAST';'Compiler']

.const int CURSOR_FAIL = -1

.sub 'interpolator' :method :multi(_, ['PAST'; 'Regex'])
    .param pmc node
    .local pmc cur, pos, fail, ops, eos, off, tgt
    (cur, pos, eos, off, tgt, fail) = self.'!rxregs'('cur pos eos off tgt fail')
    ops = self.'post_new'('Ops', 'node'=>node, 'result'=>cur)
 
    .local pmc zerowidth, negate, testop, subtype
    subtype = node.'subtype'()

    ops.'push_pirop'('inline', subtype, 'inline'=>'  # rx interp subtype=%1')
    .local pmc cpast, cpost
    cpast = node[0]
    cpost = self.'as_post'(cpast, 'rtype'=>'P')
 
    self.'!cursorop'(ops, '!cursor_pos', 0, pos)
    ops.'push'(cpost)

    # If this is just a zerowidth assertion, we don't actually interpolate anything.  Just evaluate
    # and fail or not. 
    if subtype == 'zerowidth' goto zerowidth_test

    .local string prefix
    prefix = self.'unique'('rxinterp_')
    .local pmc precompiled_label, done_label, loop_label, not_a_list_label, iterator_reg, label_reg
    $S0 =  concat prefix, '_precompiled'
    precompiled_label = self.'post_new'('Label', 'result'=>$S0)
    $S0 =  concat prefix, '_done'
    done_label = self.'post_new'('Label', 'result'=>$S0)
    $S0 =  concat prefix, '_loop'
    loop_label = self.'post_new'('Label', 'result'=>$S0)
    $S0 =  concat prefix, '_not_a_list'
    not_a_list_label = self.'post_new'('Label', 'result'=>$S0)
    iterator_reg = self.'uniquereg'("P")
    label_reg = self.'uniquereg'("I")

    ops.'push_pirop'('descalarref', '$P10', cpost)
    ops.'push_pirop'('get_hll_global', '$P11', "'Iterable'")
    ops.'push_pirop'('callmethod', "'isa'", '$P10', '$P11', 'result'=>'$P11')
    ops.'push_pirop'('unless', '$P11', not_a_list_label)

    ops.'push_pirop'('callmethod', "'iterator'", '$P10', 'result'=>iterator_reg)
    ops.'push_pirop'('set_addr', label_reg, loop_label)
    ops.'push'(loop_label)
    ops.'push_pirop'('callmethod', "'get'", iterator_reg, 'result'=>'$P10')
    ops.'push_pirop'('isa', '$I10', '$P10', "['EMPTY']")
    ops.'push_pirop'('if', '$I10', fail)
    self.'!cursorop'(ops, '!mark_push', 0, 0, pos, label_reg)

    ops.'push'(not_a_list_label)
    # Check if it isa Regex, and call it as a method if so
    ops.'push_pirop'('isa', '$I10', '$P10', "['Regex']")
    ops.'push_pirop'('if', '$I10', precompiled_label)
    ops.'push_pirop'('set', '$S10', '$P10')
    ne subtype, 'compile_regex', literal

    # Kinda cheesy, but the compiler can't be entered anywhere but TOP for now
    ops.'push_pirop'('split', '$P9', "'/'", '$S10')
    ops.'push_pirop'('join', '$S10', "'\\/'", '$P9')
    ops.'push_pirop'('concat', '$S10', "'rx/'", '$S10')
    ops.'push_pirop'('concat', '$S10', '$S10', "'/'")
    ops.'push_pirop'('compreg', '$P10', '"perl6"')
    ops.'push_pirop'('getinterp', '$P9')
    ops.'push_pirop'('set', '$P9', "$P9['context';0]")
    ops.'push_pirop'('callmethod', '"compile"', '$P10', '$S10', "'outer_ctx'=>$P9", 'result'=>'$P10')
    ops.'push_pirop'('set', '$P8', '$P10[0]')
    ops.'push_pirop'('getattribute', '$P9', '$P9', '"current_sub"')
    ops.'push_pirop'('callmethod', '"set_outer"', '$P8', '$P9')
    ops.'push_pirop'('call', '$P10', 'result'=>'$P10')

    goto have_compiled_regex

  literal:
    ops.'push_pirop'('length', '$I10', '$S10')
    ops.'push_pirop'('add', '$I11', pos, '$I10')
    ops.'push_pirop'('gt', '$I11', eos, fail)
    ops.'push_pirop'('sub', '$I11', pos, off)
    ops.'push_pirop'('substr', '$S11', tgt, '$I11', '$I10')
    ne subtype, 'literal_i', dont_downcase
    ops.'push_pirop'('downcase', '$S10', '$S10')
    ops.'push_pirop'('downcase', '$S11', '$S11')
  dont_downcase:
    ops.'push_pirop'('ne', '$S11', '$S10', fail)
    ops.'push_pirop'('add', pos, '$I10')
    ops.'push_pirop'('goto', done_label)

  have_compiled_regex:
    ops.'push'(precompiled_label)
    ops.'push_pirop'('callmethod', '$P10', cur, 'result'=>'$P10')
    ops.'push_pirop'('unless', '$P10', fail)
    self.'!cursorop'(ops, '!mark_push', 0, 0, CURSOR_FAIL, 0, '$P10')
    ops.'push_pirop'('callmethod', '"pos"', '$P10', 'result'=>pos)
    
    ops.'push'(done_label)

    goto done

  zerowidth_test:
    negate = node.'negate'()
    testop = self.'??!!'(negate, 'if', 'unless')
    ops.'push_pirop'(testop, cpost, fail)
  done:
    .return (ops)


.end
