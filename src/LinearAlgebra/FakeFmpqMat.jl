################################################################################
#
#  FakeFmpqMat.jl : Model fmpq_mat's as fmpz_mat's with denominator
#
################################################################################

iszero(x::FakeFmpqMat) = iszero(x.num)

numerator(x::FakeFmpqMat) = deepcopy(x.num)

denominator(x::FakeFmpqMat) = deepcopy(x.den)

nrows(x::FakeFmpqMat) = nrows(x.num)

ncols(x::FakeFmpqMat) = ncols(x.num)

function simplify_content!(x::FakeFmpqMat)
  c = content(x.num)
  c = gcd(c, x.den)
  if !isone(c) 
    divexact!(x.num, x.num, c)
    divexact!(x.den, x.den, c)
  end
  y = canonical_unit(x.den)
  if !isone(y)
    mul!(x.den, x.den, y)
    mul!(x.num, x.num, y)
  end
end

################################################################################
#
#  Hashing
#
################################################################################

function hash(a::FakeFmpqMat, b::UInt)
  h = xor(Base.hash(a.num, b), Base.hash(a.den, b))
  h = xor(h, Base.hash(b))
  h = (h << 1) | (h >> (sizeof(Int)*8 - 1))
  return h
end

################################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, x::FakeFmpqMat)
  print(io, "FakeFmpqMat with numerator\n", x.num, "\nand denominator ", x.den)
end

################################################################################
#
#  Unary operations
#
################################################################################

function -(x::FakeFmpqMat)
  return FakeFmpqMat(-x.num, x.den, true)
end

function inv(x::FakeFmpqMat)
  i, d_i = pseudo_inv(x.num) 
  #TODO gcd d_i and x.den 1st!!!
  i *= x.den
  z = FakeFmpqMat(i,d_i)
  simplify_content!(z)
  return z
end

################################################################################
#
#  Binary operations
#
################################################################################

function +(x::FakeFmpqMat, y::FakeFmpqMat)
  t = y.den*x.num + x.den*y.num
  d = x.den*y.den
  z = FakeFmpqMat(t,d)
  return z
end

function *(x::FakeFmpqMat, y::FakeFmpqMat)
  t = x.num*y.num
  d = x.den * y.den
  z = FakeFmpqMat(t, d)
  return z
end

function mul!(z::FakeFmpqMat, x::FakeFmpqMat, y::FakeFmpqMat)
  mul!(z.num, x.num, y.num)
  mul!(z.den, x.den, y.den)
  simplify_content!(z)
  return z
end

################################################################################
#
#  Adhoc binary operations
#
################################################################################

function *(x::FakeFmpqMat, y::fmpz_mat)
  t = x.num*y
  z = FakeFmpqMat(t, denominator(x))
  simplify_content!(z)
  return z
end

function *(x::fmpz_mat, y::FakeFmpqMat)
  t = x*y.num
  z = FakeFmpqMat(t, denominator(y))
  simplify_content!(z)
  return z
end

################################################################################
#
#  Comparison
#
################################################################################

==(x::FakeFmpqMat, y::FakeFmpqMat) = (x.num == y.num) && (x.den == y.den)

isequal(x::FakeFmpqMat, y::FakeFmpqMat) = (x.num == y.num) && (x.den == y.den)

################################################################################
#
#  Conversion
#
################################################################################

to_array(x::FakeFmpqMat) = (x.num, x.den)

function to_fmpz_mat(x::FakeFmpqMat)
  !isone(x.den) && error("Denominator has to be 1")
  return numerator(x)
end

function FakeFmpqMat(x::Vector{fmpq})
  dens = fmpz[denominator(x[i]) for i=1:length(x)]
  den = lcm(dens)
  M = zero_matrix(FlintZZ, 1, length(x))
  for i in 1:length(x)
    M[1,i] = numerator(x[i])*divexact(den, dens[i])
  end
  return FakeFmpqMat(M,den)
end


################################################################################
#
#  Hermite normal form for numerator
#
################################################################################

function hnf!(x::FakeFmpqMat, shape = :lowerleft)
  x.num = _hnf(x.num, shape)
  return x
end

function hnf(x::FakeFmpqMat, shape = :lowerleft)
  h = _hnf(x.num, shape)
  return FakeFmpqMat(h, denominator(x))
end

function hnf!!(x::FakeFmpqMat, shape = :lowerleft)
  _hnf!(x.num, shape)
end

################################################################################
#
#  Sub
#
################################################################################

function sub(x::FakeFmpqMat, r::UnitRange{Int}, c::UnitRange{Int})
  z = FakeFmpqMat(sub(x.num, r, c), x.den)
  return z
end

function Base.deepcopy_internal(x::FakeFmpqMat, dict::IdDict)
  z = FakeFmpqMat()
  z.num = Base.deepcopy_internal(x.num, dict)
  z.den = Base.deepcopy_internal(x.den, dict)
  z.rows = nrows(x)
  z.cols = ncols(x)
  if isdefined(x, :parent)
    z.parent = x.parent
  end
  return z
end

################################################################################
#
#  Zero row
#
################################################################################

function iszero_row(M::FakeFmpqMat, i::Int)
  return iszero_row(M.num, i)
end

################################################################################
#
#  Determinant
#
################################################################################

function det(x::FakeFmpqMat)
  nrows(x) != ncols(x) && error("Matrix must be square")
  
  return det(x.num)//(x.den)^nrows(x)
end