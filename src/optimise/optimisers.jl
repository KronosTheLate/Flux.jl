using Flux
using MacroTools: @forward

abstract type AbstractOptimiser end

const EPS = 1e-8

# TODO: should use weak refs

"""
    Descent(η = 0.1)

Classic gradient descent optimiser with learning rate `η`.
For each parameter `p` and its gradient `δp`, this runs `p -= η*δp`

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.

# Examples
```julia
opt = Descent()

opt = Descent(0.3)

ps = Flux.params(model)

gs = gradient(ps) do
    loss(x, y)
end

Flux.Optimise.update!(opt, ps, gs)
```
"""
mutable struct Descent <: AbstractOptimiser
  eta::Float64
end

Descent() = Descent(0.1)

function apply!(o::Descent, x, Δ)
  Δ .*= o.eta
end

"""
    Momentum(η = 0.01, ρ = 0.9)

Gradient descent optimizer with learning rate `η` and momentum `ρ`.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Momentum (`ρ`): Controls the acceleration of gradient descent in the
                  prominent direction, in effect damping oscillations.

# Examples
```julia
opt = Momentum()

opt = Momentum(0.01, 0.99)
```
"""
mutable struct Momentum <: AbstractOptimiser
  eta::Float64
  rho::Float64
  velocity::IdDict
end

Momentum(η = 0.01, ρ = 0.9) = Momentum(η, ρ, IdDict())

function apply!(o::Momentum, x, Δ)
  η, ρ = o.eta, o.rho
  v = get!(() -> zero(x), o.velocity, x)::typeof(x)
  @. v = ρ * v - η * Δ
  @. Δ = -v
end

"""
    Nesterov(η = 0.001, ρ = 0.9)

Gradient descent optimizer with learning rate `η` and Nesterov momentum `ρ`.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Nesterov momentum (`ρ`): Controls the acceleration of gradient descent in the
                           prominent direction, in effect damping oscillations.

# Examples
```julia
opt = Nesterov()

opt = Nesterov(0.003, 0.95)
```
"""
mutable struct Nesterov <: AbstractOptimiser
  eta::Float64
  rho::Float64
  velocity::IdDict
end

Nesterov(η = 0.001, ρ = 0.9) = Nesterov(η, ρ, IdDict())

function apply!(o::Nesterov, x, Δ)
  η, ρ = o.eta, o.rho
  v = get!(() -> zero(x), o.velocity, x)::typeof(x)
  d = @. ρ^2 * v - (1+ρ) * η * Δ
  @. v = ρ*v - η*Δ
  @. Δ = -d
end

"""
    RMSProp(η = 0.001, ρ = 0.9, ϵ = $EPS)

Optimizer using the
[RMSProp](https://www.cs.toronto.edu/~tijmen/csc321/slides/lecture_slides_lec6.pdf)
algorithm. Often a good choice for recurrent networks. Parameters other than learning rate
generally don't need tuning.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Momentum (`ρ`): Controls the acceleration of gradient descent in the
                  prominent direction, in effect damping oscillations.

# Examples
```julia
opt = RMSProp()

opt = RMSProp(0.002, 0.95)
```
"""
mutable struct RMSProp <: AbstractOptimiser
  eta::Float64
  rho::Float64
  epsilon::Float64
  acc::IdDict
end
RMSProp(η::Real = 0.001, ρ::Real = 0.9, ϵ::Real = EPS) = RMSProp(η, ρ, ϵ, IdDict())
RMSProp(η::Real, ρ::Real, acc::IdDict) = RMSProp(η, ρ, EPS, acc)

function apply!(o::RMSProp, x, Δ)
  η, ρ = o.eta, o.rho
  acc = get!(() -> zero(x), o.acc, x)::typeof(x)
  @. acc = ρ * acc + (1 - ρ) * Δ * conj(Δ)
  @. Δ *= η / (√acc + o.epsilon)
end

"""
    ADAM(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

[ADAM](https://arxiv.org/abs/1412.6980) optimiser.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = ADAM()

opt = ADAM(0.001, (0.9, 0.8))
```
"""
mutable struct ADAM <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64,Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
ADAM(η::Real = 0.001, β::Tuple = (0.9, 0.999), ϵ::Real = EPS) = ADAM(η, β, ϵ, IdDict())
ADAM(η::Real, β::Tuple, state::IdDict) = ADAM(η, β, EPS, state)

