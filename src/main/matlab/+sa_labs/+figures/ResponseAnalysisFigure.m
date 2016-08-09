classdef ResponseAnalysisFigure < symphonyui.core.FigureHandler
    % Plots statistics calculated from the response of a specified device for each epoch run.
    
    properties (SetAccess = private)
        devices
        numChannels
        activeFunctionNames
        measurementRegion
        baselineRegion
        epochData
        allMeasurementNames = {'mean','var','max','min','sum','std'};
        plotMode
        responseAxes
        epochSplitParameter
        channelNames
        analysisData % just for autocenter for now
    end
    
    properties % not private access
        
    end
    
    properties (Access = private)
        axesHandlesAnalysis
        
        markers
        spikeDetector
    end
    
    methods
        
        function obj = ResponseAnalysisFigure(devices, varargin)
            
            %             disp('figure start')
            obj = obj@symphonyui.core.FigureHandler();
            
            %             if ~iscell(activeFunctionNames)
            %                 activeFunctionNames = {activeFunctionNames};
            %             end
            
            ip = inputParser();
            ip.addParameter('activeFunctionNames', {'mean'});
            ip.addParameter('measurementRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('baselineRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('epochSplitParameter', '', @(x)ischar(x));
            ip.addParameter('plotMode', 'cartesian', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.numChannels = length(obj.devices);
            obj.activeFunctionNames = ip.Results.activeFunctionNames;
            obj.measurementRegion = ip.Results.measurementRegion;
            obj.baselineRegion = ip.Results.baselineRegion;
            obj.epochSplitParameter = ip.Results.epochSplitParameter;
            obj.plotMode = ip.Results.plotMode;
            
            obj.createUi();
            
            obj.epochData = {};
            
            obj.spikeDetector = sa_labs.util.SpikeDetector();
        end
        
        function createUi(obj)
            import appbox.*;
            %             clf(obj.figureHandle);
            %             fullBox = uix.HBoxFlex('Parent', obj.figureHandle);
            leftBox = uix.VBoxFlex('Parent',obj.figureHandle, 'Spacing',10);
            %             rightBox = uix.VBox('Parent', fullBox);
            
            %             hbox = uix.HBox( 'Parent', obj.figureHandle);
            %             plotBox = uix.VBox('Parent', hbox );
            %             controlBox = uix.VBox('Parent', hbox);
            %
            
            %             funcNames = cellfun(@func2str, obj.activeFunctionNames, 'UniformOutput', 0);
            
            obj.responseAxes = axes('Parent', leftBox);
            
            obj.axesHandlesAnalysis = [];
            rowBoxes = [];
            plotControlBoxes = [];
            measListBoxes = [];
            delPlotButtons = [];
            for measi = 1:numel(obj.activeFunctionNames)
                funcName = obj.activeFunctionNames{measi};
                
                rowBoxes(measi) = uix.HBox('Parent',leftBox);
                
                switch obj.plotMode
                    case {'cartesian', 'autocenter'}
                        obj.axesHandlesAnalysis(measi) = axes('Parent', rowBoxes(measi));
                    case 'polar'
                        obj.axesHandlesAnalysis(measi) = polaraxes('Parent', rowBoxes(measi));
                end
                
                plotControlBoxes(measi) = uix.VBox('Parent',rowBoxes(measi));
                
                thisFuncIndex = find(not(cellfun('isempty', strfind(obj.activeFunctionNames, funcName))), 1);
                
                measListBoxes(measi) = uicontrol( 'Style', 'listbox', 'Parent', plotControlBoxes(measi), ...
                    'String', obj.allMeasurementNames, 'Value',thisFuncIndex, 'Back', 'w',...
                    'Callback',{@obj.functionSelectorCallback, measi});
                
                delPlotButtons(measi) = uicontrol('Style','pushbutton', 'Parent', plotControlBoxes(measi),...
                    'String', 'del', 'Callback',{@obj.deletePlotCallback, measi});
                
                set(plotControlBoxes(measi), 'Heights', [-1, 30])
                
                set(rowBoxes(measi), 'Widths', [-3 80]);
                
            end
            
            buttonArea = uix.HButtonBox('Parent',leftBox,'ButtonSize', [100, 30]);
            newPlotButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'new plot','Callback',@obj.addPlotCallback);
            redrawButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'redraw','Callback',@obj.redrawPlotCallback);
            
            set(leftBox, 'Heights', [-1, -1*ones(1, numel(obj.activeFunctionNames)), 30])
        end
        
        function redrawPlotCallback(obj, ~, ~)
            obj.redrawPlots()
        end
        
        function functionSelectorCallback(obj, hObject, ~, measi)
            items = get(hObject,'String');
            index_selected = get(hObject,'Value');
            item_selected = items{index_selected};
            obj.activeFunctionNames{measi} = item_selected;
        end
        
        function deletePlotCallback(obj, ~, ~, measi)
            obj.activeFunctionNames(measi) = [];
            obj.createUi();
        end
        
        function addPlotCallback(obj, ~, ~)
            obj.activeFunctionNames{end+1} = obj.allMeasurementNames{1};
            obj.createUi();
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandlesAnalysis(1), t);
        end
        
        function handleEpoch(obj, epoch)
            channels = cell(obj.numChannels, 1);
            obj.channelNames = cell(obj.numChannels,1);
            
            if strcmp(obj.plotMode, 'autocenter')
                
                responseObject = epoch.getResponse(obj.devices{1}); %only one channel for now
                [signal, units] = responseObject.getData();
