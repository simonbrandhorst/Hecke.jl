################################################################################
#
#  Simplify
#
################################################################################

function simplify(K::NfRel; cached::Bool = true, prec::Int = 100)
  Kabs, mK, mk = absolute_field(K, cached = false)
  OK = maximal_order(K)
  B = lll_basis(OK)
  B1 = _sieve_primitive_elements(B)
  i = 6
  while isempty(B1)
    B1 = _sieve_primitive_elements(B, parameter = i)
    i += 3
  end
  a = B1[1]
  I = t2(a)
  for i = 2:min(50, length(B1))
    J = t2(B1[i])
    if J < I
      a = B1[i]
      I = J
    end
  end
  f = minpoly(a)
  @assert degree(f) == degree(K)
  Ks = number_field(f, cached = cached, check = false)[1]
  mKs = hom(Ks, K, a)
  return Ks, mKs
end

function _sieve_primitive_elements(B::Vector{T}) where T <: NumFieldElem
  K = parent(B[1])
  n = absolute_degree(K)
  B1 = typeof(B)()
  k = div(n, 2)
  for x in B
    c = conjugates_arb(x, 16)
    isprimitive = true
    for i = 2:k+1
      for j = 1:i-1
        if overlaps(c[i], c[j])
          isprimitive = false
          break
        end
      end
      if !isprimitive
        break
      end
    end
    if isprimitive
      push!(B1, x)
    end
  end
  return B1
end


function _is_primitive_via_block(a::NfRelElem{nf_elem}, rt::Dict{fq, Vector{fq}}, Fx, tmp::gfp_fmpz_poly)
  n = degree(parent(a))
  pol = data(a)
  conjs = Set{fq}()
  for (r, vr) in rt
    coeffs = Vector{fq}(undef, degree(pol)+1)
    for i = 0:degree(pol)
      nf_elem_to_gfp_fmpz_poly!(tmp, coeff(pol, i))
      coeffs[i+1] = evaluate(tmp, r)
    end
    g = Fx(coeffs)
    for i = 1:length(vr)
      ev = evaluate(g, vr[i])
      if ev in conjs
        return false
      end
      push!(conjs, ev)
    end
  end
  return true
end

function _find_prime(L::NfRel{nf_elem})
  p = 2^10
  K = base_field(L)
  OK = maximal_order(K)
  OL = maximal_order(L)

  n_attempts = min(degree(L), 10)
  candidates = Vector{Tuple{NfOrdIdl, Int}}(undef, n_attempts)
  i = 1
  f = L.pol
  threshold = degree(f)^2
  while i < n_attempts+1
    p = next_prime(p)
    if isindex_divisor(OK, p)
      continue
    end
    lp = prime_decomposition(OK, p)
    P = lp[1][1]
    if isindex_divisor(OL, P)
      continue
    end
    F, mF = ResidueField(OK, P)
    mF1 = extend_easy(mF, K)
    fF = map_coeffs(mF1, f)
    if degree(fF) != degree(f) || !issquarefree(fF)
      continue
    end
    FS = factor_shape(fF)
    d = lcm(Int[x for (x, v) in FS])
    if d < threshold
      candidates[i] = (P, d)
      i += 1
    end
  end
  res =  candidates[1]
  for j = 2:n_attempts
    if candidates[j][2] < res[2]
      res = candidates[j]
    end
  end
  return res[1], res[2]
end


