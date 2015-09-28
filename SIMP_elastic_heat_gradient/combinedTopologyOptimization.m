function combinedTopologyOptimization(useInputArgs, w1, iterationNum)
% input args, useInputArgs = 1 if to use the input args
% w1 weight1 for weighted objective. 
% iterationNum, used to know where to output files. 

% --------------------------------------
% %% Settings
% --------------------------------------------
%clear
%clc
%close all



settings = Configuration;

% if using input args, then override some configurations. 
% if using input args, then running on the cluster, so use high resolution,
% otherwise use low resolution
 if(str2num(useInputArgs) ==1)
     settings.w1 = str2num(w1);
     settings.w2 = 1-settings.w1;
     settings.iterationNum = str2num(iterationNum)   
     settings.nelx = 80;
     settings.nely = 80;
 else
     settings.nelx = 20;
     settings.nely = 20;     
 end

% material properties Object
matProp = MaterialProperties;

% ---------------------------------
% Initialization of varriables
% ---------------------------------
designVars = DesignVars(settings);
designVars.x(1:settings.nely,1:settings.nelx) = settings.totalVolume; % artificial density of the elements
designVars.w(1:settings.nely,1:settings.nelx)  = 1; % actual volume fraction composition of each element

designVars.temp1(1:settings.nely,1:settings.nelx) = 0;
designVars.temp2(1:settings.nely,1:settings.nelx) = 0;
designVars.g1elastic(1:settings.nely,1:settings.nelx) = 0;
designVars.g1heat(1:settings.nely,1:settings.nelx) = 0;

designVars = designVars.CalcIENmatrix(settings);
designVars =  designVars.CalcElementLocation(settings);
designVars = designVars.PreCalculateXYmapToNodeNumber(settings);

% recvid=1;       %turn on or off the video recorder
% %% FEA and Elastic problem initialization
% if recvid==1
%     vidObj = VideoWriter('results_homog_level_set.avi');    %Prepare the new file for video
%     vidObj.FrameRate = 50;
%     vidObj.Quality = 100;
%     open(vidObj);
%     vid=1;
% end


masterloop = 0; 
FEACalls = 0;
change = 1.;

% START ITERATION
while change > 0.01  && masterloop<=15 && FEACalls<=150
  masterloop = masterloop + 1;
  
        % --------------------------------
        % Topology Optimization
        % --------------------------------
         if ( settings.mode == 1 || settings.mode == 3)
              for loopTop = 1:10
                   designVars = designVars.CalculateSensitivies(settings, matProp, masterloop);
                   [vol1Fraction, vol2Fraction] =  designVars.CalculateVolumeFractions(settings);
                   
                   FEACalls = FEACalls+1;
                    % normalize the sensitivies  by dividing by their max values. 
                    temp1Max =-1* min(min(designVars.temp1));
                    designVars.temp1 = designVars.temp1/temp1Max;
                    temp2Max = -1* min(min(designVars.temp2));
                    designVars.temp2 = designVars.temp2/temp2Max;

                    designVars.dc = settings.w1*designVars.temp1+settings.w2*designVars.temp2; % add the two sensitivies together using their weights 

                      % FILTERING OF SENSITIVITIES
                      [designVars.dc]   = check(settings.nelx,settings.nely,settings.rmin,designVars.x,designVars.dc);    
                    % DESIGN UPDATE BY THE OPTIMALITY CRITERIA METHOD
                      [designVars.x]    = OC(settings.nelx,settings.nely,designVars.x,settings.totalVolume,designVars.dc, designVars, settings); 
                    % PRINT RESULTS
                      %change = max(max(abs(designVars.x-designVars.xold)));
                       disp([' FEA calls.: ' sprintf('%4i',FEACalls) ' Obj.: ' sprintf('%10.4f',designVars.c) ...
                       ' Vol. 1: ' sprintf('%6.3f', vol1Fraction) ...
                        ' Vol. 2: ' sprintf('%6.3f', vol2Fraction) ...
                        ' Lambda.: ' sprintf('%6.3f',designVars.lambda1  )])

                    p = plotResults;
                    p.plotTopAndFraction(designVars,  settings, matProp, FEACalls); % plot the results. 
              end
         end
        
      % --------------------------------   
      % Volume fraction optimization
      % --------------------------------
        if ( settings.mode ==2 || settings.mode ==3)
            for loopVolFrac = 1:10
                   designVars = designVars.CalculateSensitivies( settings, matProp, masterloop);
                   FEACalls = FEACalls+1;
                   
                  % for j = 1:5
                      [vol1Fraction, vol2Fraction] =  designVars.CalculateVolumeFractions(settings);

                      totalVolLocal = vol1Fraction+ vol2Fraction;
                      fractionCurrent_V1Local = vol1Fraction/totalVolLocal;
                      targetFraction_v1 = settings.v1/(settings.v1+settings.v2);
                      
                      % Normalize the sensitives. 
                      temp1Max = max(max(designVars.g1elastic));
                      designVars.g1elastic = designVars.g1elastic/temp1Max;
                      temp2Max = max(max(designVars.g1heat));
                      designVars.g1heat = designVars.g1heat/temp2Max;

                      g1 = settings.w1*designVars.g1elastic+settings.w2*designVars.g1heat; % Calculate the weighted volume fraction change sensitivity.               
                      G1 = g1 - designVars.lambda1 +1/(designVars.mu1)*( targetFraction_v1-fractionCurrent_V1Local); % add in the lagrangian             
                      designVars.w = designVars.w+settings.timestep*G1; % update the volume fraction.

                     designVars.w = max(min( designVars.w,1),0);    % Don't allow the    vol fraction to go above 1 or below 0    
                     designVars.lambda1 =  designVars.lambda1 -1/(designVars.mu1)*(targetFraction_v1-fractionCurrent_V1Local)*settings.volFractionDamping;
                     
                   %  oldLambda1 =  designVars.lambda1;
                     
                   % change = oldLambda1-designVars.lambda1
                     
                %   end
                  % PRINT RESULTS
                  %change = max(max(abs(designVars.x-designVars.xold)));
                  p = plotResults;
                    p.plotTopAndFraction(designVars, settings, matProp,FEACalls ); % plot the results. 

                  disp([' FEA calls.: ' sprintf('%4i',FEACalls) ' Obj.: ' sprintf('%10.4f',designVars.c) ...
                       ' Vol. 1: ' sprintf('%6.3f', vol1Fraction) ...
                        ' Vol. 2: ' sprintf(    '%6.3f', vol2Fraction) ...
                        ' Lambda.: ' sprintf('%6.3f',designVars.lambda1  )])
            end
        end
