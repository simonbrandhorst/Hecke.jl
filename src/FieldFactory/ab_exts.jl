add_verbose_scope(:AbExt)
add_assert_scope(:AbExt)

add_verbose_scope(:MaxAbExt)


export abelian_fields, abelian_normal_extensions, abelian_extensions

###############################################################################
#
#  Abelian extensions
#
###############################################################################

function abelian_fields(O::Union{FlintIntegerRing, FlintRationalField},
                            gtype::Vector{Int}, discriminant_bound::fmpz;
                            only_real::Bool = false,
                            tame::Bool = false)

  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K, _ = NumberField(x - 1, "a", cached = false)
  OK = maximal_order(K)
  l = abelian_fields(OK, gtype, discriminant_bound,
                         only_real = only_real,
                         tame = tame)
  return l
end

function abelian_fields(O::NfOrd, gtype::Vector{Int}, absolute_discriminant_bound::fmpz; only_real::Bool = false, only_complex::Bool = false, tame::Bool = false)
  K = nf(O) 
  @assert degree(K)==1
  gtype = map(Int, snf(abelian_group(gtype))[1].snf)
  n = prod(gtype)
  real = only_real
    
  expo = lcm(gtype)
    
  #Getting conductors
  l_conductors = conductorsQQ(O, gtype, absolute_discriminant_bound, tame)
  @vprint :AbExt 1 "Number of conductors: $(length(l_conductors)) \n"
  fields = ClassField{MapRayClassGrp, GrpAbFinGenMap}[]

  #Now, the big loop
  for (i, k) in enumerate(l_conductors)
    @vprint :AbExt 1 "Conductor: $k \n"
    @vprint :AbExt 1 "Left: $(length(l_conductors) - i)\n"
    r, mr = Hecke.ray_class_groupQQ(O, k, !real, expo)
    if !has_quotient(r, gtype)
      continue
    end
    ls = subgroups(r,quotype = gtype, fun = (x, y) -> quo(x, y, false)[2])
    for s in ls
      C = ray_class_field(mr, s)
      if Hecke._is_conductor_minQQ(C,n) && Hecke.discriminant_conductorQQ(O,C,k,absolute_discriminant_bound)
        if only_complex
          rC, sC = signature(C)
          if !iszero(rC)
            continue
          end
        end
        @vprint :AbExt 1 "New Field \n"
        push!(fields, C)
      end
    end
  end
  return fields
end


function abelian_normal_extensions(K::AnticNumberField, gtype::Vector{Int}, absolute_discriminant_bound::fmpz; only_real::Bool = false, only_complex::Bool = false, tame::Bool = false, absolute_galois_group::Tuple{Int, Int} = (0, 0))
  
  @assert !(only_real && only_complex)
  O = maximal_order(K)
  d = degree(O)
  if d == 1
    return abelian_fields(O, gtype, absolute_discriminant_bound, only_real = only_real, tame = tame) 
  end
  gtype = map(Int, snf(abelian_group(gtype))[1].snf)
  n = prod(gtype)
  inf_plc = InfPlc[]
  
  fields = ClassField{MapRayClassGrp, GrpAbFinGenMap}[]
  bound = div(absolute_discriminant_bound, abs(discriminant(O))^n)

  if bound == 0
    return fields
  end

  if iseven(n) && !only_real
    inf_plc = real_places(K)
  end
  
  Aut=Hecke.automorphisms(K)
  @assert length(Aut)==degree(O) #The field is normal over Q
  gens = Hecke.small_generating_set(Aut)

  expo = lcm(gtype)
  C, mC = class_group(O)
  cgrp = !iscoprime(n, order(C))
  allow_cache!(mC)

  #Getting conductors
  l_conductors = conductors(O, gtype, bound, tame)
  @vprint :AbExt 1 "Number of conductors: $(length(l_conductors)) \n"
  
  ctx = rayclassgrp_ctx(O, expo)
  #Now, the big loop
  for (i, k) in enumerate(l_conductors)
    @vprint :AbExt 1 "Conductor: $k \n"
    @vprint :AbExt 1 "Left: $(length(l_conductors) - i)\n"
    r, mr = ray_class_group_quo(O, k[1], k[2], inf_plc, ctx)
    if !has_quotient(r, gtype)
      continue
    end
    act = induce_action(mr,gens)
    ls = stable_subgroups(r, act, op=(x, y) -> quo(x, y, false)[2], quotype = gtype)
    for s in ls
      @hassert :AbExt 1 order(codomain(s))==n
      C = ray_class_field(mr, s)
      if Hecke._is_conductor_min_normal(C) && Hecke.discriminant_conductor(C, bound)
        if only_complex
          rC, sC = signature(C)
          if iszero(rC)
            continue
          end
        end
        @vprint :AbExt 1 "New Field \n"
        if absolute_galois_group != (0, 0)
          autabs = absolute_automorphism_group(C, gens)
          G = generic_group(autabs, *)
          id_G = find_small_group(G)
          if id_G == absolute_galois_group
            push!(fields, C)
          end
        else
          push!(fields, C)
        end
      end
    end
  end
  return fields