%                 sampleRate = responseObject.sampleRate.quantityInBaseUnits;
                
                sd = sa_labs.util.shape.ShapeData(epoch, 'online');
                
                % detect spikes here
                sp = [];
%                 if strcmp(sd.ampMode, 'Cell attached')
%                     sd.setSpikes(sp);
%                 else % whole cell
%                     sd.setResponse(signal');
%                     sd.processWholeCell();
%                 end
                
                obj.epochData{obj.epochIndex, 1} = sd;
                
            else
                
                for ci = 1:obj.numChannels
                    obj.channelNames{ci} = obj.devices{ci}.name;
                    fprintf('processing input from channel %d: %s\n',ci,obj.devices{ci}.name)
                    % process this epoch and add to epochData array
                    if ~epoch.hasResponse(obj.devices{ci})
                        disp(['Epoch does not contain a response for ' obj.devices{ci}.name]);
                        continue
                    end
                    
                    e = struct();
                    e.responseObject = epoch.getResponse(obj.devices{ci});
                    [e.signal, e.units] = e.responseObject.getData();
                    e.responseObject
                    e.sampleRate = e.responseObject.sampleRate.quantityInBaseUnits;
                    if ~isempty(obj.epochSplitParameter)
                        e.splitParameter = epoch.parameters(obj.epochSplitParameter);
                    else
                        e.splitParameter = 0; % useful when you still want parameter extraction, but no independent vars
                    end
                    msToPts = @(t)max(round(t / 1e3 * e.sampleRate), 1);
                    
                    % setup time regions for analysis
                    % remove baseline signal
                    %             if ~isempty(obj.baselineRegion)
                    %                 x1 = msToPts(obj.baselineRegion(1));
                    %                 x2 = msToPts(obj.baselineRegion(2));
                    %                 baseline = e.signal(x1:x2);
                    %                 e.signal = e.signal - mean(baseline);
                    %             end
                    
                    if ~isempty(obj.measurementRegion)
                        x1 = msToPts(obj.measurementRegion(1));
                        x2 = msToPts(obj.measurementRegion(2));
                        e.signal = e.signal(x1:x2);
                    end
                    
                    % make analysis measurements
                    e.measurements = containers.Map();
                    for i = 1:numel(obj.allMeasurementNames)
                        fcn = str2func(obj.allMeasurementNames{i});
                        result = fcn(e.signal);
                        e.measurements(obj.allMeasurementNames{i}) = result;
                    end
                    
                    channels{ci} = e;
                end
            end
            
            obj.epochData{end+1,1} = channels;
            
            obj.redrawPlots();
        end
        
        function redrawPlots(obj)
            if isempty(obj.epochData)
                return
            end
            
            colorOrder = get(groot, 'defaultAxesColorOrder');
            
            %plot the most recent response at the top
            %             clf(obj.responseAxes);
            hold(obj.responseAxes, 'off')
            for ci = 1:obj.numChannels
                color = colorOrder(mod(ci - 1, size(colorOrder, 1)) + 1, :);
                epoch = obj.epochData{end}{ci};
                quantities = epoch.responseObject.getData();
                x = (1:numel(quantities)) / epoch.responseObject.sampleRate.quantityInBaseUnits;
                y = quantities;
                plot(obj.responseAxes, x, y, 'Color', color);
                hold(obj.responseAxes, 'on')
                title(obj.responseAxes, 'previous response');
                ylabel(obj.responseAxes, epoch.units, 'Interpreter', 'none');
            end
            %             legend(obj.responseAxes, obj.channelNames , 'Location', 'east')
            hold(obj.responseAxes,'off')
            
            %             then loop through all the epochs we have and plot them
            
            
            if strcmp(obj.plotMode, 'autocenter')
                
                obj.analysisData = processShapeData(obj.epochData);

%                 clf;
%                 if strcmp(obj.shapePlotMode, 'plotSpatial_mean') && obj.epochIndex == 1
                    spm = 'temporalResponses';
%                 else
%                     spm = obj.shapePlotMode;
%                 end
                
                axes(obj.axesHandlesAnalysis(1))
                plotShapeData(obj.analysisData, spm);
                
            else
                
                for measi = 1:numel(obj.activeFunctionNames)
                    funcName = obj.activeFunctionNames{measi};
                    for ci = 1:obj.numChannels
                        
                        color = colorOrder(mod(ci - 1, size(colorOrder, 1)) + 1, :);
                        
                        if ci == 1
                            hold(obj.axesHandlesAnalysis(measi), 'off');
                        else
                            hold(obj.axesHandlesAnalysis(measi), 'on');
                        end
                        
                        % regenerate the independent axis variables
                        paramByEpoch = [];
                        for ei = 1:length(obj.epochData)
                            epoch = obj.epochData{ei}{ci};
                            paramByEpoch(ei) = epoch.splitParameter;
                        end
                        X = sort(unique(paramByEpoch));
                        
                        allMeasurementsByX = {};
                        allMeasurementsByEpoch = [];
                        for ei = 1:length(obj.epochData)
                            epoch = obj.epochData{ei}{ci};
                            whichXIndex = find(X == epoch.splitParameter);
                            thisMeas = epoch.measurements(funcName);
                            allMeasurementsByEpoch(ei) = thisMeas;
                            if length(allMeasurementsByX) < whichXIndex
                                allMeasurementsByX{whichXIndex} = thisMeas;
                            else
                                prevMeasurements = allMeasurementsByX{whichXIndex};
                                allMeasurementsByX{whichXIndex} = [prevMeasurements, thisMeas];
                            end
                        end
                        
                        Y = [];
                        Y_std = [];
                        for i = 1:length(X);
                            Y(i) = mean(allMeasurementsByX{i});
                            Y_std(i) = std(allMeasurementsByX{i});
                        end
                        
                        %                 axh = obj.axesHandlesAnalysis
                        if strcmp(obj.plotMode, 'cartesian')
                            %                     errorbar(obj.axesHandlesAnalysis(measi), X, Y, Y_std);
                            plot(obj.axesHandlesAnalysis(measi), X, Y, '-o','LineWidth',2, 'Color', color);
                            hold(obj.axesHandlesAnalysis(measi), 'on');
                            plot(obj.axesHandlesAnalysis(measi), X, Y + Y_std, '.--','LineWidth',.5, 'Color', color);
                            plot(obj.axesHandlesAnalysis(measi), X, Y - Y_std, '.--','LineWidth',.5, 'Color', color);
                            hold(obj.axesHandlesAnalysis(measi), 'off');
                        else
                            %                     axes(obj.axesHandlesAnalysis(measi));
                            X_rad = deg2rad(X);
                            X_rad(end+1) = X_rad(1);
                            Y(end+1) = Y(1);
                            Y_std(end+1) = Y_std(1);
                            polarplot(obj.axesHandlesAnalysis(measi), X_rad, Y, '-o','LineWidth',2, 'Color', color);
                            hold(obj.axesHandlesAnalysis(measi), 'on');
                            polarplot(obj.axesHandlesAnalysis(measi), X_rad, Y + Y_std, '.--','LineWidth',.5, 'Color', color);
                            polarplot(obj.axesHandlesAnalysis(measi), X_rad, Y - Y_std, '.--','LineWidth',.5, 'Color', color);
                            hold(obj.axesHandlesAnalysis(measi), 'off');
                        end
                        %                 boxplot(obj.axesHandlesAnalysis(measi), allMeasurementsByEpoch, paramByEpoch);
                        title(obj.axesHandlesAnalysis(measi), funcName);
                        
                        %                 for ei = 1:length(obj.epochData)
                        %                     epoc = obj.epochData{ei};
                        %
                        %                     measurement = epoc.measurements(measi);
                        %
                        %                     if numel(obj.markers) < measi
                        %                         colorOrder = get(groot, 'defaultAxesColorOrder');
                        %                         color = colorOrder(mod(measi - 1, size(colorOrder, 1)) + 1, :);
                        %                         obj.markers(measi) = line(1, measurement, 'Parent', obj.axesHandlesAnalysis(measi), ...
                        %                             'LineStyle', 'none', ...
                        %                             'Marker', 'o', ...
                        %                             'MarkerEdgeColor', color, ...
                        %                             'MarkerFaceColor', color);
                        %                     else
                        %                         x = get(obj.markers(measi), 'XData');
                        %                         y = get(obj.markers(measi), 'YData');
                        %                         set(obj.markers(measi), 'XData', [x x(end)+1], 'YData', [y measurement]);
                        %                     end
                    end
                end
            end
        end
        
    end
end