function _sieve_primitive_elements(B::Vector{NfRelElem{nf_elem}}; parameter::Int = 3)
  Lrel = parent(B[1])
  n = absolute_degree(Lrel)
  #First, we choose the candidates
  Bnew = NfRelElem{nf_elem}[]
  nrep = parameter
  if n < parameter
    nrep = n
  end
  for i = 1:length(B)
    push!(Bnew, B[i])
    for j = 1:nrep
      if i != j
        push!(Bnew, B[i]+B[j])
        push!(Bnew, B[i]-B[j])
      end
    end
  end
  #Now, we test for primitiveness.
  K = base_field(Lrel)
  OK = maximal_order(K)
  Zx = ZZ["x"][1]

  

  P, d = _find_prime(Lrel)
  p = minimum(P, copy = false)
  abs_deg = d*degree(P)
  #First, we search for elements that are primitive using block systems
  Fp = GF(p, cached = false)
  Fpx = PolynomialRing(Fp, cached = false)[1]
  F = FlintFiniteField(p, abs_deg, "w", cached = false)[1]
  Fx = PolynomialRing(F, cached = false)[1]
  rt_base_field = roots(Zx(K.pol), F)
  tmp = Fpx()
  g = Lrel.pol
  rt = Dict{fq, Vector{fq}}()
  nroots = 0
  roots_needed = div(n, 2)+1
  for r in rt_base_field
    coeff_gF = fq[]
    for i = 0:degree(g)
      nf_elem_to_gfp_fmpz_poly!(tmp, coeff(g, i))
      push!(coeff_gF, evaluate(tmp, r))
    end
    gF = Fx(coeff_gF)
    rt[r] = roots(gF)
    nroots += length(roots(gF))
    if nroots >= roots_needed
      break
    end
  end
  
  indices = Int[]
  for i = 1:length(Bnew)
    if _is_primitive_via_block(Bnew[i], rt, Fx, tmp)
      push!(indices, i)
    end
  end
  return Bnew[indices]

end

function _find_prime(L::NfRelNS{nf_elem})
  p = 2^10
  K = base_field(L)
  OK = maximal_order(K)
  OL = maximal_order(L)
  dL = numerator(discriminant(L, FlintQQ))

  n_attempts = min(degree(L), 10)
  candidates = Vector{Tuple{NfOrdIdl, Int}}(undef, n_attempts)
  i = 1
  pols = L.pol
  threshold = absolute_degree(L)^2
  polsR = Vector{fq_poly}(undef, length(pols))
  while i < n_attempts+1
    p = next_prime(p)
    if isindex_divisor(OK, p) || divisible(dL, p)
      continue
    end
    lp = prime_decomposition(OK, p)
    P = lp[1][1]
    @assert !isindex_divisor(OL, P)
    F, mF = ResidueField(OK, P)
    mF1 = extend(mF, K)
    is_proj = true
    for j = 1:length(pols)
      fF = isunivariate(map_coeffs(mF1, pols[j]))[2]
      if degree(fF) != total_degree(pols[j]) || !issquarefree(fF)
        is_proj = false
        break
      end
      polsR[j] = fF
    end
    if !is_proj
      continue
    end
    d = 1
    for j = 1:length(polsR)
      FS = factor_shape(polsR[j])
      d1 = lcm(Int[x for (x, v) in FS])
      d = lcm(d, d1)
    end
    if d < threshold
      candidates[i] = (P, d)
      i += 1
    end
  end
  res = candidates[1]
  for j = 2:n_attempts
    if candidates[j][2]*degree(candidates[j][1]) < res[2]*degree(res[1])
      res = candidates[j]
    end
  end
  return res[1], res[2]
end