end

################################################################################
#
#  Abelian extensions of arbitrary fields
#
################################################################################

function abelian_extensions(K::AnticNumberField, gtype::Vector{Int}, absolute_discriminant_bound::fmpz; ramified_at_inf_plc::Tuple{Bool, Vector{InfPlc}} = (false, InfPlc[]), only_tame::Bool = false)

  OK = maximal_order(K)
  gtype = map(Int, snf(abelian_group(gtype))[1].snf)
  n = prod(gtype)
  inf_plc = InfPlc[]
  
  fields = ClassField{MapRayClassGrp, GrpAbFinGenMap}[]
  bound = div(absolute_discriminant_bound, abs(discriminant(OK))^n)
  if iszero(bound)
    return fields
  end

  inf_plc = real_places(K)
  if ramified_at_inf_plc[1]
    inf_plc = ramified_at_inf_plc[2]
  end
  expo = gtype[end]
  C, mC = class_group(OK)
  cgrp = !iscoprime(n, order(C))
  allow_cache!(mC)

  #Getting conductors
  l_conductors = conductors_generic(K, gtype, absolute_discriminant_bound, only_tame = only_tame)
  @vprint :AbExt 1 "Number of conductors: $(length(l_conductors)) \n"
  
  ctx = rayclassgrp_ctx(OK, expo)
  #Now, the big loop
  for (i, k) in enumerate(l_conductors)
    @vprint :AbExt 1 "Left: $(length(l_conductors) - i)\n"
    r, mr = ray_class_group_quo(OK, k, inf_plc, ctx)
    if !has_quotient(r, gtype)
      continue
    end
    ls = subgroups(r, quotype = gtype, fun = (x, y) -> quo(x, y, false)[2])
    for s in ls
      @hassert :AbExt 1 order(codomain(s))==n
      C = ray_class_field(mr, s)
      cC = conductor(C)
      if ramified_at_inf_plc[1]
        if Set(cC[2]) != Set(ramified_at_inf_plc[2])
          continue
        end
      end
      if cC[1] == mr.defining_modulus[1] && norm(discriminant(C)) <= bound
        @vprint :AbExt 1 "New Field \n"
        push!(fields, C)
      end
    end
  end
  return fields
end


################################################################################
#
#  Valuation bounds for discriminants
#
################################################################################

function valuation_bound_discriminant(n::Int, p::Union{Integer, fmpz})
  # First compute the p-adic expansion of n
  S = Vector{typeof(p)}()
	q = typeof(p)(n)
  q, r = divrem(q, p)
  push!(S, r)
  while q >= p
    q, r = divrem(q, p)
    push!(S, r)
  end

	if !iszero(q)
		push!(S, q)
	end

	@assert sum(S[i + 1] * p^i for i in 0:length(S)-1) == n

	b = zero(typeof(p))

	for i in 0:length(S) - 1
		b = b + S[i + 1] * (i + 1) * p^i
		if !iszero(S[i + 1])
			b = b - 1
		end
	end

  return b
end                                                         
                                                                               
###########################################################################
#
#  Some useful functions
#
###########################################################################

#This function gets a quotient of the ray class group and the action on
# the ray class group
# In output, we get the quotient group as a ZpnGModule

function _action_on_quo(mq::GrpAbFinGenMap, act::Array{GrpAbFinGenMap,1})
  
  q=mq.header.codomain
  S,mS=snf(q)
  n=Int(S.snf[end])
  R=ResidueField(FlintZZ, n, cached=false)
  quo_action=Array{nmod_mat,1}(undef, length(act))
  for s=1:length(act)
    quo_action[s]= change_base_ring(mS.map*act[i].map*mS.imap, R)
  end
  return ZpnGModule(S, quo_action)

end

###############################################################################
#
#  Quadratic Extensions of Q
#
###############################################################################