function apply!(o::ADAM, x, Δ)
  η, β = o.eta, o.beta

  mt, vt, βp = get!(o.state, x) do
      (zero(x), zero(x), Float64[β[1], β[2]])
  end :: Tuple{typeof(x),typeof(x),Vector{Float64}}

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. vt = β[2] * vt + (1 - β[2]) * Δ * conj(Δ)
  @. Δ =  mt / (1 - βp[1]) / (√(vt / (1 - βp[2])) + o.epsilon) * η
  βp .= βp .* β

  return Δ
end

"""
    RADAM(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

[Rectified ADAM](https://arxiv.org/abs/1908.03265) optimizer.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = RADAM()

opt = RADAM(0.001, (0.9, 0.8))
```
"""
mutable struct RADAM <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64,Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
RADAM(η::Real = 0.001, β::Tuple = (0.9, 0.999), ϵ::Real = EPS) = RADAM(η, β, ϵ, IdDict())
RADAM(η::Real, β::Tuple, state::IdDict) = RADAM(η, β, EPS, state)

function apply!(o::RADAM, x, Δ)
  η, β = o.eta, o.beta
  ρ∞ = 2/(1-β[2])-1

  mt, vt, βp, t = get!(o.state, x) do
      (zero(x), zero(x), Float64[β[1], β[2]], Ref(1))
  end :: Tuple{typeof(x),typeof(x),Vector{Float64},Base.RefValue{Int}}

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. vt = β[2] * vt + (1 - β[2]) * Δ * conj(Δ)
  ρ = ρ∞ - 2t[] * βp[2] / (1 - βp[2])
  if ρ > 4
    r = sqrt((ρ-4)*(ρ-2)*ρ∞/((ρ∞-4)*(ρ∞-2)*ρ))
    @. Δ =  mt / (1 - βp[1]) / (√(vt / (1 - βp[2])) + o.epsilon) * η * r
  else
    @. Δ =  mt / (1 - βp[1]) * η
  end
  βp .= βp .* β
  t[] += 1

  return Δ
end

"""
    AdaMax(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

[AdaMax](https://arxiv.org/abs/1412.6980) is a variant of ADAM based on the ∞-norm.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = AdaMax()

opt = AdaMax(0.001, (0.9, 0.995))
```
"""
mutable struct AdaMax <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64,Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
AdaMax(η::Real = 0.001, β::Tuple = (0.9, 0.999), ϵ::Real = EPS) = AdaMax(η, β, ϵ, IdDict())
AdaMax(η::Real, β::Tuple, state::IdDict) = AdaMax(η, β, EPS, state)

function apply!(o::AdaMax, x, Δ)
  η, β = o.eta, o.beta

  mt, ut, βp = get!(o.state, x) do
      (zero(x), zero(x), Float64[β[1], β[2]])
  end :: Tuple{typeof(x),typeof(x),Vector{Float64}}

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. ut = max(β[2] * ut, abs(Δ))
  @. Δ = (η/(1 - βp[1])) * mt/(ut + o.epsilon)
  βp .= βp .* β

  return Δ
end

"""
    OADAM(η = 0.0001, β::Tuple = (0.5, 0.9), ϵ = $EPS)

[OADAM](https://arxiv.org/abs/1711.00141) (Optimistic ADAM)
is a variant of ADAM adding an "optimistic" term suitable for adversarial training.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = OADAM()

opt = OADAM(0.001, (0.9, 0.995))
```
"""
mutable struct OADAM <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64,Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
OADAM(η::Real = 0.001, β::Tuple = (0.5, 0.9), ϵ::Real = EPS) = OADAM(η, β, ϵ, IdDict())
OADAM(η::Real, β::Tuple, state::IdDict) = RMSProp(η, β, EPS, state)

function apply!(o::OADAM, x, Δ)
  η, β = o.eta, o.beta

  mt, vt, Δ_, βp = get!(o.state, x) do
      (zero(x), zero(x), zero(x), Float64[β[1], β[2]])
  end :: Tuple{typeof(x),typeof(x),typeof(x),Vector{Float64}}

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. vt = β[2] * vt + (1 - β[2]) * Δ * conj(Δ)
  @. Δ = -Δ_
  @. Δ_ = η * mt / (1 - βp[1]) / (√(vt / (1 - βp[2])) + o.epsilon)
  @. Δ += 2Δ_
  βp .= βp .* β

  return Δ