function _sieve_primitive_elements(B::Vector{NfRelNSElem{nf_elem}}; parameter::Int = 3)
  Lrel = parent(B[1])
  #First, we choose the candidates
  Bnew = NfRelNSElem{nf_elem}[]
  nrep = min(parameter, absolute_degree(Lrel))
  for i = 1:length(B)
    push!(Bnew, B[i])
    for j = 1:nrep
      if i != j
        push!(Bnew, B[i]+B[j])
        push!(Bnew, B[i]-B[j])
      end
    end
  end
  #Now, we test for primitiveness.
  K = base_field(Lrel)
  OK = maximal_order(K)
  Zx = ZZ["x"][1]

  n = absolute_degree(Lrel)

  P, d = _find_prime(Lrel)
  p = minimum(P, copy = false)
  abs_deg = d*degree(P)
  #First, we search for elements that are primitive using block systems
  Fp = GF(p, cached = false)
  Fpx = PolynomialRing(Fp, cached = false)[1]
  F = FlintFiniteField(p, abs_deg, "w", cached = false)[1]
  Fx = PolynomialRing(F, cached = false)[1]
  rt_base_field = roots(Zx(K.pol), F)
  rt = Dict{fq, Vector{Vector{fq}}}()
  Rxy = PolynomialRing(F, ngens(Lrel), cached = false)[1]
  tmp = Fpx()
  for r in rt_base_field
    vr = Vector{Vector{fq}}()
    for f in Lrel.pol
      g = isunivariate(f)[2]
      coeff_gF = fq[]
      for i = 0:degree(g)
        nf_elem_to_gfp_fmpz_poly!(tmp, coeff(g, i))
        push!(coeff_gF, evaluate(tmp, r))
      end
      gF = Fx(coeff_gF)
      push!(vr, roots(gF))
    end
    rt[r] = vr
  end
  rt1 = Dict{fq, Vector{Vector{fq}}}()
  ind = 1
  nconjs_needed = div(n, 2)+1
  for (r, v) in rt
    rtv = Vector{Vector{fq}}()
    it = cartesian_product_iterator([1:length(v[i]) for i in 1:length(v)])
    for i in it
      push!(rtv, [v[j][i[j]] for j = 1:length(v)])
      ind += 1
      if ind > nconjs_needed
        break
      end
    end
    rt1[r] = rtv
    if ind > nconjs_needed
      break
    end
  end
  indices = Int[]
  for i = 1:length(Bnew)
    if length(vars(Bnew[i].data)) < ngens(Lrel)
      continue
    end
    if _is_primitive_via_block(Bnew[i], rt1, Rxy, tmp)
      push!(indices, i)
    end
  end
  return Bnew[indices]
end

function _is_primitive_via_block(a::NfRelNSElem{nf_elem}, rt::Dict{fq, Vector{Vector{fq}}}, Rxy, tmp)
  n = degree(parent(a))
  pol = data(a)
  conjs = Set{fq}()
  for (r, vr) in rt
    ctx = MPolyBuildCtx(Rxy)
    for (c, v) in zip(coeffs(pol), exponent_vectors(pol))
      nf_elem_to_gfp_fmpz_poly!(tmp, c)
      push_term!(ctx, evaluate(tmp, r), v)
    end
    g = finish(ctx)
    for i = 1:length(vr)
      ev = evaluate(g, vr[i])
      if ev in conjs
        return false
      end
      push!(conjs, ev)
    end
  end
  return true
end

function simplified_absolute_field(L::NfRelNS; cached = false)
  OL = maximal_order(L)
  B = lll_basis(OL)
  B1 = _sieve_primitive_elements(B)
  nrep = 3
  while isempty(B1)
    nrep += 1
    B1 = _sieve_primitive_elements(B, parameter = nrep)
  end
  a = B1[1]
  I = t2(a)
  for i = 2:min(50, length(B1))
    J = t2(B1[i])
    if J < I
      a = B1[i]
      I = J
    end
  end
  f = absolute_minpoly(a)
  @assert degree(f) == absolute_degree(L)
  K = number_field(f, check = false, cached = cached)[1]
  mp = hom(K, L, a)
  return K, mp
end

function simplified_absolute_field(L::NfRel; cached::Bool = false)
  OL = maximal_order(L)
  B = lll_basis(OL)
  B1 = _sieve_primitive_elements(B)
  nrep = 4
  while isempty(B1)
    nrep += 1
    B1 = _sieve_primitive_elements(B, parameter = nrep)
  end
  a = B1[1]
  I = t2(a)
  for i = 2:min(50, length(B1))
    J = t2(B1[i])
    if J < I
      a = B1[i]
      I = J
    end
  end
  f = absolute_minpoly(a)
  @assert degree(f) == absolute_degree(L)
  K = number_field(f, check = false, cached = cached)[1]
  mp = hom(K, L, a)
  imp = inv(mp)
  return K, mp, hom(base_field(L), K,  imp(L(gen(base_field(L)))))
end