function quadratic_fields(bound::Int; tame::Bool=false, real::Bool=false, complex::Bool=false, with_autos::Type{Val{T}}=Val{false}) where T

  @assert !(real && complex)
  Qx,x=PolynomialRing(FlintQQ, "x")
  sqf=squarefree_up_to(bound)
  if real
    deleteat!(sqf,1)
  elseif complex
    sqf=Int[-i for i in sqf]
  else
    sqf= vcat(sqf[2:end], Int[-i for i in sqf])
  end
  if tame
    filter!( x -> mod(x,4)==1, sqf)
    return ( number_field(x^2-x+divexact(1-i,4), cached=false, check = false)[1] for i in sqf)
  end
  final_list=Int[]
  for i=1:length(sqf)
    if abs(sqf[i]*4)< bound
      @views push!(final_list,sqf[i])
      continue
    end
    if mod(sqf[i],4)==1
      @views push!(final_list,sqf[i])
    end
  end
  return ( mod(i,4)!=1 ? number_field(x^2-i, cached=false, check = false)[1] : number_field(x^2-x+divexact(1-i,4), cached = false, check = false)[1] for i in final_list)

end

function _quad_ext(bound::Int, only_real::Bool = false)
  
  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K = NumberField(x-1, cached = false, check = false)[1]
  sqf = squarefree_up_to(bound)
  final_list = Int[]
  for i=2:length(sqf)
    if abs(sqf[i]*4)< bound
      @views push!(final_list, sqf[i])
      continue
    end
    if mod(sqf[i], 4) == 1
      @views push!(final_list, sqf[i])
    end
  end
  if !only_real
    for i = 1:length(sqf)
      if abs(sqf[i]*4)< bound
        @views push!(final_list, -sqf[i])
        continue
      end
      if mod(sqf[i], 4) == 3
        @views push!(final_list, -sqf[i])
      end
    end
  end
  fields_list = Array{Tuple{AnticNumberField, Vector{NfToNfMor}, Vector{NfToNfMor}}, 1}(undef, length(final_list))
  for i = 1:length(final_list)
    if mod(final_list[i],4) != 1
      cp = Vector{fmpz}(undef, 3)
      cp[1] = -final_list[i]
      cp[2] = 0
      cp[3] = 1
      L, gL = number_field(Qx(cp), cached=false, check = false)
      auts = NfToNfMor[hom(L, L, -gL, check = false)]
      emb = NfToNfMor[hom(K, L, one(L), check = false)]
      fields_list[i] = (L, auts, emb)
    else
      cp = Vector{fmpz}(undef, 3)
      cp[1] = divexact(1-final_list[i], 4)
      cp[2] = -1
      cp[3] = 1
      L, gL = number_field(Qx(cp), cached=false, check = false)
      auts = NfToNfMor[hom(L, L, 1-gL, check = false)]
      emb = NfToNfMor[hom(K, L, one(L), check = false)]
      fields_list[i] = (L, auts, emb)
    end
  end
  return fields_list

end

###############################################################################
#
#  C2 x C2 extensions of Q
#
###############################################################################

function C22_extensions(bound::Int)
  
  
  Qx, x=PolynomialRing(FlintZZ, "x")
  K, _=NumberField(x-1, cached = false)
  Kx,x=PolynomialRing(K,"x", cached=false)
  b1=ceil(Int,Base.sqrt(bound))
  n=2*b1+1
  pairs = _find_pairs(bound)
  return (_ext(Kx,x,i,j) for (i, j) in pairs)
  
end

function _ext(Ox,x,i,j)
 
  y=mod(i,4)
  pol1 = x^2
  if y != 1
    pol1 = x^2-i
  else
    pol1 = x^2-x+divexact(1-i,4)
  end
  y=mod(j,4)
  pol2=Ox(1)
  if y!=1
    pol2=x^2-j
  else
    pol2=x^2-x+divexact(1-j,4)
  end
  return number_field([pol1,pol2], cached = false, check = false)

end


function _C22_exts_abexts(bound::Int, only_real::Bool = false)
  Qx, x = PolynomialRing(FlintZZ, "x")
  pairs = _find_pairs(bound, only_real)
  return (_ext_with_autos(Qx, x, i, j) for (i, j) in pairs)
end

