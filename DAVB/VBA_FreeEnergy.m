function [F] = VBA_FreeEnergy(posterior,suffStat,options)
% computes free energy of the sDCM generative model
% function [F] = VBA_FreeEnergy(posterior,suffStat,options)
% This function evaluates the free energy associated with the nonlinear
% state-space model inverted by the main inversion routine
% VBA_NLStateSpaceModel.m.
% IN:
%   - posterior: a structure containing the natural parameters of the
%   marginal posterior pdf of the unknown variables of the model
%   - suffStat: a structure containing pre-calculated (sufficient
%   statistics) quantities associated required for the computation of the
%   free energy (such as derivatives of the evolution/observation functions
%   evaluated at the current mode)
%   - options: a structure variable containing optional parameters (such as
%   the priors structure)
% OUT:
%   - F: the free energy under the local Laplace approximation

if ~options.Laplace
    [F] = VBA_FreeEnergy_old(posterior,suffStat,options);
    return
end

if options.DisplayWin % Display progress
    try
        set(options.display.hm(1),'string',...
            'Calculating Free Energy... ');
        set(options.display.hm(2),'string','0%');
        drawnow
    end
end

priors = options.priors;
dim = options.dim;

% Get common free energy terms
if ~options.binomial
    E = posterior.a_sigma./posterior.b_sigma;
    V = posterior.a_sigma./posterior.b_sigma^2;
    E0 = priors.a_sigma./priors.b_sigma;
    V0 = priors.a_sigma./priors.b_sigma^2;
    SSE = E*suffStat.dy2;
    dF = -VB_KL(E,V,E0,V0,'Gamma');
    ElogS = psi(posterior.a_sigma) - log(posterior.b_sigma);
else
    SSE = -2*suffStat.logL;
    dF = 0;
end
ldQ = 0;
S = 0;
ntot = 0;

if dim.n > 0 && ~isinf(priors.a_alpha) && ~isequal(priors.b_alpha,0)
    E = posterior.a_alpha./posterior.b_alpha;
    V = posterior.a_alpha./posterior.b_alpha^2;
    E0 = priors.a_alpha./priors.b_alpha;
    V0 = priors.a_alpha./priors.b_alpha^2;
    ElogA = psi(posterior.a_alpha) - log(posterior.b_alpha);
    dF = dF - VB_KL(E,V,E0,V0,'Gamma');
    SSE = SSE + E*suffStat.dx2;
    S = S + suffStat.SX;
end

for t=1:dim.n_t
    if ~options.binomial
        ldQ = ldQ + VBA_logDet(options.priors.iQy{t});
        ny = length(find(diag(options.priors.iQy{t})~=0));
        dF = dF + 0.5*ny*ElogS;
        ntot = ntot + ny;
    end
    if dim.n > 0  && ~isinf(priors.a_alpha) && ~isequal(priors.b_alpha,0)
        indIn = options.params2update.x{t};
        nx = length(indIn);
        ldQ = ldQ + VBA_logDet(options.priors.iQx{t},indIn);
        dF = dF + 0.5*nx*ElogA;
        ntot = ntot + nx;
        S = S - 0.5*nx;
    end
end


% observation parameters
if dim.n_phi > 0
    indIn = options.params2update.phi;
    if ~isempty(indIn)
        ntot = ntot + length(indIn);
        Q = priors.SigmaPhi(indIn,indIn);
        iQ = VB_inv(Q,[]);
        SSE = SSE + suffStat.dphi(indIn)'*iQ*suffStat.dphi(indIn);
        ldQ = ldQ - VBA_logDet(Q,[]);
        S = S + suffStat.Sphi - 0.5*length(indIn);
    end
end

% evolution parameters
if dim.n_theta > 0
    indIn = options.params2update.theta;
    if ~isempty(indIn)
        ntot = ntot + length(indIn);
        Q = priors.SigmaTheta(indIn,indIn);
        iQ = VB_inv(Q,[]);
        SSE = SSE + suffStat.dtheta(indIn)'*iQ*suffStat.dtheta(indIn);
        ldQ = ldQ - VBA_logDet(Q,[]);
        S = S + suffStat.Stheta - 0.5*length(indIn);
    end
end

% initial conditions
if dim.n > 0
    indIn = options.params2update.x0;
    if ~isempty(indIn)
        ntot = ntot + length(indIn);
        Q = priors.SigmaX0(indIn,indIn);
        iQ = VB_inv(Q,[]);
        SSE = SSE + suffStat.dx0(indIn)'*iQ*suffStat.dx0(indIn);
        ldQ = ldQ - VBA_logDet(Q,[]);
        S = S + suffStat.SX0 - 0.5*length(indIn);
    end
end


% Compose free energy
F = - 0.5*SSE - 0.5*ntot*log(2*pi) + 0.5*ldQ + S + dF;


if options.DisplayWin % Display progress
    try
        set(options.display.hm(2),'string','OK');
        drawnow
    end
end