end

"""
    ADAGrad(η = 0.1, ϵ = $EPS)

[ADAGrad](http://www.jmlr.org/papers/volume12/duchi11a/duchi11a.pdf) optimizer. It has
parameter specific learning rates based on how frequently it is updated.
Parameters don't need tuning.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.

# Examples
```julia
opt = ADAGrad()

opt = ADAGrad(0.001)
```
"""
mutable struct ADAGrad <: AbstractOptimiser
  eta::Float64
  epsilon::Float64
  acc::IdDict
end
ADAGrad(η::Real = 0.1, ϵ::Real = EPS) = ADAGrad(η, ϵ, IdDict())
ADAGrad(η::Real, state::IdDict) = ADAGrad(η, EPS, state)

function apply!(o::ADAGrad, x, Δ)
  η = o.eta
  acc = get!(() -> fill!(similar(x), o.epsilon), o.acc, x)::typeof(x)
  @. acc += Δ * conj(Δ)
  @. Δ *= η / (√acc + o.epsilon)
end

"""
    ADADelta(ρ = 0.9, ϵ = $EPS)

[ADADelta](https://arxiv.org/abs/1212.5701) is a version of ADAGrad adapting its learning
rate based on a window of past gradient updates.
Parameters don't need tuning.

# Parameters
- Rho (`ρ`): Factor by which the gradient is decayed at each time step.

# Examples
```julia
opt = ADADelta()

opt = ADADelta(0.89)
```
"""
mutable struct ADADelta <: AbstractOptimiser
  rho::Float64
  epsilon::Float64
  state::IdDict{Any, Any}
end
ADADelta(ρ::Real = 0.9, ϵ::Real = EPS) = ADADelta(ρ, ϵ, IdDict())
ADADelta(ρ::Real, state::IdDict) = ADADelta(ρ, EPS, state)

function apply!(o::ADADelta, x, Δ)
  ρ = o.rho
  acc, Δacc = get!(() -> (zero(x), zero(x)), o.state, x)::NTuple{2,typeof(x)}
  @. acc = ρ * acc + (1 - ρ) * Δ * conj(Δ)
  # DON'T remove epsilon from numerator
  # or even out of the square roots
  @. Δ *= √(Δacc + o.epsilon) / √(acc + o.epsilon)
  @. Δacc = ρ * Δacc + (1 - ρ) * Δ * conj(Δ)
  return Δ
end

"""
    AMSGrad(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

The [AMSGrad](https://openreview.net/forum?id=ryQu7f-RZ) version of the ADAM
optimiser. Parameters don't need tuning.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = AMSGrad()

opt = AMSGrad(0.001, (0.89, 0.995))
```
"""
mutable struct AMSGrad <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64, Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
AMSGrad(η::Real = 0.001, β = (0.9, 0.999), ϵ::Real = EPS) = AMSGrad(η, β, ϵ, IdDict())
AMSGrad(η::Real, β::Tuple, state::IdDict) = AMSGrad(η, β, EPS, state)

function apply!(o::AMSGrad, x, Δ)
  η, β = o.eta, o.beta

  mt, vt, v̂t = get!(o.state, x) do
    (fill!(similar(x), o.epsilon), fill!(similar(x), o.epsilon), fill!(similar(x), o.epsilon))
  end :: NTuple{3,typeof(x)}

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. vt = β[2] * vt + (1 - β[2]) * Δ ^ 2
  @. v̂t = max(v̂t, vt)
  @. Δ = η * mt / (√v̂t + o.epsilon)
end

"""
    NADAM(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

[NADAM](https://openreview.net/forum?id=OM0jvwB8jIp57ZJjtNEZ) is a Nesterov variant of ADAM.
Parameters don't need tuning.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = NADAM()

opt = NADAM(0.002, (0.89, 0.995))
```
"""
mutable struct NADAM <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64, Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
NADAM(η::Real = 0.001, β = (0.9, 0.999), ϵ::Real = EPS) = NADAM(η, β, ϵ, IdDict())
NADAM(η::Real, β::Tuple, state::IdDict) = NADAM(η, β, EPS, state)