function _ext_with_autos(Qx, x, i::Int, j::Int)
  first = i
  second = j
  g = gcd(i, j)
  if g != 1
    third = divexact(i*j, g^2)
    if gcd(first, third) == 1
      second = third
    elseif gcd(second, third) == 1
      first = third
    end
  end
  y1 = mod(first, 4)
  cp1 = Vector{fmpz}(undef, 3)
  cp1[3] = fmpz(1)
  if y1 != 1
    cp1[1] = fmpz(-first)
    cp1[2] = fmpz(0)
  else
    cp1[1] = fmpz(divexact(1-first,4))
    cp1[2] = fmpz(-1)
  end
  y2 = mod(second, 4)
  cp2 = Vector{fmpz}(undef, 3)
  cp2[3] = fmpz(1)
  if y2 != 1
    cp2[1] = fmpz(-second)
    cp2[2] = fmpz(0)
  else
    cp2[1] = fmpz(divexact(1-second, 4))
    cp2[2] = fmpz(-1)
  end
  return Qx(cp1), Qx(cp2)
end

function __get_term(a::fmpq_mpoly, exps::Vector{UInt})
   z = fmpq()
   ccall((:fmpq_mpoly_get_coeff_fmpq_ui, libflint), Nothing,
         (Ref{fmpq}, Ref{fmpq_mpoly}, Ptr{UInt}, Ref{FmpqMPolyRing}),
         z, a, exps, parent(a))
   return z
end

function _C22_with_max_ord(l)
  list = Vector{Tuple{AnticNumberField, Vector{NfToNfMor}, Vector{NfToNfMor}}}()
  Qx, x = PolynomialRing(FlintQQ, "x", cached = false)
  K = NumberField(x-1, cached = false)[1]
  for (p1, p2) in l
    Kns, g = number_field(fmpz_poly[p1, p2], check = false, cached = false)
    S, mS = simple_extension(Kns, check = false, cached = false, simplified = true)
    Hecke._assure_has_inverse_data(mS)
    gen1 = mS\(g[1])
    gen2 = mS\(g[2])
    d1 = discriminant(p1)
    d2 = discriminant(p2)
    cf = gcd(d1, d2)
    if isone(cf)
      B = Vector{nf_elem}(undef, 4)
      B[1] = S(1)
      B[2] = mS\(g[1])
      B[3] = mS\(g[2])
      B[4] = B[2] * B[3]
      M = basis_matrix(B, FakeFmpqMat)
      hnf_modular_eldiv!(M.num, M.den, :lowerleft)
      O = NfAbsOrd(S, FakeFmpqMat(M.num, M.den))
      O.disc = d1^2*d2^2
      d3 = numerator(discriminant(S))
      if d3 < 0 
        O.disc = -O.disc
      end
      O.index = divexact(d3, O.disc)
      O.ismaximal = 1
      Hecke._set_maximal_order_of_nf(S, O) 
    else
      maximal_order(S)
    end
    auts = small_generating_set(automorphisms(S, isabelian = true, copy = false))
    push!(list, (S, auts, NfToNfMor[hom(K, S, S(1), check = false)]))
  end
  return list
end

function _disc(a::Int, b::Int, c::Int, bound::Int)
  a1 = mod(a, 4)
  b1 = mod(b, 4)
  if a1 == 1 && b1 == 1
    return a*b*c <= bound
  end
  c1 = mod(c, 4)
  if a1 == 1 || b1 == 1 || c1 == 1
    return 16*a*b*c <= bound
  else
    return 64*a*b*c <= bound
  end
end

function _pairs_totally_real(pairs, ls, bound)
  b1=floor(Int, Base.sqrt(bound))
  pairs[1, 1:length(ls)] .= false
  pairs[1:length(ls), 1] .= false
  for j = 2:length(ls)
    for i = j:length(ls)
      pairs[i, j] = false
    end
  end
  for j = 2:length(ls)
    second = ls[j]
    for i = 2:j-1
      if pairs[i, j]
        first = ls[i]
        g = gcd(first, second)
        if isone(g)
          third = first*second
        else
          third = divexact(first*second, g^2)
        end
        if abs(third) > b1
          pairs[i, j] = false
          continue
        end
        k = searchsortedfirst(ls, third)
        if i < k
          pairs[i, k] = false
        else
          pairs[k, i] = false
        end
        if j < k
          pairs[j, k] = false
        else
          pairs[k, j] = false
        end
        if !_disc(first, second, third, bound)
          pairs[i, j] = false
        end
      end
    end
  end
  it = findall(pairs)
  totally_real_exts = Vector{Tuple{Int, Int}}(undef, length(it))
  ind = 1
  for I in it
    totally_real_exts[ind] = (ls[I[1]], ls[I[2]])
    ind += 1
  end
  return totally_real_exts

end


