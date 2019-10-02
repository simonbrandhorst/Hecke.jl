
## Payani's algorithm.

eisf_elem = Hecke.eisf_elem

# TODO: Various division operators and coefficient manipulations need to be implemented.

# Citation "krasner.pdf"
# import Base.//
# function //(f::Hecke.Generic.Poly{T}, b::T) where T <: NALocalFieldElem
#     g = deepcopy(f)
#     for i=1:degree(f)+1
#         g.coeffs[i] = g.coeffs[i]//b
#     end
#     return g
# end


import Markdown
@doc Markdown.doc"""
    number_of_roots(K, f)
Given an eisenstein extension `K` and a polynomial $f \in K[x]$, return the number of roots of `f` defined over `K`.
"""
function number_of_roots(f::Hecke.Generic.Poly{<:NALocalFieldElem})

    K = base_ring(f)
    k, mp_struct = ResidueField(K)

    # Unpack the map structure to get the maps to/from the residue field.
    res  = mp_struct.f
    lift = mp_struct.g
    
    x = gen(parent(f))
    pi = uniformizer(K)
    C = [primitive_part(f)]
    m = 0

    while !isempty(C)
        c = pop!(C)        
        cp = change_base_ring(c, res)
        Rfp = parent(cp)
        rts = roots(cp)
        
        for rt in rts
            
            h = primitive_part( c(pi*x + lift(rt)) )
            hp = change_base_ring(h, res)
            
            if degree(hp) == 1
                m += 1
            elseif degree(hp) > 1
                push!(C, h)        
            end
        end

        if length(C) >= degree(f)
            error("Code has clearly gone wrong")
        end
    end
    return m
end

function number_of_roots(f::Hecke.Generic.Poly{<:NALocalFieldElem}, K::NALocalField)
    return number_of_roots(change_base_ring(f, K))
end

############################################################

# Lifting the roots looks like the next step...

my_setprecision!(f,N) = f

# Should use a precision access function rather than a "__.N".

#XXX: valuation(Q(0)) == 0 !!!!!
function newton_lift(f::Hecke.Generic.Poly{T}, r::T) where T<:NALocalFieldElem

    # The many setprecision! calls are likely not valid for an approximately defined
    # polynomial.

    r.N = 1 # TODO: should be removed.
    
    K = parent(r)
    #n = K.prec_max
    n = 100
    
    i = n
    chain = [n]
    while i>2
        i = div(i+1, 2)
        push!(chain, i)
    end
    df  = derivative(f)
    fK  = change_base_ring(f, K)
    dfK = change_base_ring(df, K)

    @assert r.N == 1          # Ensure the residue is well-defined.
    df_at_r_inverse = K(r)    # Cache and update the values of 1/dfK(r)
    df_at_r_inverse.N = 1
    df_at_r_inverse = inv(my_setprecision!(dfK, 1)(df_at_r_inverse))
    
    #s = fK(r)

    for current_precision in reverse(chain)
        
        r.N               = current_precision
        df_at_r_inverse.N = current_precision
        #K.prec_max = r.N
        my_setprecision!(fK, r.N)
        my_setprecision!(dfK, r.N)        
        r = r - fK(r) * df_at_r_inverse
        #if r.N >= n
        #    K.prec_max = n
        #    return r
        #end

        # Update the value of the derivative.
        df_at_r_inverse = df_at_r_inverse*(2-dfK(r)*df_at_r_inverse)
    end

    return r
end

import Hecke.roots

# TODO: XXX: f is assumed to be "square-free".
function integral_roots(f::Hecke.Generic.Poly{<:Hecke.NALocalFieldElem})

    K = base_ring(parent(f))
    k, mp_struct = ResidueField(K)

    # Unpack the map structure to get the maps to/from the residue field.
    res  = mp_struct.f
    lift = mp_struct.g

    x = gen(parent(f))
    pi = uniformizer(K)
    roots_type = elem_type(K)
    
    fprim = primitive_part(f)
    fp = change_base_ring(fprim, res)

    rts = roots(fp)
    
    if length(rts)==0
        # There are no roots in the padic unit disk        
        return roots_type[]
        
    elseif degree(fp) == 1
        # There is exactly one root, which can be Hensel lifted
        rr = lift(rts[1])
        return [newton_lift(fprim,rr)]

    else
        # There are multiple roots in the unit disk. Zoom in on each.
        roots_out = roots_type[]
        for beta in rts
            beta_lift = lift(beta)
            roots_near_beta = integral_roots( fprim(pi*x + beta_lift) )
            roots_out = vcat(roots_out, [pi*r + beta_lift for r in roots_near_beta] )
        end
        
        return roots_out
    end
    error("Etwas hat scheif gelaufen.")
end

function roots(f::Hecke.Generic.Poly{<:Hecke.NALocalFieldElem})

    K = base_ring(parent(f))
    pi = uniformizer(K)
    x = gen(parent(f))
    
    Ov_roots   = integral_roots(f,K)
    outside_Ov_roots = integral_roots(reverse(f)(pi*x), K)
    filter!(r->r!=K(0), outside_Ov_roots)
    return vcat(Ov_roots, [inv(rt) for rt in outside_Ov_roots])
end

function roots(f, K::Hecke.Field)
    #base_ring(f) != K && error("Not implemented unless the polynomial has base ring $K.")
    return roots(change_base_ring(f,K))
end

function integral_roots(f, K::Hecke.Field)
    #base_ring(f) != K && error("Not implemented unless the polynomial has base ring $K.")
    return integral_roots(change_base_ring(f,K))
end


######################################################################
#
# Tests!
#
######################################################################

rts1 = roots(fK)
correct = fmpz(5) + 138118274 + O(Qp,7^10)
# + O(7^10)

@assert length(rts1) == 1 && K(correct) == rts1[1]

rts2 = roots(x^6 - 7, K)

correct = [
(2 + 4*7^1 + 6*7^2 + 3*7^3 + 2*7^5 + 6*7^6 + 2*7^7 + 4*7^8 + O(Qp,7^9))*θ
(3 + 4*7^1 + 6*7^2 + 3*7^3 + 2*7^5 + 6*7^6 + 2*7^7 + 4*7^8 + O(Qp,7^9))*θ        
(5 + 2*7^1 + 3*7^3 + 6*7^4 + 4*7^5 + 4*7^7 + 2*7^8 + O(Qp,7^9))*θ                
θ                                                                             
(4 + 2*7^1 + 3*7^3 + 6*7^4 + 4*7^5 + 4*7^7 + 2*7^8 + O(Qp,7^9))*θ                
(6 + 6*7^1 + 6*7^2 + 6*7^3 + 6*7^4 + 6*7^5 + 6*7^6 + 6*7^7 + 6*7^8 + O(Qp,7^9))*θ
]

@assert rts2 == correct



nothing