end 

% if recvid==1
%          close(vidObj);  %close video

%%%%%%%%%% OPTIMALITY CRITERIA UPDATE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xnew]=OC(nelx,nely,x,volfrac,dc ,designVar, settings)  
l1 = 0; l2 = 100000; move = 0.2;
while (l2-l1 > 1e-4)
  lmid = 0.5*(l2+l1);
  xnew = max(0.001,max(x-move,min(1.,min(x+move,x.*sqrt(-dc./lmid)))));
  
%   desvars = max(VOID, max((x - move), min(SOLID,  min((x + move),(x * (-dfc / lammid)**self.eta)**self.q))))

%[volume1, volume2] = designVar.CalculateVolumeFractions(settings);
%currentvolume=volume1+volume2;
 
  %if currentvolume - volfrac > 0;
  if sum(sum(xnew)) - volfrac*nelx*nely > 0;
    l1 = lmid;
  else
    l2 = lmid;
  end
end
%%%%%%%%%% MESH-INDEPENDENCY FILTER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [dcn]=check(nelx,nely,rmin,x,dc)
dcn=zeros(nely,nelx);
for i = 1:nelx
  for j = 1:nely
    sum=0.0; 
    for k = max(i-floor(rmin),1):min(i+floor(rmin),nelx)
      for l = max(j-floor(rmin),1):min(j+floor(rmin),nely)
        fac = rmin-sqrt((i-k)^2+(j-l)^2);
        sum = sum+max(0,fac);
        dcn(j,i) = dcn(j,i) + max(0,fac)*x(l,k)*dc(l,k);
      end
    end
    dcn(j,i) = dcn(j,i)/(x(j,i)*sum);
  end
end
%%%%%%%%%% FE-ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [KE]=lkHeat

KE= [0.6667   -0.1667   -0.3333   -0.1667;
   -0.1667    0.6667   -0.1667   -0.3333;
   -0.3333   -0.1667    0.6667   -0.1667;
   -0.1667   -0.3333   -0.1667    0.6667];

% function [U]=FE(nelx,nely,x,penal,F,fixeddofs)
% [KE] = lk; 
% K = sparse(2*(nelx+1)*(nely+1), 2*(nelx+1)*(nely+1));
% %F = sparse(2*(nely+1)*(nelx+1),1);
% U = zeros(2*(nely+1)*(nelx+1),1);
% for elx = 1:nelx
%   for ely = 1:nely
%     n1 = (nely+1)*(elx-1)+ely; 
%     n2 = (nely+1)* elx   +ely;
%     edof = [2*n1-1; 2*n1; 2*n2-1; 2*n2; 2*n2+1; 2*n2+2; 2*n1+1; 2*n1+2];
%     K(edof,edof) = K(edof,edof) + x(ely,elx)^penal*KE;
%   end
% end
% % DEFINE LOADS AND SUPPORTS (HALF MBB-BEAM)
% % F(2,1) = -1;
% % fixeddofs   = union([1:2:2*(nely+1)],[2*(nelx+1)*(nely+1)])
% alldofs     = [1:2*(nely+1)*(nelx+1)];
% freedofs    = setdiff(alldofs,fixeddofs);
% % SOLVING
% U(freedofs,:) = K(freedofs,freedofs) \ F(freedofs,:);      
% U(fixeddofs,:)= 0;
%%%%%%%%%% ELEMENT STIFFNESS MATRIX %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [KE]=lk
% 
% KE= [0.6667   -0.1667   -0.3333   -0.1667;
%    -0.1667    0.6667   -0.1667   -0.3333;
%    -0.3333   -0.1667    0.6667   -0.1667;
%    -0.1667   -0.3333   -0.1667    0.6667];