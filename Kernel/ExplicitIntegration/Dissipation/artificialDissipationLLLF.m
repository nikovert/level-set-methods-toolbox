function [ diss, stepBound ] = ...
                 artificialDissipationLLLF(t, data, derivL, derivR, schemeData)
% artificialDissipationLLLF: local Lax-Friedrichs dissipation calculation.
%
% [ diss, stepBound ] = ...
%                artificialDissipationLLLF(t, data, derivL, derivR, schemeData)
%
% Calculates the stabilizing dissipation for the local-local Lax-Friedrichs
%   numerical Hamiltonian, which is known to be nonmonotone.  The method is
%   "local-local" because it optimizes alpha = |\partial H(x,p) / \partial
%   p_i| at each node x over the range for that node (ie p^+ to p^- at that
%   node).  The result is guaranteed to generate the same or less
%   dissipation than both the regular (global) Lax-Friedrichs and the local
%   Lax-Friedrichs.  It will be the same as local LF for separable
%   Hamiltonians (of the form H(x,p) = \sum_i H_i(x,p_i)); unfortunately, in
%   those cases where it differs from local LF it may not introduce
%   sufficient dissipation and lead to instability.  Since it is not
%   monotone, it may not converge even when used with monotone spatial
%   and time derivative approximations.
%
% Based on methods outlined in O&F, chapter 5.3.1 (the LLLF scheme).
%
% Parameters:
%   t            Time at beginning of timestep.
%   data         Data array.
%   derivL	 Cell vector with left derivatives of the data.
%   derivR	 Cell vector with right derivatives of the data.
%   schemeData	 A structure (see below).
%
%   diss	 Local-Local Lax-Friedrichs dissipation for each node.
%   stepBound	 CFL bound on timestep for stability.
%
% schemeData is a structure containing data specific to this type of 
%   term approximation.  For this function it contains the field(s)
%
%   .grid	 Grid structure.
%   .partialFunc Function handle to extrema of \partial H(x,p) / \partial p.
%
%
% schemeData.partialFunc should have prototype
%
%         alpha = partialFunc(t, data, derivMin, derivMax, schemeData, dim)
%
%   where t and schemeData are passed directly from this function, data = y
%   has been reshaped into its original size, dim is the dimension of
%   interest, and derivMin and derivMax are both cell vectors (of length
%   grid.dim) containing the elements of the minimum and maximum costate p =
%   \grad \phi (respectively).  The range of nodes over which this minimum
%   and maximum is taken depends on the choice of dissipation function.  The
%   return value should be an array (the size of data) containing alpha_dim:
%
%    maximum_{p \in [ derivMin, derivMax ] | \partial H(x,p) / \partial p_dim |
%
%
% in the notation of OF text,
%   data	  \phi.
%   derivL	  \phi_i^- (all dimensions i are in the cell vector).
%   derivR	  \phi_i^+ (all dimensions i are in the cell vector).
%   partialFunc	  \alpha^i (dimension i is an argument to partialFunc).
%   diss	  all the terms in \hat H except the H term.


% Copyright 2004 Ian M. Mitchell (mitchell@cs.ubc.ca).
% This software is used, copied and distributed under the licensing 
%   agreement contained in the file LICENSE in the top directory of 
%   the distribution.
%
% Ian Mitchell 2/13/04


  %---------------------------------------------------------------------------
  checkStructureFields(schemeData, 'grid', 'partialFunc');

  %---------------------------------------------------------------------------
  grid = schemeData.grid;

  %---------------------------------------------------------------------------
  % Get separate costate bounds for each node.
  derivMin = cell(grid.dim, 1);
  derivMax = cell(grid.dim, 1);
  derivDiff = cell(grid.dim, 1);
  for i = 1 : grid.dim
    derivMin{i} = min(derivL{i}, derivR{i});
    derivMax{i} = max(derivL{i}, derivR{i});
    
    % Get derivative differences at each node.
    derivDiff{i} = derivR{i} - derivL{i};
  end

  %---------------------------------------------------------------------------
  % Now calculate the dissipation.  Since alpha is the effective speed of
  %   the flow, it provides the CFL timestep bound too.
  diss = 0;
  stepBoundInv = 0;
  for i = 1 : grid.dim
    alpha = feval(schemeData.partialFunc, t, data, derivMin, derivMax, ...
                  schemeData, i);
    diss = diss + (0.5 * derivDiff{i} .* alpha);
    stepBoundInv = stepBoundInv + max(alpha(:)) / grid.dx(i);
  end
  
  stepBound = 1 / stepBoundInv;
