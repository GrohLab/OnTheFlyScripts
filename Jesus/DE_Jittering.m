% 30.08.19 Jittering analysis by using the Data Explorer.
clearvars
%% Load the data
% Choosing the working directory
dataDir = uigetdir('E:\Data\VPM\Jittering\Silicon Probes\',...
    'Choose a working directory');
%%
if dataDir == 0
    return
end
% Creating the figure directory
figureDir = fullfile(dataDir,'Figures\');
if ~mkdir(figureDir)
    fprintf(1,'There was an issue with the figure folder...\n');
end
if isempty(dir(fullfile(dataDir, '*analysis.mat')))
    pgObj = ProtocolGetter(dataDir);
    pgObj.getConditionSignals;
    pgObj.getSignalEdges;
    pgObj.getFrequencyEdges;
    pgObj.pairStimulus;
    pgObj.saveConditions;
end
% Loading the necessary files
if ~loadTriggerData(dataDir)
    fprintf(1,'Not possible to load all the necessary variables\n')
    return
end
fnOpts = {'UniformOutput', false};
spk_file_vars = {'spike_times','gclID','Nt','Ns','goods'};
%% Constructing the helper 'global' variables

spkPttrn = "%s_Spike_Times.mat";
spk_path = fullfile(dataDir, sprintf(spkPttrn, expName));
if ~exist(spk_path, "file")
    % Number of total samples
    Ns = structfun(@numel,Triggers); Ns = min(Ns(Ns>1));
    % Total duration of the recording
    Nt = Ns/fs;
    % Useless clusters (labeled as noise or they have very low firing rate)
    badsIdx = cellfun(@(x) x==3,sortedData(:,3));
    bads = find(badsIdx);
    totSpkCount = cellfun(@numel,sortedData(:,2));
    clusterSpikeRate = totSpkCount/Nt;
    silentUnits = clusterSpikeRate < 0.1;
    bads = union(bads,find(silentUnits));
    goods = setdiff(1:size(sortedData,1),bads);
    badsIdx = badsIdx | silentUnits;
    if ~any(ismember(clInfo.Properties.VariableNames,'ActiveUnit'))
        clInfo = addvars(clInfo,~badsIdx,'After',1,...
            'NewVariableNames','ActiveUnit');
        writeClusterInfo(clInfo, fullfile(dataDir, 'cluster_info.tsv'), 1);
    end
    gclID = sortedData(goods,1);
    badsIdx = StepWaveform.subs2idx(bads,size(sortedData,1));
    spike_times = sortedData(~badsIdx, 2);
    save(spk_path, spk_file_vars{:})
else
    % Subscript column vectors for the rest good clusters
    load(spk_path, spk_file_vars{:})
end
spkSubs = cellfun(@(x) round(x.*fs),spike_times, fnOpts{:});
% Number of good clusters
Ncl = numel(goods);
% Redefining the stimulus signals from the low amplitude to logical values
whStim = {'piezo','whisker','mech','audio'};
cxStim = {'laser','light'};
lfpRec = {'lfp','s1','cortex','s1lfp'};
trigNames = fieldnames(Triggers);
numTrigNames = numel(trigNames);
ctn = 1;
continuousSignals = cell(numTrigNames,1);
continuousNameSub = zeros(size(trigNames));
while ctn <= numTrigNames
    if contains(trigNames{ctn},whStim,'IgnoreCase',true)
        continuousSignals{ctn} = Triggers.(trigNames{ctn});
        continuousNameSub(ctn) = ctn;
    end
    if contains(trigNames{ctn},cxStim,'IgnoreCase',true)
        continuousSignals{ctn} = Triggers.(trigNames{ctn});
        continuousNameSub(ctn) = ctn;
    end
    if contains(trigNames{ctn},lfpRec,'IgnoreCase',true)
        continuousSignals{ctn} = Triggers.(trigNames{ctn});
        continuousNameSub(ctn) = ctn;
    end
    ctn = ctn + 1;
end
continuousSignals(continuousNameSub == 0) = [];
continuousNameSub(continuousNameSub == 0) = [];
trigNames = trigNames(continuousNameSub);
fnOpts = {'UniformOutput', false};
%% Inter-spike intervals
isiFile = fullfile(dataDir,[expName,'_ISIvars.mat']);
if ~exist(isiFile,'file')
    spkSubs2 = cellfun(@(x) round(x.*fs), sortedData(goods,2),...
        'UniformOutput', false);
    ISIVals = cellfun(@(x) [x(1)/fs; diff(x)/fs], spkSubs2,...
        'UniformOutput', 0);
    NnzvPcl = cellfun(@numel,ISIVals);
    Nnzv = sum(NnzvPcl);
    rows = cell2mat(arrayfun(@(x,y) repmat(x,y,1), (1:Ncl)', NnzvPcl,...
        'UniformOutput', 0));
    cols = cell2mat(spkSubs2);
    vals = cell2mat(ISIVals);
    try
        ISIspar = sparse(rows, cols, vals);
    catch
        fprintf(1, 'Not possible to create such a big array')
    end
else
    % load(isiFile,'ISIspar')
end
% ISIsignal = zeros(Ncl,Ns,'single');
% for ccl = 1:Ncl
%     ISIsignal(ccl,spkSubs2{ccl}) = ISIVals{ccl};
% end
%% User controlling variables
% Time lapse, bin size, and spontaneous and response windows
promptStrings = {'Viewing window (time lapse) [s]:','Response window [s]',...
    'Bin size [s]:'};
defInputs = {'-0.1, 0.1', '0.002, 0.05', '0.001'};
answ = inputdlg(promptStrings,'Inputs', [1, 30],defInputs);
if isempty(answ)
    fprintf(1,'Cancelling...\n')
    return
else
    timeLapse = str2num(answ{1}); %#ok<*ST2NM>
    if numel(timeLapse) ~= 2
        timeLapse = str2num(inputdlg('Please provide the time window [s]:',...
            'Time window',[1, 30], '-0.1, 0.1'));
        if isnan(timeLapse) || isempty(timeLapse)
            fprintf(1,'Cancelling...')
            return
        end
    end
    responseWindow = str2num(answ{2});
    binSz = str2double(answ(3));
end
fprintf(1,'Time window: %.2f - %.2f ms\n',timeLapse*1e3)
fprintf(1,'Response window: %.2f - %.2f ms\n',responseWindow*1e3)
fprintf(1,'Bin size: %.3f ms\n', binSz*1e3)
sponAns = questdlg('Mirror the spontaneous window?','Spontaneous window',...
    'Yes','No','Yes');
spontaneousWindow = -flip(responseWindow);
if strcmpi(sponAns,'No')
    spontPrompt = "Time before the trigger in [s] (e.g. -0.8, -0.6 s)";
    sponDef = string(sprintf('%.3f, %.3f',spontaneousWindow(1),...
        spontaneousWindow(2)));
    sponStr = inputdlg(spontPrompt, 'Inputs',[1,30],sponDef);
    if ~isempty(sponStr)
        spontAux = str2num(sponStr{1});
        if length(spontAux) ~= 2 || spontAux(1) > spontAux(2) || ...
                spontAux(1) < timeLapse(1)
            fprintf(1, 'The given input was not valid.\n')
            fprintf(1, 'Keeping the mirror version!\n')
        else
            spontaneousWindow = spontAux;
        end
    end
end
fprintf(1,'Spontaneous window: %.2f to %.2f ms before the trigger\n',...
    spontaneousWindow(1)*1e3, spontaneousWindow(2)*1e3)
%% Condition triggered stacks
condNames = arrayfun(@(x) x.name,Conditions,'UniformOutput',false);
condGuess = contains(condNames, 'whiskerall', 'IgnoreCase', true);
% Choose the conditions to create the stack upon
[chCond, iOk] = listdlg('ListString',condNames,'SelectionMode','single',...
    'PromptString',...
    'Choose the condition which has all whisker triggers: (one condition)',...
    'InitialValue', find(condGuess), 'ListSize', [350, numel(condNames)*16]);
if ~iOk
    fprintf(1,'Cancelling...\n')
    return
end

% Select the onset or the offset of a trigger
fprintf(1,'Condition ''%s''\n', Conditions(chCond).name)
onOffStr = questdlg('Trigger on the onset or on the offset?','Onset/Offset',...
    'on','off','Cancel','on');
if strcmpi(onOffStr,'Cancel')
    fprintf(1,'Cancelling...\n')
    return
end

%% Constructing the stack out of the user's choice
% discStack - dicrete stack has a logical nature
% cst - continuous stack has a numerical nature
% Both of these stacks have the same number of time samples and trigger
% points. They differ only in the number of considered events.
[discStack, cst] = getStacks(false,Conditions(chCond).Triggers,onOffStr,...
    timeLapse,fs,fs,spkSubs,continuousSignals);
discStack(2,:,:) = [];
% ISI stack
try
    [~, isiStack] = getStacks(spkLog,Conditions(chCond).Triggers, onOffStr,...
        timeLapse,fs,fs,[],ISIspar);
catch
    fprintf(1,'Not able to do the ISI stack\n')
end
% [dst, cst] = getStacks(spkLog, allWhiskersPlusLaserControl,...
%     'on',timeLapse,fs,fs,[spkSubs;{Conditions(allLaserStimulus).Triggers}],...
%     continuousSignals);
if ~exist(isiFile,'file') && exist('ISIspar','var')
    fprintf(1,'Saving the inter-spike intervals for each cluster... ');
    save(isiFile,'ISIspar','ISIVals','-v7.3')
    fprintf(1,'Done!\n')
end
% Number of clusters + the piezo as the first event + the laser as the last
% event, number of time samples in between the time window, and number of
% total triggers.
[Ne, Nt, NTa] = size(discStack);
% Computing the time axis for the stack
tx = (0:Nt - 1)/fs + timeLapse(1);
%% Considered conditions selection
% Choose the conditions to look at
auxSubs = setdiff(1:numel(condNames), chCond);
ccondNames = condNames(auxSubs);
[cchCond, iOk] = listdlg('ListString',ccondNames,'SelectionMode','multiple',...
    'PromptString',...
    'Choose the condition(s) to look at (including whiskers):',...
    'ListSize', [350, numel(condNames)*16]);
if ~iOk
    fprintf(1,'Cancelling...\n')
    return
end

% Select the onset or the offset of a trigger
fprintf(1,'Condition(s):\n')
fprintf('- ''%s''\n', Conditions(auxSubs(cchCond)).name)

% Subscript to indicate the conditions with all whisker stimulations, and
% combinations
allWhiskerStimulus = chCond;
consideredConditions = auxSubs(cchCond);

Nccond = length(consideredConditions);
%% Boolean flags
delayFlags = false(NTa,Nccond);
counter2 = 1;
for ccond = consideredConditions
    delayFlags(:,counter2) = ismember(Conditions(chCond).Triggers(:,1),...
        Conditions(ccond).Triggers(:,1));
    counter2 = counter2 + 1;
end
Na = sum(delayFlags,1);

%% Computing which units/clusters/putative neurons respond to the stimulus
% Logical indices for fetching the stack values
sponActStackIdx = tx >= spontaneousWindow(1) & tx <= spontaneousWindow(2);
respActStackIdx = tx >= responseWindow(1) & tx <= responseWindow(2);
% The spontaneous activity of all the clusters, which are allocated from
% the second until one before the last row, during the defined spontaneous
% time window, and the whisker control condition.

timeFlags = [sponActStackIdx;respActStackIdx];
% Time window
delta_t = diff(responseWindow);
% Statistical tests
[Results, Counts] = statTests(discStack, delayFlags, timeFlags);

indCondSubs = cumsum(Nccond:-1:1);
consCondNames = condNames(consideredConditions);
% Plotting statistical tests
[Figs, Results] = scatterSignificance(Results, Counts, consCondNames,...
    delta_t, gclID);
configureFigureToPDF(Figs);
stFigBasename = fullfile(figureDir,[expName,' ']);
stFigSubfix = sprintf(' Stat RW%.1f-%.1fms SW%.1f-%.1fms',...
    responseWindow(1)*1e3, responseWindow(2)*1e3, spontaneousWindow(1)*1e3,...
    spontaneousWindow(2)*1e3);
ccn = 1;

for cc = 1:numel(Figs)
    if ~ismember(cc, indCondSubs)
        altCondNames = strsplit(Figs(cc).Children(2).Title.String,': ');
        altCondNames = altCondNames{2};
    else
        altCondNames = consCondNames{ccn};
        ccn = ccn + 1;
    end
    stFigName = [stFigBasename, altCondNames, stFigSubfix];
    saveFigure(Figs(cc), stFigName)
end
[rclIdx, H, zH] = getSignificantFlags(Results);
Htc = sum(H,2);
CtrlCond = contains(consCondNames,'control','IgnoreCase',true);
if ~nnz(CtrlCond)
    CtrlCond = true(size(H,2),1);
end
wruIdx = all(H(:,CtrlCond),2);
Nwru = nnz(wruIdx);
%% Configuration structure
configStructure = struct('Experiment', fullfile(dataDir,expName),...
    'Viewing_window_s', timeLapse, 'Response_window_s', responseWindow,...
    'Spontaneous_window_s', spontaneousWindow, 'BinSize_s', binSz, ...
    'Trigger', struct('Name', condNames{chCond}, 'Edge',onOffStr), ...
    'ConsideredConditions',{consCondNames});
%% Results directory
fprintf('%d responding clusters:\n', Nwru);
fprintf('- %s\n',gclID{wruIdx})
resDir = fullfile(dataDir, 'Results');
if ~exist(resDir, 'dir')
    if ~mkdir(resDir)
        fprintf(1, "There was an issue creating %s!\n", resDir)
        fprintf(1, "Saving results in main directory")
        resDir = dataDir;
    end
end
%% Map prototype
CC_key = '';
for cc = 1:length(consCondNames)-1
    CC_key = [CC_key, sprintf('%s-', consCondNames{cc})]; %#ok<AGROW>
end
CC_key = [CC_key, sprintf('%s', consCondNames{end})];
C_key = condNames{chCond};
SW_key = sprintf('SW%.2f-%.2f', spontaneousWindow*1e3);
RW_key = sprintf('RW%.2f-%.2f', responseWindow*1e3);
O_key = sprintf('%s', onOffStr);
current_key = {RW_key, SW_key, C_key, CC_key, O_key};

mapPttrn = "Map %s.mat";
resMap_path = fullfile(resDir, sprintf(mapPttrn, expName));
nmFlag = true;
try
    resMap = MapNested();
catch
    fprintf(1, "'RolandRitt/Matlab-NestedMap' toolbox not installed! ")
    fprintf(1, "Cannot create multi-key map!\n")
    nmFlag = false;
end
if nmFlag
    if exist(resMap_path, "file")
        resMap_vars = load(resMap_path,"resMap", "keyCell");
        resMap = resMap_vars.resMap;
        keyCell = resMap_vars.keyCell; clearvars respMap_vars
        try
            % Testing if the current key combination exists
            resMap_value = resMap(current_key{:});
            clearvars resMap_value
        catch
            fprintf(1, "Saving responsive unit flags\n")
            resMap(current_key{:}) = wruIdx;
            keyCell = cat(1, keyCell, current_key);
        end
    else
        fprintf(1, "Saving responsive unit flags\n")
        resMap(current_key{:}) = wruIdx;
        keyCell = current_key;
    end
    save(resMap_path, "resMap", "keyCell")
end

%% Saving statistical results
% Not the best name, but works for now...
resPttrn = 'Res VW%.2f-%.2f ms %s ms %s ms %s.mat';
resFN = sprintf(resPttrn, timeLapse*1e3, RW_key, SW_key, C_key);
resFP = fullfile(resDir, resFN);
if ~exist(resFP, "file")
    save(resFP, "Results", "Counts", "configStructure", "gclID")
end
%% Filter question
filterIdx = true(Ne,1);
ansFilt = questdlg('Would you like to filter for significance?','Filter',...
    'Yes','No','Yes');
filtStr = 'unfiltered';
if strcmp(ansFilt,'Yes')
    filterIdx = [true; wruIdx];
    filtStr = 'filtered';
end
%% Getting the relative spike times for the whisker responsive units (wru)
% For each condition, the first spike of each wru will be used to compute
% the standard deviation of it.

% cellLogicalIndexing = @(x,idx) x(idx);
isWithinResponsiveWindow =...
    @(x) x > responseWindow(1) & x < responseWindow(2);

rst = arrayfun(@(x) getRasterFromStack(discStack, ~delayFlags(:,x), ...
    filterIdx(3:end), timeLapse, fs, true, true), 1:size(delayFlags,2), ...
    fnOpts{:});
relativeSpkTmsStruct = struct('name', consCondNames, 'SpikeTimes', rst);
firstSpkStruct = getFirstSpikeInfo(relativeSpkTmsStruct, configStructure);
relSpkFileName =...
    sprintf('%s RW%.2f - %.2f ms SW%.2f - %.2f ms VW%.2f - %.2f ms %s (%s) exportSpkTms.mat',...
    expName, responseWindow*1e3, spontaneousWindow*1e3,...
    timeLapse*1e3, Conditions(chCond).name, filtStr);
if ~exist(relSpkFileName,'file')
    save(fullfile(dataDir, relSpkFileName), 'relativeSpkTmsStruct',...
        'configStructure', 'firstSpkStruct')
end

%% Ordering PSTH

orderedStr = 'ID ordered';
dans = questdlg('Do you want to order the PSTH other than by IDs?',...
    'Order', 'Yes', 'No', 'No');
ordSubs = 1:nnz(filterIdx(2:Ncl+1));
pclID = gclID(filterIdx(2:Ncl+1));
if strcmp(dans, 'Yes')
    if ~exist('clInfo','var')
        clInfo = getClusterInfo(fullfile(dataDir,'cluster_info.tsv'));
    end
    % varClass = varfun(@class,clInfo,'OutputFormat','cell');
    [ordSel, iOk] = listdlg('ListString', clInfo.Properties.VariableNames,...
        'SelectionMode', 'multiple');
    orderedStr = [];
    ordVar = clInfo.Properties.VariableNames(ordSel);
    for cvar = 1:numel(ordVar)
        orderedStr = [orderedStr, sprintf('%s ',ordVar{cvar})]; %#ok<AGROW>
    end
    orderedStr = [orderedStr, 'ordered'];

    if ~strcmp(ordVar,'id')
        [~,ordSubs] = sortrows(clInfo(pclID,:),ordVar);
    end
end

%% Plot PSTH
goodsIdx = logical(clInfo.ActiveUnit);
if exist('Triggers', 'var')
    csNames = fieldnames(Triggers);
end
Nbn = diff(timeLapse)/binSz;
if (Nbn - round(Nbn)) ~= 0
    Nbn = ceil(Nbn);
end
PSTH = zeros(nnz(filterIdx) - 1, Nbn, Nccond);
psthTx = (0:Nbn-1) * binSz + timeLapse(1);
psthFigs = gobjects(Nccond,1);
Ntc = size(cst,2);
for ccond = 1:Nccond
    figFileName =...
        sprintf('%s %s VW%.1f-%.1f ms B%.1f ms RW%.1f-%.1f ms SW%.1f-%.1f ms %sset %s (%s)',...
        expName, consCondNames{ccond}, timeLapse*1e3, binSz*1e3,...
        responseWindow*1e3, spontaneousWindow*1e3, onOffStr, orderedStr,...
        filtStr);
    [PSTH(:,:,ccond), trig, sweeps] = getPSTH(discStack(filterIdx,:,:),timeLapse,...
        ~delayFlags(:,ccond),binSz,fs);
    if exist('cst', 'var') && ~isempty(cst)
        stims = mean(cst(:,:,delayFlags(:,ccond)),3);
        stims = stims - median(stims,2);
        for cs = 1:size(stims,1)
            if abs(log10(var(stims(cs,:),[],2))) < 13
                [m,b] = lineariz(stims(cs,:),1,0);
                stims(cs,:) = m*stims(cs,:) + b;
            else
                stims(cs,:) = zeros(1,Ntc);
            end
        end
    else
        stims = zeros(1, Ntc);
    end
    psthFigs(ccond) = plotClusterReactivity(PSTH(ordSubs,:,ccond), trig,...
        sweeps, timeLapse, binSz, [consCondNames(ccond); pclID(ordSubs)],...
        strrep(expName,'_',' '), stims, csNames);
    psthFigs(ccond).Children(end).YLabel.String =...
        [psthFigs(ccond).Children(end).YLabel.String,...
        sprintf('^{%s}',orderedStr)];
    figFilePath = fullfile(figureDir, figFileName);
    saveFigure(psthFigs(ccond), figFilePath);
end

%% Log PSTH -- Generalise this part!!
Nbin = 64;
ncl = size(relativeSpkTmsStruct(1).SpikeTimes,1);

logPSTH = getLogTimePSTH(relativeSpkTmsStruct, true(ncl,1),...
    'tmWin', responseWindow, 'Offset', 2.5e-3, 'Nbin', Nbin,...
    'normalization', 'fr');
logFigs = plotLogPSTH(logPSTH);
% Saving the figures
lpFigName = sprintf('%s Log-likePSTH %s %d-conditions RW%.1f-%.1f ms NB%d (%s)',...
    expName, logPSTH.Normalization, Nccond, responseWindow*1e3, Nbin, filtStr);
saveFigure(logFigs(1), fullfile(figureDir, lpFigName))
if numel(logFigs) > 1
    lmiFigName = sprintf('%s LogMI %d-conditions RW%.1f-%.1f ms NB%d (%s)',...
        expName, Nccond, responseWindow*1e3, Nbin, filtStr);
    saveFigure(logFigs(2), fullfile(figureDir, lmiFigName))
end

%% Spontaneous firing rates
trainDuration = 1;
AllTriggs = unique(cat(1, Conditions.Triggers), 'rows', 'sorted');
[spFr, ~, SpSpks, spIsi] = getSpontFireFreq(spkSubs, AllTriggs,...
    [0, Inf], fs, trainDuration + delta_t + responseWindow(1));
%% Cluster population proportions
% Responsive and unresponsive cells, significantly potentiated or depressed
% and unmodulated.
fnOpts = {'UniformOutput', false};
hsOpts = {'BinLimits', [-1,1], 'NumBins', 32,...
    'Normalization', 'probability', 'EdgeColor', 'none', 'DisplayName'};
axOpts = {'Box', 'off', 'Color', 'none'};
evFr = cellfun(@(x) mean(x,2)./diff(responseWindow), Counts(:,2),fnOpts{:});
evFr = cat(2, evFr{:});
getMI = @(x) diff(x, 1, 2)./sum(x, 2);
MIevok = getMI(evFr);
Nrn = sum(wruIdx); Ntn = size(wruIdx,1);
signMod = Results(1).Activity(2).Pvalues < 0.05;
potFlag = MIevok > 0;
Nrsn = sum(wruIdx & signMod); Nrsp = sum(wruIdx & signMod & potFlag);
% All spikes in a cell format
if size(spkSubs,1) < size(gclID,1)
    spkSubs = cat(1, {round(sortedData{goods(1),2}*fs)}, spkSubs);
end
NaCount = 1;
% Experiment firing rate and ISI per considered condition
spFrC = zeros(Ncl, size(consideredConditions,2), 'single');
econdIsi = cell(Ncl, size(consideredConditions,2));
econdSpks = econdIsi;
trainDuration = 1;
for ccond = consideredConditions
    itiSub = mean(diff(Conditions(ccond).Triggers(:,1)));
    consTime = [Conditions(ccond).Triggers(1,1) - round(itiSub/2),...
        Conditions(ccond).Triggers(Na(NaCount),2) + round(itiSub/2)]...
        ./fs;
    [spFrC(:,NaCount),~, econdSpks(:,NaCount), econdIsi(:,NaCount)] =...
        getSpontFireFreq(spkSubs, Conditions(ccond).Triggers,...
        consTime, fs, trainDuration + delta_t + responseWindow(1));
    NaCount = NaCount + 1;
end
MIspon = getMI(spFrC); SNr = evFr./spFrC;
%% Plot proportional pies
clrMap = lines(2); clrMap([3,4],:) = [0.65;0.8].*ones(2,3);
% Responsive and non responsive clusters
respFig = figure("Color", "w");
pie([Ntn-Nrn, Nrn], [0, 1], {'Unresponsive', 'Responsive'});
pObj = findobj(respFig, "Type", "Patch");
arrayfun(@(x) set(x, "EdgeColor", "none"), pObj);
arrayfun(@(x) set(pObj(x), "FaceColor", clrMap(x+2,:)), 1:length(pObj))
propPieFileName = fullfile(figureDir,...
    sprintf("Whisker responsive proportion pie RW%.1f - %.1f ms (%dC, %dR)",...
    responseWindow*1e3, [Ntn-Nrn, Nrn]));
saveFigure(respFig, propPieFileName, 1);
% Potentiated, depressed and unmodulated clusters pie
if Nccond == 2
    potFig = figure("Color", "w");
    pie([Nrn - Nrsn, Nrsp, Nrsn - Nrsp], [0, 1, 1], {'Non-modulated', ...
        'Potentiated', 'Depressed'}); % set(potFig, axOpts{:})
    pObj = findobj(potFig, "Type", "Patch");
    arrayfun(@(x) set(x, "EdgeColor", "none"), pObj);
    arrayfun(@(x) set(pObj(x), "FaceColor", clrMap(x,:)), 1:length(pObj))
    modPropPieFigFileName = fullfile(figureDir,...
        sprintf("Modulation proportions pie RW%.1f - %.1f ms (%dR, %dP, %dD)",...
        responseWindow*1e3, Nrn - Nrsn, Nrsp, Nrsn - Nrsp));
    saveFigure(potFig, modPropPieFigFileName, 1)
    % Modulation index histogram
    MIFig = figure; histogram(MIspon, hsOpts{:}, "Spontaneous"); hold on;
    histogram(MIevok, hsOpts{:}, "Evoked"); set(gca, axOpts{:});
    title("Modulation index distribution"); xlabel("MI");
    ylabel("Cluster proportion"); lgnd = legend("show");
    set(lgnd, "Box", "off", "Location", "best")
    saveFigure(MIFig, fullfile(figureDir,...
        "Modulation index dist evoked & after induction"), 1)
end
%% Get significantly different clusters
gcans = questdlg(['Do you want to get the waveforms from the',...
    ' ''responding'' clusters?'], 'Waveforms', 'Resp only', 'All', 'None', ...
    'None');
switch gcans
    case 'Resp only'
        clWaveforms = getClusterWaveform(gclID(wruIdx), dataDir);
    case 'All'
        clWaveforms = getClusterWaveform(gclID, dataDir);
    case 'None'
        fprintf(1, 'You can always get the waveforms later\n')
end

%% Addition mean signals to the Conditions variable (Unused)
%{
if ~isfield(Conditions,'Stimulus') ||...
        any(arrayfun(@(x) isempty(x.Stimulus), Conditions(consideredConditions)))
    fprintf(1,'Writting the stimulus raw signal into Conditions variable:\n')
    whFlag = contains(trigNames, whStim, 'IgnoreCase', 1);
    lrFlag = contains(trigNames, cxStim, 'IgnoreCase', 1);
    cdel = 1;
    for cc = consideredConditions
        fprintf(1,'- %s\n', Conditions(cc).name)
        Conditions(cc).Stimulus = struct(...
            'Mechanical',reshape(mean(cst(whFlag,:,delayFlags(:,cdel)),3),...
            1,Nt),'Laser',reshape(mean(cst(lrFlag,:,delayFlags(:,cdel)),3),...
            1,Nt),'TimeAxis',(0:Nt-1)/fs + timeLapse(1));
        cdel = cdel + 1;
    end
    save(fullfile(dataDir,[expName,'analysis.mat']),'Conditions','-append')
end
%}

%% Standard Deviations of First Spikes After Each Trigger per Unit
% firstSpikes(relativeSpkTmsStruct, gclID, dataDir);

%% Rasters from interesting clusters
rasAns = questdlg('Plot rasters?','Raster plot','Yes','No','Yes');
if strcmpi(rasAns,'Yes')
    [clSel, iOk] = listdlg('ListString',pclID,...
        'Name', 'Selection of clusters',...
        'CancelString', 'None',...
        'PromptString', 'Select clusters',...
        'SelectionMode', 'multiple');
    if ~iOk
        return
    end
    % Color of the rectangle
    cmap = [{[0.6, 0.6, 0.6]};... gray
        {[1, 0.6, 0]};... orange
        {[0.5, 0.6, 0.5]};... greenish gray (poo)
        {[0, 0.6, 1]};... baby blue
        {[0.6, 0.6, 1]};... lila
        {[1, 0.6, 1]}]; % pink
    clrNames = {'Gray','Orange','Poo','Baby Blue','Lila','Pink'}';
    clrmap = containers.Map(clrNames,cmap);
    if contains(Conditions(chCond).name, whStim,'IgnoreCase', 1)
        rectColor = clrmap('Orange');
    elseif contains(Conditions(chCond).name, cxStim, 'IgnoreCase', 1)
        rectColor = clrmap('Baby Blue');
    else
        rectColor = clrmap('Gray');
    end
    % Choose the conditions to be plotted
    resCondNames = arrayfun(@(x) x.name, Conditions(consideredConditions),...
        'UniformOutput', 0);
    [rasCondSel, iOk] = listdlg('ListString', resCondNames,...
        'PromptString', 'Which conditions to plot?',...
        'InitialValue', 1:length(consideredConditions),...
        'CancelString', 'None',...
        'Name', 'Conditions for raster',...
        'SelectionMode', 'multiple');
    if ~iOk
        return
    end
    rasCond = consideredConditions(rasCondSel);
    rasCondNames = consCondNames(rasCondSel);
    Nrcl = numel(clSel);
    % Reorganize the rasters in the required order.
    clSub = find(ismember(gclID, pclID(clSel)))+1;
    [rasIdx, rasOrd] = ismember(pclID(ordSubs), pclID(clSel));
    clSub = clSub(rasOrd(rasIdx));
    clSel = clSel(rasOrd(rasOrd ~= 0));
    Nma = min(Na(rasCondSel));
    rasFig = figure;
    Nrcond = length(rasCond);
    ax = gobjects(Nrcond*Nrcl,1);
    timeFlags = all([tx(:) >= timeLapse(1), tx(:) <= timeLapse(2)],2);
    for cc = 1:length(rasCond)
        % Equalize trial number
        trigSubset = sort(randsample(Na(rasCondSel(cc)),Nma));
        tLoc = find(delayFlags(:,rasCondSel(cc)));
        tSubs = tLoc(trigSubset);
        % Trigger subset for stimulation shading
        trigAlSubs = Conditions(rasCond(cc)).Triggers(trigSubset,:);
        timeDur = round(diff(trigAlSubs, 1, 2)/fs, 3); tol = 0.02/max(timeDur);
        timeDurUniq = uniquetol(timeDur, tol);
        %trigChange = find(diff(timeDur) ~= 0);
        trigChange = find(~ismembertol(timeDur, timeDurUniq, tol));
        for ccl = 1:Nrcl
            lidx = ccl + (cc - 1) * Nrcl;
            ax(lidx) = subplot(Nrcond, Nrcl, lidx);
            title(ax(lidx),sprintf('%s cl:%s',rasCondNames{cc},pclID{clSel(ccl)}))
            plotRasterFromStack(discStack([1,clSub(ccl)],timeFlags,tSubs),...
                timeLapse, fs,'',ax(lidx));
            ax(lidx).YAxisLocation = 'origin';ax(lidx).YAxis.TickValues = Nma;
            ax(lidx).YAxis.Label.String = Nma;
            ax(lidx).YAxis.Label.Position =...
                [timeLapse(1)-timeLapse(1)*0.65, Nma,0];
            %ax(lidx).XAxis.TickLabels =...
            %    cellfun(@(x) str2num(x)*1e3, ax(lidx).XAxis.TickLabels,...
            %    'UniformOutput', 0);
            xlabel(ax(lidx), 'Time [s]')
            initSub = 0;
            optsRect = {'EdgeColor',rectColor,'FaceColor','none'};
            for ctr = 1:numel(trigChange)
                rectangle('Position',[0, initSub,...
                    timeDur(trigChange(ctr)), trigChange(ctr)],optsRect{:})
                initSub = trigChange(ctr);
            end
            rectangle('Position', [0, initSub, timeDur(Nma),...
                Nma - initSub],optsRect{:})
        end
    end
    linkaxes(ax,'x')
    rasFigName = sprintf('%s R-%scl_%sVW%.1f-%.1f ms', expName,...
        sprintf('%s ', rasCondNames{:}), sprintf('%s ', pclID{clSel}),...
        timeLapse*1e3);
    rasFigPath = fullfile(figureDir, rasFigName);
    arrayfun(@(x) set(x,'Color','none'), ax);
    saveFigure(rasFig, rasFigPath, 1);
    clearvars ax rasFig
end
%% Response speed characterization
btx = (0:Nbn-1)*binSz + timeLapse(1);
respIdx = isWithinResponsiveWindow(btx);
% Window defined by the response in the population PSTH
% twIdx = btx >= 2e-3 & btx <= 30e-3;
% respTmWin = [2, 30]*1e-3;
[mdls, r2, qVals, qDiff] = exponentialSpread(PSTH(:,:,1), btx, responseWindow);
mdls(mdls(:,2) == 0, 2) = 1;
%% Cross-correlations
ccrAns = questdlg(['Get cross-correlograms?',...
    '(Might take a while to compute if no file exists!)'],...
    'Cross-correlations', 'Yes', 'No', 'Yes');
if strcmpi(ccrAns,'Yes')
    consTime = inputdlg('Cross-correlation lag (ms):',...
        'Correlation time', [1,30], {'50'});
    try
        consTime = str2num(consTime{1})*1e-3;
    catch
        fprintf(1, 'Cancelling...\n');
        return
    end
    corrsFile = fullfile(dataDir,sprintf('%s_%.2f ms_ccorr.mat', expName,...
        consTime*1e3));
    if ~exist(corrsFile,'file')
        if size(spkSubs,1) < size(goods,1)
            spkSubs = cat(1, {round(sortedData{goods(1),2}*fs)},spkSubs);
        end
        corrs = neuroCorr(spkSubs, consTime, 1, fs);
        save(corrsFile,'corrs','consTime','fs','-v7.3');
    else
        load(corrsFile, 'corrs')
    end
end
%% Auto-correlation measurement
% Arranging the auto-correlograms out of the cross-correlograms into a
% single matrix
try
    acorrs = cellfun(@(x) x(1,:), corrs, 'UniformOutput', 0);
catch
    fprintf(1, 'No correlograms in the workspace!\n')
end
if exist('acorrs', "var")
    acorrs = single(cat(1, acorrs{:})); Ncrs = size(acorrs, 2);
    % Computing the lag axis for the auto-correlograms
    b = -ceil(Ncrs/2)/fs; corrTx = (1:Ncrs)'/fs + b;
    corrTmWin = [1, 25]*1e-3;
    % Interesting region in the auto-correlogram
    [cmdls, cr2, cqVals, cqDiff] =...
        exponentialSpread(acorrs, corrTx, corrTmWin);
end
% lwIdx = corrTx >= (1e-3 - 1/fs) & corrTx <= 25e-3;
% lTx = corrTx(lwIdx);
% icsAc = double(1 - cumsum(acorrs(:,lwIdx)./sum(acorrs(:,lwIdx),2),2));
% % Quartile cuts
% quartCut = exp(-log([4/3, 2, exp(1), 4]))';
% % Exponential analysis for the auto-correlograms
% cmdls = zeros(Ncl,2); cr2 = zeros(Ncl,1); cqVals = zeros(Ncl,4);
% for ccl = 1:Ncl
%     % Exponential fit for the inverted cumsum
%     [fitObj, gof] = fit(lTx, icsAc(ccl,:)', 'exp1','Display','off');
%     cmdls(ccl,:) = coeffvalues(fitObj); cr2(ccl) = gof.rsquare;
%     % Quartiles cut for exponential distribution (25, 50, 63.21, 75)
%     quartFlags = icsAc(ccl,:) >= quartCut;
%     [qSubs, ~] = find(diff(quartFlags'));
%     il = arrayfun(@(x) fit_poly(lTx(x:x+1), icsAc(ccl,x:x+1), 1), qSubs,...
%         'UniformOutput', 0);il = cat(2,il{:});
%     cqVals(ccl,:) = (quartCut' - il(2,:))./il(1,:);
% end
% cqDiff = diff(cqVals(:,[1,4]),1,2);
%% Behaviour
afPttrn = "ArduinoTriggers*.mat";
rfPttrn = "RollerSpeed*.mat";
axOpts = {'Box','off','Color','none'};
lgOpts = cat(2, axOpts{1:2}, {'Location','best'});
flds = dir(getParentDir(dataDir,1));
pointFlag = arrayfun(@(x) any(strcmpi(x.name, {'.','..'})), flds);
flds(pointFlag) = [];
behFoldFlag = arrayfun(@(x) any(strcmpi(x.name, 'Behaviour')), flds);
if any(behFoldFlag) && sum(behFoldFlag) == 1
    % If only one folder named Behaviour exists, chances are that this is
    % an awake experiment.
    behDir = fullfile(flds(behFoldFlag).folder,flds(behFoldFlag).name);
    fprintf(1, "Found %s!\n", behDir)
    promptStrings = {'Viewing window (time lapse) [s]:','Response window [s]'};
    defInputs = {'-0.25, 0.5', '0.005, 0.4'};
    answ = inputdlg(promptStrings,'Behaviour parameters', [1, 30], defInputs);
    if isempty(answ)
        fprintf(1,'Cancelling...\n')
        return
    else
        bvWin = str2num(answ{1}); %#ok<*ST2NM>
        if numel(bvWin) ~= 2
            bvWin = str2num(inputdlg('Please provide the time window [s]:',...
                'Time window',[1, 30], '-0.1, 0.1'));
            if isnan(bvWin) || isempty(bvWin)
                fprintf(1,'Cancelling...')
                return
            end
        end
        brWin = str2num(answ{2});
    end
    if isempty(dir(fullfile(behDir, afPttrn)))
        readAndCorrectArdTrigs(behDir);
    end

    fprintf(1,'Time window: %.2f - %.2f ms\n',bvWin*1e3)
    fprintf(1,'Response window: %.2f - %.2f ms\n',brWin*1e3)
    % Roller speed
    rfFiles = dir(fullfile(behDir, rfPttrn));
    if isempty(rfFiles)
        [~, vf, rollTx, fr, Texp] = createRollerSpeed(behDir);
        rfFiles = dir(fullfile(behDir, rfPttrn));
    end
    if numel(rfFiles) == 1
        rfName = fullfile(rfFiles.folder, rfFiles.name);
        load(rfName)
        try
            %              Encoder steps  Radius^2
            en2cm = ((2*pi)/((2^15)-1))*((14.85/2)^2)*rollFs;
            fr = rollFs;
        catch
            try
                %              Encoder steps  Radius^2
                en2cm = ((2*pi)/((2^15)-1))*((14.85/2)^2)*fr;
                rollFs = fr;
            catch
                en2cm = ((2*pi)/((2^15)-1))*((14.85/2)^2)*fsRoll;
                rollFs = fsRoll;
                fr = fsRoll;
            end
        end
    end
    % Triggers
    getFilePath = @(x) fullfile(x.folder, x.name);
    atVar = {'atTimes', 'atNames', 'itTimes', 'itNames'};
    afFiles = dir(fullfile(behDir,afPttrn));
    if ~isempty(afFiles)
        atV = arrayfun(@(x) load(getFilePath(x), atVar{:}), afFiles);
        Nrecs = length(atV);
        atT = arrayfun(@(x, z) cellfun(@(y, a) y+a, ...
            x.atTimes, repmat(z,1,length(x.atTimes)), fnOpts{:}), atV', ...
            num2cell([0, Texp(1:end-1)]), fnOpts{:});
        trig_per_recording = cellfun(@(x) size(x,2), atT);
        [max_trigs, record_most_trigs] = max(trig_per_recording);
        record_trig_cont_ID = arrayfun(@(x) ...
            contains(atV(record_most_trigs).atNames, x.atNames), ...
            atV(1:Nrecs), fnOpts{:}); outCell = cell(Nrecs, max_trigs);
        for cr = 1:Nrecs
            outCell(cr,record_trig_cont_ID{cr}) = atT{cr};
        end
        atTimes = arrayfun(@(x) cat(1, outCell{:,x}), 1:size(outCell,2), ...
            fnOpts{:});
        atNames = atV(1).atNames;
    end

    lSub = arrayfun(@(x) contains(Conditions(chCond).name, x), atNames);
    [~, vStack] = getStacks(false, round(atTimes{lSub} * fr), 'on', bvWin,...
        fr, fr, [], vf*en2cm); [~, Nbt, Nba] = size(vStack);
    tmdl = fit_poly([1,Nbt], bvWin, 1);
    behTx = ((1:Nbt)'.^[1,0])*tmdl;
    % Spontaneous flag
    bsFlag = behTx <= 0; brFlag = behTx < brWin;
    brFlag = xor(brFlag(:,1),brFlag(:,2));
    sSig = squeeze(std(vStack(:,bsFlag,:), [], 2));
    sMed = squeeze(median(vStack(:,bsFlag,:), 2));
    tMed = squeeze(median(vStack, 2));

    % A bit arbitrary threshold, but enough to remove running trials
    sigTh = 2.5; sMedTh = 0.2; tMedTh = 1;
    thrshStr = sprintf("TH s%.2f sp_m%.2f t_m%.2f", sigTh, sMedTh, tMedTh);
    excFlag = sSig > sigTh | abs(sMed) > sMedTh | abs(tMed) > tMedTh;
    ptOpts = {"Color", 0.7*ones(1,3), "LineWidth", 0.2;...
        "Color", "k", "LineWidth",  1.5};
    spTh = {0.1:0.1:3}; % Speed threshold
    gp = zeros(Nccond, 1, 'single');
    rsPttrn = "%s roller speed VW%.2f - %.2f s RM%.2f - %.2f ms EX%d %s";
    pfPttrn = "%s move probability %.2f RW%.2f - %.2f ms EX%d %s";
    rsSgnls = cell(Nccond, 1); mvFlags = cell(Nccond,1); mvpt = mvFlags;
    qSgnls = rsSgnls;
    mat2ptch = @(x) [x(1:end,:)*[1;1]; x(end:-1:1,:)*[1;-1]];
    getThreshCross = @(x) sum(x)/size(x,1);
    xdf = arrayfun(@(x) ~excFlag & delayFlags(:,x), 1:Nccond, ...
        fnOpts{:});  xdf = cat(2, xdf{:});

    for ccond = 1:Nccond
        sIdx = xdf(:,ccond);
        % % Plot speed signals
        fig = figure("Color", "w");
        Nex = sum(xor(sIdx, delayFlags(:,ccond)));
        rsFigName = sprintf(rsPttrn,consCondNames{ccond}, bvWin,...
            brWin*1e3, Nex, thrshStr);
        % Plot all trials
        plot(behTx, squeeze(vStack(:,:,sIdx)), ptOpts{1,:}); hold on;
        % Plot mean of trials
        % Standard deviation
        %rsSgnls{ccond} = [squeeze(mean(vStack(:,:,sIdx),3))',...
        %squeeze(std(vStack(:,:,sIdx),1,3))'];
        % S.E.M.
        rsSgnls{ccond} = [squeeze(mean(vStack(:,:,sIdx),3))',...
            squeeze(std(vStack(:,:,sIdx),1,3))'./sqrt(sum(sIdx))];
        qSgnls{ccond} = squeeze(quantile(vStack(:,:,sIdx),3,3));
        lObj = plot(behTx, rsSgnls{ccond}(:,1), ptOpts{2,:});
        lgnd = legend(lObj,string(consCondNames{ccond}));
        set(lgnd, "Box", "off", "Location", "best")
        set(gca, axOpts{:})
        title(['Roller speed ',consCondNames{ccond}])
        xlabel("Time [s]"); ylabel("Roller speed [cm/s]"); xlim(bvWin)
        saveFigure(fig, fullfile(figureDir, rsFigName), 1)
        % Probability plots
        mvpt{ccond} = getMaxAbsPerTrial(squeeze(vStack(:,:,sIdx)), ...
            brWin, behTx);
        mvFlags{ccond} = compareMaxWithThresh(mvpt{ccond}, spTh);
        gp(ccond) = getAUC(mvFlags{ccond});
        pfName = sprintf(pfPttrn, consCondNames{ccond}, gp(ccond),...
            brWin*1e3, Nex, thrshStr);
        fig = plotThetaProgress(mvFlags(ccond), spTh,...
            string(consCondNames{ccond}));
        xlabel("Roller speed \theta [cm/s]");
        title(sprintf("Trial proportion crossing \\theta: %.3f", gp(ccond)))
        saveFigure(fig, fullfile(figureDir, pfName), 1)
    end
    clMap = lines(Nccond);
    phOpts = {'EdgeColor', 'none', 'FaceAlpha', 0.25, 'FaceColor'};
    % Plotting mean speed signals together
    fig = figure("Color", "w"); axs = axes("Parent", fig, "NextPlot", "add");
    arrayfun(@(x) patch(axs, behTx([1:end, end:-1:1]),...
        mat2ptch(rsSgnls{x}), 1, phOpts{:}, clMap(x,:)), 1:Nccond); hold on
    lObj = arrayfun(@(x) plot(axs, behTx, rsSgnls{x}(:,1), "Color", clMap(x,:),...
        "LineWidth", 1.5, "DisplayName", consCondNames{x}), 1:Nccond);
    xlabel(axs, "Time [s]"); xlim(axs, bvWin); ylabel(axs, "Roller speed [cm/s]")
    set(axs, axOpts{:}); title(axs, "Roller speed for all conditions")
    lgnd = legend(axs, lObj); set(lgnd, lgOpts{:})
    rsPttrn = "Mean roller speed %s VW%.2f - %.2f s RM%.2f - %.2f ms EX%s %s SEM";
    Nex = Na - sum(xdf);
    rsFigName = sprintf(rsPttrn, sprintf('%s ', consCondNames{:}), bvWin,...
        brWin*1e3, sprintf('%d ', Nex), thrshStr);
    saveFigure(fig, fullfile(figureDir, rsFigName), 1)

    % Plotting median speed signals together
    q2patch = @(x) [x(:,1);x(end:-1:1,3)];
    fig = figure("Color", "w"); axs = axes("Parent", fig, "NextPlot", "add");
    arrayfun(@(x) patch(axs, behTx([1:end, end:-1:1]),...
        q2patch(qSgnls{x}), 1, phOpts{:}, clMap(x,:)), 1:Nccond); hold on
    lObj = arrayfun(@(x) plot(axs, behTx, qSgnls{x}(:,2), "Color", clMap(x,:),...
        "LineWidth", 1.5, "DisplayName", consCondNames{x}), 1:Nccond);
    xlabel(axs, "Time [s]"); xlim(axs, bvWin); ylabel(axs, "Roller speed [cm/s]")
    set(axs, axOpts{:}); title(axs, "Roller speed for all conditions")
    lgnd = legend(axs, lObj); set(lgnd, lgOpts{:})
    rsPttrn = "Median roller speed %s VW%.2f - %.2f s RM%.2f - %.2f ms EX%s %s IQR";
    rsFigName = sprintf(rsPttrn, sprintf('%s ', consCondNames{:}), bvWin,...
        brWin*1e3, sprintf('%d ', Nex), thrshStr);
    saveFigure(fig, fullfile(figureDir, rsFigName), 1)

    % Plotting movement threshold crossings
    fig = figure("Color", "w"); axs = axes("Parent", fig, "NextPlot", "add");
    mvSgnls = cellfun(getThreshCross, mvFlags, fnOpts{:});
    mvSgnls = cat(1, mvSgnls{:}); mvSgnls = mvSgnls';
    plot(axs, spTh{1}, mvSgnls);
    ccnGP = cellfun(@(x, y) [x, sprintf(' AUC%.3f',y)], consCondNames', ...
        num2cell(gp), fnOpts{:});
    lgnd = legend(axs, ccnGP); set(axs, axOpts{:})
    set(lgnd, lgOpts{:}); ylim(axs, [0,1])
    xlabel(axs, "Roller speed \theta [cm/s]"); ylabel(axs, "Trial proportion")
    title(axs, "Trial proportion crossing \theta")
    pfPttrn = "Move probability %sRW%.2f - %.2f ms %s";
    pfName = sprintf(pfPttrn, sprintf('%s ', ccnGP{:}), brWin*1e3, thrshStr);
    saveFigure(fig, fullfile(figureDir, pfName), 1)

    % Plotting maximum speed for all considered trials
    fig = figure; axs = axes('Parent', fig, 'NextPlot', 'add');
    arrayfun(@(x) boxchart(x*ones(size(mvpt{x},1),1), mvpt{x}, 'Notch', 'on'), ...
        1:size(mvpt,1))
    xticks(axs, 1:size(mvpt,1)); xticklabels(axs, consCondNames)
    try
        ylim(axs, [0, round(1.05*(max(cellfun(@(x) quantile(x, 0.75) + ...
            1.5*iqr(x), mvpt))),1)]);
    catch
        ylim(axs, 'auto')
    end
    ylabel(axs, "Roller speed [cm/s]")
    arrayfun(@(x) text(x, median(mvpt{x}), sprintf("%.2f",median(mvpt{x})), ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom"), ...
        1:Nccond, fnOpts{:});
    title(axs, "Roller speed distribution")
    rsdPttrn = "Roller speed dist %sVW%.2f - %.2f ms RM%.2f - %.2f ms EX%s%s";
    rsdFigName = sprintf(rsdPttrn, sprintf('%s ', consCondNames{:}), bvWin*1e3,...
        brWin*1e3, sprintf('%d ', Nex), thrshStr);
    saveFigure(fig, fullfile(figureDir, rsdFigName), 1)

    % Tests for movement
    prms = nchoosek(1:Nccond,2);
    getDistTravel = @(x) squeeze(sum(abs(vStack(:,brFlag,xdf(:,x))),2));
    dstTrav = arrayfun(getDistTravel, 1:Nccond, fnOpts{:});
    [pd, hd, statsd] = arrayfun(@(x) ranksum(dstTrav{prms(x,1)}, ...
        dstTrav{prms(x,2)}), 1:size(prms,1), fnOpts{:});
    [pm, hm, statsm] = arrayfun(@(x) ranksum(mvpt{prms(x,1)}, ...
        mvpt{prms(x,2)}), 1:size(prms,1), fnOpts{:});
    resPttrn = "Results %s%sVW%.2f - %.2f ms RW%.2f - %.2f ms EX%s%s.mat";
    resName = sprintf(resPttrn, sprintf("%d ", hd{:}), ...
        sprintf('%s ',consCondNames{:}), bvWin*1e3, brWin*1e3, ...
        sprintf('%d ', Nex), thrshStr);
    save(fullfile(behDir, resName), "gp", "dstTrav", "ccnGP", "mvpt", "xdf", ...
        "vStack", "spTh", "sigTh", "sMedTh", "tMedTh", "brWin", "bvWin", "prms")

    % Behaviour signals
    timeAxis_speed = (0:length(vf)-1)'/fr;
    time_drift_mdl = fit_poly(atTimes{lSub}, Conditions(1).Triggers(:,1)/fs, 1);
    timeAxis_speed_corrected = timeAxis_speed.^[1,0] * time_drift_mdl;
    timeAxis_speed2 = (0:1/fr:timeAxis_speed_corrected(end))';
    vels = interp1(timeAxis_speed_corrected, vf*en2cm, timeAxis_speed2);

    

    dlcFiles = dir(fullfile(behDir, "*filtered.csv"));
    dlcFile = [];
    if ~isempty(dlcFiles)
        if numel(dlcFiles)==1
            dlcFile = dlcFiles.name;
        end
    else
        dlcFiles = dir(fullfile(behDir, "roller*DLC_resnet50_AwakenSCJul20shuffle1_1030000.csv"));
        if ~empty(dlcFiles)
            if numel(dlcFiles) == 1
                dlcFile = dlcFiles.name;
            end
        else
            fprintf(1, "No DLC applied on the videos yet!\n")
            fprintf(1, "Unable to get behavioural signals!\n")
        end
    end

    if ~isempty(dlcFile)
        dlcTable = readDLCData(fullfile(behDir, dlcFile));
        [a_bodyParts, refStruct] = getBehaviourSignals(dlcTable);
        nose = a_bodyParts{:,"nose"} - mean(a_bodyParts{:,"nose"});
        % Right whiskers
        rw = mean(a_bodyParts{:,{'rw1', 'rw2', 'rw3', 'rw4'}}, 2);
        rw = rw - mean(rw);
        % Left whiskers
        lw = mean(a_bodyParts{:,{'lw1', 'lw2', 'lw3', 'lw4'}},2);
        lw = lw - mean(lw);
    end

end