function _find_pairs(bound::Int, only_real::Bool = false)

  #first, we need the squarefree numbers
  b1=ceil(Int, Base.sqrt(bound))
  ls = squarefree_up_to(b1)
  #The first step is to enumerate all the totally real extensions.
  pairs = trues(length(ls), length(ls))
  real_exts = _pairs_totally_real(pairs, ls, bound)
  if only_real
    return real_exts
  end
  ls1 = -ls
  #Now, all the others.
  pairs[1:length(ls), 2:length(ls)] .= true
  for j = 2:length(ls)
    second = ls[j]
    for i = 1:length(ls)
      if pairs[i, j]
        first = ls1[i]
        g = gcd(first, second)
        if isone(g)
          third = first*second
        else
          third = divexact(first*second, g^2)
        end
        abt = -third
        if abt > b1
          pairs[i, j] = false
          continue
        end
        k = searchsortedfirst(ls, abt)
        pairs[k, j] = false
        if !_disc(first, second, third, bound)
          pairs[i, j] = false
        end
      end
    end
  end
  it = findall(pairs)
  ind = 1
  res = Vector{Tuple{Int, Int}}(undef, length(it))
  for I in it
    res[ind] = (ls1[I[1]], ls[I[2]])
    ind += 1
  end 
  return vcat(res, real_exts)
end



function _from_relative_to_abs(L::NfRelNS{T}, auts::Vector{<: NumFieldMor{NfRelNS{T}, NfRelNS{T}}}) where T

  S, mS = simple_extension(L)
  K, mK, mK2 = absolute_field(S, cached = false)
  #First, we compute the maximal order of the absolute field.
  #Since the computation of the relative maximal order is slow, I bring to the absolute field the elements
  # generating the equation order.
  @vprint :AbExt 2 "Computing the maximal order\n"
  #First, I construct the product basis of the relative extension
  pols = L.pol
  gL = gens(L)
  B = Array{nf_elem, 1}(undef, degree(K))
  B[1] = K(1)
  ind = total_degree(pols[1])
  genjj = mK\(mS\gL[1])
  for i = 2:ind
    B[i] = genjj*B[i-1]
  end
  for jj = 2:length(pols)
    genjj = mK\(mS\gL[jj])
    el = genjj
    new_deg = total_degree(pols[jj])
    for i = 2:new_deg
      for j = 1:ind
        B[(i-1)* ind + j] = B[j]* el 
      end
      mul!(el, el, genjj)
    end
    ind *= new_deg
  end

  #Now, I add the elements of the maximal order
  if degree(base_field(L)) > 1
    O = maximal_order(S.base_ring)
    for i = 1:degree(O)
      el = mK\(S(O.basis_nf[i]))
      for j = 1:ind
        B[(i-1)* ind + j] = B[j] * el 
      end
    end
  end
  #Now, we compute the maximal order. Then we simplify.
  PO = Order(K, B, check = false, cached = false, isbasis = true)
  @vtime :AbExt 2 O1 = MaximalOrder(PO)
  O1.ismaximal = 1
  _set_maximal_order_of_nf(K, O1)
  @vprint :AbExt 2 "Done. Now simplify and translate information\n"
  @vtime :AbExt 2 Ks, mKs = simplify(K, cached = false)
  #Now, we have to construct the maximal order of this field.
  #I am computing the preimages of mKs by hand, by inverting the matrix.


  #Now, the automorphisms.
  autos=Array{NfToNfMor, 1}(undef, length(auts))
  el=mS(mK((mKs(gen(Ks)))))
  for i=1:length(auts)
    y = mKs\(mK\(mS\(auts[i](el))))
    autos[i] = hom(Ks, Ks, y, check = false)
  end
  _set_automorphisms_nf(Ks, closure(autos, degree(Ks)))
  
  @vprint :AbExt 2 "Finished\n"
  return Ks, autos
end 


#######################################################################################
#
#  relative discriminant for abelian extension function
#
#######################################################################################

