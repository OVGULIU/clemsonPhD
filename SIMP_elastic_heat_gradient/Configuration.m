classdef Configuration
    
    properties
        % --------------------------------------
        % %% Settings
        % --------------------------------------------
        nelx = 40; % 40 # of elements in the x direcction
        nely = 20; % 18 number of elements in the y direction
        penal = 3; % penality used for the SIMP method
        rmin = 2; % smoothing radius for sensitivity smoothing.
        % Optimization mode and configurations
        mode =3; % 1 = topology only, 2 = material optimization only. 3 = both        
        referenceTemperature = 0; % for thermal expansion, assume that there is not strain when at this temperature. 
        addThermalExpansion = 0; % Set to 1 to incorporate thermal expansion       
        timestep = 0.1; % time step for the volume fraction update algorithm
        volFractionDamping = 0.1;
        iterationsPerPlot = 5;
        w1 = 0; % weight elastic for multi-objective
        w2;        
        voidMaterialDensityCutOff = 0.3; % everything below this density is considered void.
        % Plotting information
        doPlotVolFractionDesignVar = 0;
        doPlotTopologyDesignVar = 1;
        doPlotHeat = 1;
        doPlotHeatSensitivityTopology = 1;
        doPlotStress = 0;
        doPlotFinal = 0;
        doPlotMetrics = 1;
        doSaveDesignVarsToCSVFile = 0; % set to 1 to write plotFinal csv file instead      
        v1 = 1;
        v2 = 1;
        totalVolume; % = v1+v2;  
        iterationNum=0; %  used for parallel computing. 
        % not much faster. 
        useGPU = 0; % set to 1 to try to solve matrix using gpu        
        % -----------------
        % Use different mixture rules for effective elastic properteis
        % 1. Simple linear interpolation, Vigot rule of miztures E = w(E1)*(1-w)*E2
        % 2. Hashin�Shtrikam law
        % 3. Reuss -rule, 1/E = w/E1+(1-w)/E2 (not implemented yet)
        % 4. Mori and Tanaka, metal ceramic composite
        % ---------------------        
        elasticMaterialInterpMethod = 1;         
        % -----------------
        % Use different mixture rules for effective Heat properteis
        % 1. Simple linear interpolation, Vigot rule of miztures E = w(E1)*(1-w)*E2       
        % 3. Reuss -rule, 1/E = w/E1+(1-w)/E2 (not implemented yet)
        % 4. Kingery's, metal ceramic composite
        % ---------------------        
        heatMaterialInterpMethod = 1;         
    end    
    
    methods
        
        function obj = Configuration()
             if obj.mode ==1    
                obj.doPlotHeat = 1;
                obj.v1 = 0.2; % fraction of material 1 to use
                obj.v2 = 0.2; % fraction of material 2 to use
                 obj.doPlotHeat = 0;
            elseif obj.mode ==2
                obj.v1 = 0.5; % fraction of material 1 to use
                obj.v2 = 0.5; % fraction of material 2 to use
                 obj.doPlotHeat = 0;
                obj. plotFinal = 1;
                obj. plotToCSVFile = 0;

            elseif obj.mode ==3
                 obj.v1 = 0.20; % fraction of material 1 to use
                 obj.v2 = 0.40; % fraction of material 2 to use
               
             end
            
            obj.w2  = 1- obj.w1; % weight heat transfer
            obj.totalVolume = obj.v1+obj.v2;            
        end
        
    end
end