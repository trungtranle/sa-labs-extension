classdef ColorResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 500                 % Spot trailing duration (ms)
        
        baseIntensity1
        baseIntensity2
        fixedContrast = 0.3;                 % contrast of fixed step each epoch, may be negative
        spotDiameter = 200              % Spot diameter (um)
        numberOfCycles = 3               % Number of cycles through all color sets
        enableSurround = false;         % use the surround instead of the mean level so mixed colors can be used
        surroundDiameter = 1000;
        
        colorChangeMode = 'ramp'
        numRampSteps = 8;
%         rampRange = [-1, ]; % contrast multipliers of baseColor values

    end
    
    properties (Hidden)
        version = 2; % changed to weber contrast
        
        spotContrasts
        currentColors
    
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'intensity2';
        
        colorChangeModeType = symphonyui.core.PropertyType('char', 'row', {'swap','ramp'});
        
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        intensity
        intensity2
    end
    
    properties (Dependent)
        contrastRange
        
        RstarIntensity2
        MstarIntensity2
        SstarIntensity2        
        plotRange
        varyingIntensityValues % The intensity of the varying color, must be in [0,1]
    end
    
    
    methods
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.StageProtocol(obj);
            
            obj.colorPattern1 = 'green';
            obj.colorPattern2 = 'uv';
        end        
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.numberOfPatterns == 1
                error('Must have > 1 pattern enabled to use color stim');
            end
            
            stepUp = 1 + obj.fixedContrast;
            stepDown = 1 - obj.fixedContrast;
            switch obj.colorChangeMode
                case 'swap'
                    obj.spotContrasts = [[stepUp,1];
                                      [1,stepUp];
                                      [stepUp,stepUp];
                                      [stepDown,1];
                                      [1,stepDown];
                                      [stepDown,stepDown];
                                      [stepUp,stepDown];
                                      [stepDown,stepUp]];
                case 'ramp'
                    rampSteps = linspace(obj.rampRange(1), obj.rampRange(2), obj.numRampSteps)';
                    obj.spotContrasts = horzcat(obj.fixedContrast * ones(obj.numRampSteps,1), rampSteps);
            end
            
        end

        function prepareEpoch(obj, epoch)

            index = mod(obj.numEpochsPrepared, size(obj.spotContrasts, 1)) + 1;
            
            if index == 1
                reorder = randperm(size(obj.spotContrasts, 1));
                obj.spotContrasts = obj.spotContrasts(reorder, :);
            end
            
            obj.currentColors = obj.baseColor .* obj.spotContrasts(index, :);

            epoch.addParameter('intensity1', obj.currentColors(1));
            epoch.addParameter('intensity2', obj.currentColors(2));
            
%             epoch.addParameter('sortColors', sum([100,1] .* round(obj.currentColors*100))); % for plot display
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            function c = surroundColor(state, backgroundColor)
                c = backgroundColor(state.pattern + 1);
            end
            
            if obj.enableSurround
                surround = stage.builtin.stimuli.Ellipse();
                surround.color = 1;
                surround.opacity = 1;
                surround.radiusX = obj.um2pix(obj.surroundDiameter/2);
                surround.radiusY = surround.radiusX;
                surround.position = canvasSize / 2;
                p.addStimulus(surround);
                surroundColorController = stage.builtin.controllers.PropertyController(surround, 'color',...
                    @(s) surroundColor(s, obj.baseColor));
                p.addController(surroundColorController);
            end
            
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = 1;
            spot.opacity = 1;
            spot.radiusX = obj.um2pix(obj.spotDiameter/2);
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = spotColor(state, onColor, backgroundColor)
                if state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3
                    c = onColor(state.pattern + 1);
                else
                    c = backgroundColor(state.pattern + 1);
                end
            end
                    
            spotColorController = stage.builtin.controllers.PropertyController(spot, 'color',...
                @(s) spotColor(s, obj.currentColors, obj.baseColor));
            p.addController(spotColorController);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = size(obj.spotContrasts, 1) * obj.numberOfCycles;
        end
        
        function intensity = get.intensity(obj)
            intensity = obj.baseColor(1);
        end
        
        function intensity = get.intensity2(obj)
            intensity = obj.baseColor(2);
        end        
        
        function varyingIntensityValues = get.varyingIntensityValues(obj)
            varyingIntensityValues = obj.contrast * obj.rampRange;
        end
        
        function plotRange = get.plotRange(obj)
            plotRange = ((obj.rampRange * obj.intensity) - obj.intensity) / obj.intensity / obj.contrast;
        end
        
        
    end
    
end