function discriminant_conductor(C::ClassField, bound::fmpz; lwp::Dict{Tuple{Int, Int}, Array{GrpAbFinGenElem, 1}} = Dict{Tuple{Int, Int}, Array{GrpAbFinGenElem, 1}}())
  
  mr = C.rayclassgroupmap 
  O = base_ring(C)
  n = degree(C)
  e = Int(exponent(C))
  lp = mr.fact_mod
  abs_disc = factor(discriminant(O)^n).fac
  if isempty(lp)
    C.absolute_discriminant=abs_disc
    return true
  end
  K = nf(O)
  d = degree(K)
  discr = fmpz(1)
  mp = pseudo_inv(C.quotientmap) * mr
  R = domain(mp)
  a = minimum(defining_modulus(mr)[1])
  primes_done = fmpz[]
  if isprime(n)
    for (p, v) in lp
      if minimum(p, copy = false) in primes_done
        continue
      end
      push!(primes_done, minimum(p, copy = false))
      ap = n*v-v
      qw = divexact(d, p.splitting_type[1])*ap
      mul!(discr, discr, fmpz(p.minimum)^qw)
      if discr > bound
        @vprint :AbExt 2 "too large\n"
        return false
      else
        if haskey(abs_disc, p.minimum)
          abs_disc[p.minimum] += qw
        else 
          abs_disc[p.minimum] = qw
        end
      end
    end
    return true
  end
  
  powers = mr.powers
  groups_and_maps = mr.groups_and_maps
  
  for i = 1:length(powers)
    p, q = powers[i]
    if p.minimum in primes_done
      continue
    end
    push!(primes_done, p.minimum)
    if p == q
      ap = n
      tmg = groups_and_maps[i][2].tame[p]
      el = C.quotientmap(tmg.disc_log)
      Q, mQ = quo(R, GrpAbFinGenElem[el], false)
      ap -= order(Q)
      qw = divexact(d, p.splitting_type[1])*ap
      mul!(discr, discr, fmpz(p.minimum)^qw)
      if discr > bound
        @vprint :AbExt 2 "too large\n"
        return false
      else
        if haskey(abs_disc, p.minimum)
          abs_disc[p.minimum] += qw
        else 
          abs_disc[p.minimum] = qw
        end
      end
      continue
    end
    np = p.minimum^divexact(d, p.splitting_type[1])
    ap = n*lp[p]
    s = lp[p]
    @hassert :AbExt 1 s>=2
    els=GrpAbFinGenElem[]
    for k=2:lp[p]      
      s = s-1
      pk = p^s
      pv = pk*p
      if haskey(lwp, (Int(p.minimum), s+1))
        gens = lwp[(Int(p.minimum), s+1)]
      else
        gens_els = _1pluspk_1pluspk1(K, p, pk, pv, powers, a, e)
        gens = Vector{GrpAbFinGenElem}(undef, length(gens_els))
        for i = 1:length(gens)
          gens[i] = mr\(ideal(O, gens_els[i]))
        end
        lwp[(Int(p.minimum), s+1)] = gens
      end
      for i = 1:length(gens)
        push!(els, C.quotientmap(gens[i]))
      end
      o = order(quo(R, els, false)[1])
      ap -= o
      tentative_ap = ap - (lp[p] - k + 1)*o
      tentative_discr = discr * (np^tentative_ap)
      if tentative_discr > bound
        return false
      end
      @hassert :AbExt 1 ap>0
    end
    if haskey(groups_and_maps[i][2].tame, p)
      v = groups_and_maps[i][2].tame[p]
      push!(els, C.quotientmap(v.disc_log))
    end
    ap -= order(quo(R, els, false)[1])
    @hassert :AbExt 1 ap>0
    np1 = np^ap
    mul!(discr, discr, np1)
    if discr > bound
      @vprint :AbExt 2 "too large\n"
      return false
    else
      if haskey(abs_disc, p.minimum)
        abs_disc[p.minimum] += ap*divexact(d, p.splitting_type[1])
      else 
        abs_disc[p.minimum] = ap*divexact(d, p.splitting_type[1])
      end
    end
  end
  C.absolute_discriminant = abs_disc
  return true

end

#same function but for ray class groups over QQ

