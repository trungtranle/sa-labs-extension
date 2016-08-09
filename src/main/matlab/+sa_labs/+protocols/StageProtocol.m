classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0       % Background light intensity (0-1)
        offsetX = 0
        offsetY = 0
    end
       
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.BaseProtocol(obj, name);
            
            switch name
                case {'meanLevel', 'offsetX', 'offsetY', 'intensity'}
                    d.category = '1 Basic';
            end
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
               
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').play(obj.createPresentation()); % may need mods for different devices
        end
        
%         function prepareRun(obj)
%             prepareRun@sa_labs.protocols.BaseProtocol(obj);
%             
%             
% %             obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
%         end

        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            
            % it is required to have an amp stimulus for stage protocols
            device = obj.rig.getDevice(obj.chan1);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
        end
            
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeRun(obj)
            completeRun@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@sa_labs.protocols.BaseProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
        
    end
    
    methods (Access = protected)
        
        function p = um2pix(obj, um)
            stages = obj.rig.getDevices('Stage');
            if isempty(stages)
                micronsPerPixel = 1;
            else
                micronsPerPixel = stages{1}.getConfigurationSetting('micronsPerPixel');
            end
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