function apply!(o::NADAM, x, Δ)
  η, β = o.eta, o.beta

  mt, vt, βp = get!(o.state, x) do
    (zero(x), zero(x), Float64[o.beta[1], o.beta[2]])
  end :: Tuple{typeof(x),typeof(x),Vector{Float64}}
  β1p, β2p = βp

  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. vt = β[2] * vt + (1 - β[2]) * Δ * conj(Δ)
  @. Δ = (β[1] * mt / (1 - β[1] * β1p) + (1 - β[1]) * Δ / (1 - β1p)) / (√(vt * β[2] / (1 - β2p)) + o.epsilon) * η
  βp .= βp .* β

  return Δ
end

"""
    ADAMW(η = 0.001, β::Tuple = (0.9, 0.999), decay = 0)

[ADAMW](https://arxiv.org/abs/1711.05101) is a variant of ADAM fixing (as in repairing) its
weight decay regularization.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.
- `decay`: Decay applied to weights during optimisation.

# Examples
```julia
opt = ADAMW()

opt = ADAMW(0.001, (0.89, 0.995), 0.1)
```
"""
ADAMW(η = 0.001, β = (0.9, 0.999), decay = 0) =
  Optimiser(ADAM(η, β), WeightDecay(decay))

"""
    AdaBelief(η = 0.001, β::Tuple = (0.9, 0.999), ϵ = $EPS)

The [AdaBelief](https://arxiv.org/abs/2010.07468) optimiser is a variant of the well-known
ADAM optimiser.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- Decay of momentums (`β::Tuple`): Exponential decay for the first (β1) and the
                                   second (β2) momentum estimate.

# Examples
```julia
opt = AdaBelief()

opt = AdaBelief(0.001, (0.9, 0.8))
```
"""
mutable struct AdaBelief <: AbstractOptimiser
  eta::Float64
  beta::Tuple{Float64,Float64}
  epsilon::Float64
  state::IdDict{Any, Any}
end
AdaBelief(η::Real = 0.001, β = (0.9, 0.999), ϵ::Real = EPS) = AdaBelief(η, β, ϵ, IdDict())
AdaBelief(η::Real, β::Tuple, state::IdDict) = AdaBelief(η, β, EPS, state)