function discriminant_conductorQQ(O::NfOrd, C::ClassField, m::Int, bound::fmpz)
  
  n = degree(C)
  discr=fmpz(1)
  mp = pseudo_inv(C.quotientmap) * C.rayclassgroupmap
  G=domain(mp)
  
  cyc_prime= isprime(n)==true
  
  lp=factor(m).fac
  abs_disc=Dict{fmpz,Int}()

  R=ResidueRing(FlintZZ, m, cached=false)

  for (p,v) in lp 
    if v==1
      ap=n
      if cyc_prime
        ap-=1
      else
        x=_unit_grp_residue_field_mod_n(Int(p),n)[1]
        s=divexact(m,Int(p))
        d,a,b=gcdx(s, Int(p))
        l=Int((R(x)*a*s+b*Int(p)).data)
        el=mp\ideal(O,l)
        q,mq=quo(G, GrpAbFinGenElem[el], false)
        ap-= order(q)
      end
      discr*=p^ap
      if discr>bound
        @vprint :AbExt 2 "too large\n"
        return false
      else
        abs_disc[p]=ap
      end
    else
      ap=n*v
      pow=Int(p)^Int(v)
      el = R(1)
      if cyc_prime
        ap-=v
      else
        if isodd(p)
          s=divexact(m,pow)
          d,a,b=gcdx(pow,s)  
          s1=R(1+p)^(p-1)
          el=G[1]
          if v==2
            el=mp\ideal(O,Int((b*s*R(s1)+a*pow).data))
            ap-=order(quo(G,GrpAbFinGenElem[el], false)[1])
          else
            for k=0:v-2      
              el=mp\ideal(O,Int((b*s*R(s1)^(p^k)+a*pow).data))
              ap-=order(quo(G, GrpAbFinGenElem[el], false)[1])
              @hassert :AbExt 1 ap>0
            end
          end
          if gcd(n,p-1)==1
            ap-=order(quo(G, GrpAbFinGenElem[mp\(ideal(O,fmpz((b*s*R(s1)+a*pow).data)))], false)[1])
          else
            x=_unit_grp_residue_field_mod_n(Int(p),n)[1]
            el1=mp\ideal(O,Int((R(x)*b*s+a*pow).data))
            ap-=order(quo(G, GrpAbFinGenElem[mp\(ideal(O,Int((b*s*R(s1)+a*pow).data))), el1], false)[1])
          end
        else
          s=divexact(m,2^v)
          d,a,b=gcdx(2^v,s)  
          el=0*G[1]
          for k=v-3:-1:0
            el=mp\ideal(O,Int((R(5)^(2^k)*b*s+a*2^v).data))
            ap-=order(quo(G, GrpAbFinGenElem[el], false)[1])
          end
          el1=mp\ideal(O,Int((R(-1)*b*s+a*p^v).data))
          ap-=2*order(quo(G, GrpAbFinGenElem[el, el1], false)[1])
        end
      end
      discr*=p^ap
      if discr>bound
        @vprint :AbExt 2 "too large\n"
        return false
      else
        abs_disc[p]=ap
      end
    end
  end
  C.absolute_discriminant=abs_disc
  return true
end

function discriminantQQ(O::NfOrd, C::ClassField, m::Int)
  
  discr=fmpz(1)
  n = degree(C)
  mp = pseudo_inv(C.quotientmap) * C.rayclassgroupmap
  G = domain(mp)
  
  cyc_prime= isprime(n)==true
  
  lp=factor(m).fac
  abs_disc=Dict{fmpz,Int}()

  R=ResidueRing(FlintZZ, m, cached=false)

  for (p,v) in lp 
    if v==1
      ap=n
      if cyc_prime
        ap-=1
      else
        x=_unit_grp_residue_field_mod_n(Int(p),n)[1]
        s=divexact(m,Int(p))
        d,a,b=gcdx(s, Int(p))
        l=Int((R(x)*a*s+b*Int(p)).data)
        el=mp\ideal(O,l)
        q,mq=quo(G, GrpAbFinGenElem[el], false)
        ap-= order(q)
      end
      discr*=p^ap
      abs_disc[p]=ap
    else
      ap=n*v
      pow=Int(p)^Int(v)
      el = R(1)
      if cyc_prime
        ap-=v
      else
        if isodd(p)
          s=divexact(m,pow)
          d,a,b=gcdx(pow,s)  
          s1=R(1+p)^(p-1)
          el=G[1]
          if v==2
            el=mp\ideal(O,Int((b*s*R(s1)+a*pow).data))
            ap-=order(quo(G,GrpAbFinGenElem[el], false)[1])
          else
            for k=0:v-2      
              el=mp\ideal(O,Int((b*s*R(s1)^(p^k)+a*pow).data))
              ap-=order(quo(G, GrpAbFinGenElem[el], false)[1])
              @hassert :AbExt 1 ap>0
            end
          end
          if gcd(n,p-1)==1
            ap-=order(quo(G, GrpAbFinGenElem[mp\(ideal(O,fmpz((b*s*R(s1)+a*pow).data)))], false)[1])
          else
            x=_unit_grp_residue_field_mod_n(Int(p),n)[1]
            el1=mp\ideal(O,Int((R(x)*b*s+a*pow).data))
            ap-=order(quo(G, GrpAbFinGenElem[mp\(ideal(O,Int((b*s*R(s1)+a*pow).data))), el1], false)[1])
          end
        else
          s=divexact(m,2^v)
          d,a,b=gcdx(2^v,s)  
          el=0*G[1]
          for k=v-3:-1:0
            el=mp\ideal(O,Int((R(5)^(2^k)*b*s+a*2^v).data))
            ap-=order(quo(G, GrpAbFinGenElem[el], false)[1])
          end
          el1=mp\ideal(O,Int((R(-1)*b*s+a*p^v).data))
          ap-=2*order(quo(G, GrpAbFinGenElem[el, el1], false)[1])
        end
      end
      discr*=p^ap
      abs_disc[p]=ap
    end
  end
  C.absolute_discriminant=abs_disc
  return discr
end

###############################################################################
#
#  conductor function for abelian extension function
#
###############################################################################

#  For this function, we assume the base field to be normal over Q and the conductor of the extension we are considering to be invariant
#  Checks if the defining modulus is the conductor of C

function _is_conductor_min_normal(C::Hecke.ClassField; lwp::Dict{Int, Array{GrpAbFinGenElem, 1}} = Dict{Int, Array{GrpAbFinGenElem, 1}}())
  mr = C.rayclassgroupmap
  lp = mr.fact_mod
  if isempty(lp)
    return true
  end
  
  a = minimum(defining_modulus(mr)[1])
  mp = pseudo_inv(C.quotientmap) * mr 
  R = domain(mp)
  e = Int(exponent(C))
  O = base_ring(C)
  K = nf(O)
  lp = mr.fact_mod
  powers = mr.powers
  groups_and_maps = mr.groups_and_maps
  #first, tame part
  primes_done = fmpz[]
  for i = 1:length(powers)
    p, q = powers[i]
    if p.minimum in primes_done 
      continue
    end
    push!(primes_done, p.minimum)
    if p == q
      #The prime is tamely ramified
      v = groups_and_maps[i][2].tame[p]
      el = C.quotientmap(v.disc_log)
      if iszero(el)
        return false
      end
      continue
    end
    if haskey(lwp, Int(p.minimum))
      gens = lwp[Int(p.minimum)]
    else
      k = lp[p]-1
      pk = p^k
      pv = q
      gens_els = _1pluspk_1pluspk1(K, p, pk, pv, powers, a, e)
      gens = Vector{GrpAbFinGenElem}(undef, length(gens_els))
      for i = 1:length(gens)
        gens[i] = mr\(ideal(O, gens_els[i]))
      end
      lwp[Int(p.minimum)] = gens
    end
    iscond = false
    for i in 1:length(gens)
      if !iszero(C.quotientmap(gens[i]))
        iscond = true
        break
      end
    end
    if !iscond
      return false
    end
  end
  return true
end 

#
#  Same function as above, but in the assumption that the map comes from a ray class group over QQ
#

function _is_conductor_minQQ(C::Hecke.ClassField, n::Int)

  mr = C.rayclassgroupmap
  mp = pseudo_inv(C.quotientmap) * mr
  m = defining_modulus(mr)[1]
  mm = Int(minimum(m))
  lp = factor(mm)
  
  O=order(m)
  K=nf(O)
  
  R=ResidueRing(FlintZZ, mm, cached=false)
  for (p,v) in lp.fac
    if isodd(p)
      if v==1
        x=_unit_grp_residue_field_mod_n(Int(p), n)[1]
        s=divexact(mm,Int(p))
        d,a,b=gcdx(s,Int(p))
        l=a*s*R(x)+p*b  
        if iszero(mp\(ideal(O,Int(l.data))))
          return false
        end
      else      
        s=divexact(mm,p^v)
        d,a,b=gcdx(s,p^v)
        x=a*s*R(1+p)^((p-1)*p^(v-2))+p^v*b
        if iszero(mp\(ideal(O,Int(x.data))))
          return false
        end
      end
    else
      if v==1
        return false
      end
      if v==2
        s=divexact(mm,4)
        d,a,b=gcdx(s,4)
        l=a*s*R(-1)+4*b
        if iszero(mp\(ideal(O,Int(l.data))))
          return false
        end
      else
        s=divexact(mm,2^v)
        d,a,b=gcdx(s, 2^v)
        l=a*s*R(5)^(2^(v-3))+2^v*b
        if iszero(mp\(ideal(O,Int(l.data))))
          return false
        end
      end
    end
  end
  return true

end 


#Returns the cyclic extension of prime degree i with minimal discriminant
function minimal_prime_cyclic_extension(i::Int)
  k = 2
  while !isprime(k*i+1)
    k +=1
  end
  K, a = cyclotomic_field(k*i+1)
  auts = small_generating_set(automorphisms(K))
  auts[1] = auts[1]^i
  g = auts[1]
  el = g(a)
  for i = 2:k
    g *= auts[1]
    el += g(a)
  end
  f = minpoly(el)
  L = number_field(f, check = false, cached = false)[1]
  set_special(L, :isabelian => true)
  return simplify(L, cached = false)[1]
end