function apply!(o::AdaBelief, x, Δ)
  η, β = o.eta, o.beta

  mt, st, βp = get!(o.state, x) do
      (zero(x), zero(x), Float64[β[1], β[2]])
  end :: Tuple{typeof(x), typeof(x), Vector{Float64}}

  #= st is a variance and can go to zero. This is in contrast to ADAM, which uses the
  second moment which is usually far enough from zero. This is problematic, since st
  can be slightly negative due to numerical error, and the square root below will fail.
  Also, if we want to differentiate through the optimizer, √0 is not differentiable.
  To protect against this, we add a small number, st -> st + eps2.
  The original implementation (https://github.com/juntang-zhuang/Adabelief-Optimizer)
  uses the square of Adam's epsilon, which we do here.
  See also: https://github.com/juntang-zhuang/Adabelief-Optimizer/issues/61 =#
  eps2 = o.epsilon^2 # TODO: make epsilon^2 the default in next breaking release
  
  @. mt = β[1] * mt + (1 - β[1]) * Δ
  @. st = β[2] * st + (1 - β[2]) * (Δ - mt) * conj(Δ - mt) + eps2
  @. Δ =  η * mt / (1 - βp[1]) / (√(st / (1 - βp[2])) + eps2)
  βp .= βp .* β

  return Δ
end


# Compose optimizers

"""
    Optimiser(a, b, c...)

Combine several optimisers into one; each optimiser produces a modified gradient
that will be fed into the next, and this is finally applied to the parameter as
usual.
"""
mutable struct Optimiser <: AbstractOptimiser
  os::Vector{Any}
end

Optimiser(opts::AbstractOptimiser...) = Optimiser(Any[opts...])

@forward Optimiser.os Base.getindex, Base.first, Base.last, Base.lastindex, Base.push!, Base.setindex!
@forward Optimiser.os Base.iterate

Base.getindex(c::Optimiser, i::AbstractArray) = Optimiser(c.os[i]...)

function apply!(o::Optimiser, x, Δ)
  for opt in o.os
    Δ = apply!(opt, x, Δ)
  end
  return Δ
end

"""
    InvDecay(γ = 0.001)

Apply inverse time decay to an optimiser, so that the effective step size at
iteration `n` is `eta / (1 + γ * n)` where `eta` is the initial step size.
The wrapped optimiser's step size is not modified.

See also the [Scheduling Optimisers](@ref) section of the docs
for more general scheduling techniques.

# Examples

`InvDecay` is typically composed  with other optimizers 
as the last transformation of the gradient:

```julia
# Inverse decay of the learning rate
# with starting value 0.001 and decay coefficient 0.01.
opt = Optimiser(Adam(1f-3), InvDecay(1f-2))
```
"""
mutable struct InvDecay <: AbstractOptimiser
  gamma::Float64
  state::IdDict{Any, Int}
end

InvDecay(γ = 0.001) = InvDecay(γ, IdDict{Any, Int}())

function apply!(o::InvDecay, x, Δ)
  γ = o.gamma
  n = get!(o.state, x, 1)
  Δ .*= 1 / (1 + γ * n)
  o.state[x] = n + 1
  return Δ
end

"""
    ExpDecay(η = 0.001, decay = 0.1, decay_step = 1000, clip = 1e-4, start = 1)

Discount the learning rate `η` by the factor `decay` every `decay_step` steps till
a minimum of `clip`.

# Parameters
- Learning rate (`η`): Amount by which gradients are discounted before updating
                       the weights.
- `decay`: Factor by which the learning rate is discounted.
- `decay_step`: Schedule decay operations by setting the number of steps between
                two decay operations.
- `clip`: Minimum value of learning rate.
- 'start': Step at which the decay starts.


See also the [Scheduling Optimisers](@ref) section of the docs
for more general scheduling techniques.

# Examples

`ExpDecay` is typically composed  with other optimizers 
as the last transformation of the gradient:
```julia
opt = Optimiser(ADAM(), ExpDecay(1.0))
```
Note: you may want to start with `η=1` in `ExpDecay` when combined with other
optimizers (`ADAM` in this case) that have their own learning rate.
"""
mutable struct ExpDecay <: AbstractOptimiser
  eta::Float64
  decay::Float64
  step::Int64
  clip::Float64
  start::Int64
  current::IdDict
end

ExpDecay(opt = 0.001, decay = 0.1, decay_step = 1000, clip = 1e-4, start = 0) =
  ExpDecay(opt, decay, decay_step, clip, start, IdDict())

function apply!(o::ExpDecay, x, Δ)
  η, s, decay, start = o.eta, o.step, o.decay, o.start
  n = o.current[x] = get(o.current, x, 0) + 1
  if n > start && n % s == 0 && count(x -> x > start && x % s == 0, values(o.current)) == 1
    η = max(η * decay, o.clip)
    o.eta = η
  end
  @. Δ *= η
end

"""
    WeightDecay(λ = 0)

Decay weights by ``λ``. 
Typically composed  with other optimizers as the first transformation to the gradient,
making it equivalent to adding ``L_2`` regularization 
with coefficient  ``λ`` to the loss.

# Examples

```julia
opt = Optimiser(WeightDecay(1f-4), ADAM())
```
"""
mutable struct WeightDecay <: AbstractOptimiser
  wd::Real
end

WeightDecay() = WeightDecay(0)

function apply!(o::WeightDecay, x, Δ)
  wd = o.wd
  @. Δ += wd * x
end

"""
    ClipValue(thresh)

Clip gradients when their absolute value exceeds `thresh`.
"""
mutable struct ClipValue{T} <: AbstractOptimiser
    thresh::T
end

apply!(o::ClipValue, x, Δ) = clamp!(Δ, -o.thresh, o.thresh)

"""
    ClipNorm(thresh)

Clip gradients when their L2 norm exceeds `thresh`.
"""
mutable struct ClipNorm{T} <: AbstractOptimiser
    thresh::T
end

function apply!(o::ClipNorm, x, Δ)
    Δnrm = norm(Δ)
    if Δnrm > o.thresh
        rmul!(Δ, o.thresh / Δnrm)
    end
    return Δ
end
