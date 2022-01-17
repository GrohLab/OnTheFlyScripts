% PoolPain is a script that takes in all the experiments to be analysed
% together and will then analyse them ala DE_Jittering/PAIN scripts


%% Choose a Directory to save info to
pooledDataDir = uigetdir('Z:\',...
    'Choose a working directory');
if pooledDataDir == 0
    return
end

% Creating the figure directory
figureDir = fullfile(pooledDataDir,'Figures\');
if ~mkdir(figureDir)
    fprintf(1,'There was an issue with the figure folder...\n');
end
%%
% Select the experiment folders and add to the Analysis struct
Analysis.Experiments = struct;
nExpts = str2double(cell2mat(inputdlg('How Many Experiments are you considering?')));

for exp = 1:nExpts
    Analysis.Experiments(exp).Directory = uigetdir('Z:\',...
        'Choose a working directory');
    if Analysis.Experiments(exp).Directory == 0
        return
    end
end

%% Get data from the selected directories

ObjNames = {'bin', 'all_channels', 'analysis', 'cluster_info'};
for exp = 1:nExpts
    
    cDir = Analysis.Experiments(exp).Directory;
    % fprintf(['Reading the relevant files in ', cDir , '. \n This may take a few mins'])
    files = {dir(fullfile(cDir, '*.bin')),...
        dir(fullfile(cDir, '*all_channels.mat')),...
        dir(fullfile(cDir, '*analysis.mat')),...
        dir(fullfile(cDir, '*cluster_info.tsv'))};
    
    
    
    
    mouseIDfind = strfind(files{2}.name, 'm');
    mouseIDfind = mouseIDfind(1);
    find_ = strfind(files{2}.name, '_');
    find_ = find_(1)-1;
    mouseID{exp} = files{2}.name(mouseIDfind:find_);
    
    
    for name = 1:length(ObjNames)
        Analysis.Experiments(exp).(ObjNames{name}) = {};
    end
    
    
    for ind = 1:length(files)
        file = files{ind};
        
        if length(file) > 1
            promptStr = {'Select the relevant file: '};
            input = struct2cell(file);
            input = (cell(input(1,1:end)))';
            fileNo = listdlg('PromptString', promptStr, 'ListString', input);
            file = dir(fullfile(cDir, file(fileNo).name));
            Analysis.Experiments(exp).(ObjNames{ind}) = file;
        elseif length(file) < 1
            if ind == 3
                fprintf(['There is no ', ObjNames{ind}, ' file in directory ', num2str(exp), ' \n']);
                ansFilt = questdlg('Would you like to create one with the smrx files?','Filter',...
                    'Yes','No','Yes');
                if strcmp(ansFilt,'Yes')
                    fs = Analysis.Experiments(exp).all_channels.fs; % This won't work, all_channels hasn't been loaded in yet
                    expName = inputdlg('Please give a name to the analysis file:', 'FileName', [1, 50]);
                    expName = expName{1};
                    iOk = getTriggers(expName, cDir, fs);
                    file = dir(fullfile(cDir, '*analysis.mat'));
                    % Bring this file back into the analysis and make
                    % getTriggers an iOK function
                end
            end
            
            
            
            fprintf(['There is no ', ObjNames{ind}, ' file in directory ', num2str(exp), ' \n']);
            fprintf('Maybe you can find one manually? \n \n');
        else
            Analysis.Experiments(exp).(ObjNames{ind}) = file;
        end
        
    end
    
    for mat = [2,3]
        indx = Analysis.Experiments(exp).(ObjNames{mat});
        Analysis.Experiments(exp).(ObjNames{mat}) = load([indx.folder, '\', indx.name]);
    end
    
    tsv = 4;
    indx = Analysis.Experiments(exp).(ObjNames{tsv});
    Analysis.Experiments(exp).(ObjNames{tsv}) = getClusterInfo([indx.folder, '\', indx.name]);
end


%% Combining the tables together & altering unit names for pooled analysis
for exp = 1:nExpts
    if sum(contains(Analysis.Experiments(exp).cluster_info.Properties.VariableNames, 'abs_depth')) < 1
        promptStrings = {'How deep was your probe? (um)'};
        defInputs = {'1500'};
        dpth = inputdlg(promptStrings,'Inputs', [1, 30],defInputs);
        
        dpth = str2double(dpth{1});
        
        
        abs_depth = dpth - Analysis.Experiments(exp).cluster_info.depth;
        % dif = abs(dpth) - 1275;
        % abs_depth = clInfo.depth + dif;
        
        
        
        
        Analysis.Experiments(exp).cluster_info = addvars(Analysis.Experiments(exp).cluster_info,abs_depth,'After','depth',...
            'NewVariableNames','abs_depth');
        
        
    end
    for ind = 1:length(Analysis.Experiments(exp).cluster_info.id)
        Analysis.Experiments(exp).cluster_info.id{ind} = [mouseID{exp}, Analysis.Experiments(exp).cluster_info.id{ind}];
        Analysis.Experiments(exp).cluster_info.Properties.RowNames{ind} = Analysis.Experiments(exp).cluster_info.id{ind};
        Analysis.Experiments(exp).all_channels.sortedData{ind} = Analysis.Experiments(exp).cluster_info.id{ind};
    end
end

All_Units = Analysis.Experiments(1).cluster_info(:,[1,3:13]);
for nClInfo = 2: nExpts
    
    
    All_Units = [All_Units; Analysis.Experiments(exp).cluster_info(:,[1,3:13])];
end

%% User controlling variables
% Time lapse, bin size, and spontaneous and response windows
promptStrings = {'Viewing window (time lapse) [s]:','Response window [s]',...
    'Bin size [s]:'};
defInputs = {'-2, 6', '0.1, 1.5', '0.01'};
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
            fprintf(1,'Cancelling... \n')
            return
        end
    end
    responseWindow = str2num(answ{2});
    binSz = str2double(answ(3));
end
fprintf(1,'Time window: %.2f - %.2f ms\n',timeLapse(1)*1e3, timeLapse(2)*1e3)
fprintf(1,'Response window: %.2f - %.2f ms\n',responseWindow(1)*1e3, responseWindow(2)*1e3)
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
statFigFileNameEndings = {'.pdf','.emf'};
printOpts = {{'-dpdf','-fillpage'},'-dmeta'};

cellLogicalIndexing = @(x,idx) x(idx);

expCo = 1;



%% Experiment loop
% For all the chosen experiments, perform the statistical test and save its
% results, and extract the spike times for all clusters blending in the
% trial information for a PDF calculation
relativeSpikeTimes = cell(nExpts);
activeUnits = [];
for cExp = 1:nExpts
    
    dataDir = Analysis.Experiments(cExp).Directory;
    sortedData = Analysis.Experiments(cExp).all_channels.sortedData;
    fs = Analysis.Experiments(cExp).all_channels.fs;
    Conditions = Analysis.Experiments(cExp).analysis.Conditions;
    Triggers = Analysis.Experiments(cExp).analysis.Triggers;
    
    
    
    %% Constructing the helper 'global' variables
    if (fs - (1/33.3e-6)) > 1
        fprintf(2, '%.3f kHz different sampling frequency!\n', fs/1e3);
        [~, cfld] = fileparts(dataDir);
        fprintf(2, 'Skipping %s\n', cfld);
        continue
    end
    % Number of total samples
    Ns = structfun(@numel,Triggers);
    Ns = min(Ns(Ns>1));
    % Total duration of the recording
    Nt = Ns/fs;
    
    
    autoCorr = @(x) neuroCorr(x, corrWin, 1, fs);
    % Useless clusters (labeled as noise or they have very low firing rate)
    badsIdx = cellfun(@(x) x==3, sortedData(:,3)); bads = find(badsIdx);
    silentUnits = cellfun(@(x) (numel(x)/Nt) < 0.1, sortedData(:,2));
    bads = union(bads, find(silentUnits));
    goods = setdiff(1:size(sortedData,1),bads);
    badsIdx = badsIdx | silentUnits;
    
    activeUnits = [activeUnits; ~badsIdx];
    
    gclID = sortedData(goods,1);
    % Logical spike trace for the first good cluster
    spkLog = StepWaveform.subs2idx(round(sortedData{goods(1),2}*fs),Ns);
    % Subscript column vectors for the rest good clusters
    spkSubs = cellfun(@(x) round(x.*fs),sortedData(goods(2:end),2),...
        'UniformOutput',false);
    % Number of good clusters
    Ncl = numel(goods);
    % Redefining the stimulus signals from the low amplitude to logical values
    whStim = {'piezo','whisker','mech','audio'};
    cxStim = {'laser','light'};
    lfpRec = {'lfp','s1','cortex','s1lfp'};
    trigNames = fieldnames(Triggers);
    numTrigNames = numel(trigNames);
    continuousSignals = struct2cell(Triggers);
    % User defined conditions
    
    Nt = round(sum(ceil(abs(timeLapse)*fs))+1);
    % Computing the time axis for the stack
    tx = (0:Nt - 1)/fs + timeLapse(1);
    %% Condition triggered stacks
    condNames = arrayfun(@(x) x.name,Conditions,'UniformOutput',false);
    condGuess = contains(condNames, 'whiskerall', 'IgnoreCase', true);
    % Choose the conditions to create the stack upon
    [chCond, iOk] = listdlg('ListString',condNames,'SelectionMode','single',...
        'PromptString',...
        'Choose the condition which has all Mechanical triggers: (one condition)',...
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
    
    %% Considered conditions selection
    % Choose the conditions to look at
    auxSubs = setdiff(1:numel(condNames), chCond);
    ccondNames = condNames(auxSubs);
    [cchCond, iOk] = listdlg('ListString',ccondNames,'SelectionMode','multiple',...
        'PromptString',...
        'Choose the condition to analyse (Only one intenstiy!):',...
        'ListSize', [350, numel(condNames)*16]);
    if ~iOk
        fprintf(1,'Cancelling...\n')
        return
    end
    
    % Select the onset or the offset of a trigger
    fprintf(1,'Condition(s):\n')
    fprintf('- ''%s''\n', Conditions(auxSubs(cchCond)).name)
    
    ansFilt = questdlg('Would you like to filter for significance?','Filter',...
        'Yes','No','Yes');
    filtStr = 'unfiltered';
    if strcmp(ansFilt,'Yes')
        filtStr = 'filtered';
    end
    % Subscript to indicate the conditions with all whisker stimulations,
    % whisker control, laser control, and the combination whisker and laser.
    consideredConditions = auxSubs(cchCond);
    Nccond = length(consideredConditions);
    
    % Select the onset or the offset of a trigger
    fprintf(1,'Condition(s):\n')
    fprintf('- ''%s''\n', Conditions(auxSubs(cchCond)).name)
    % Subscripts and names for the considered conditions
    consCondNames = condNames(consideredConditions);
    
    % Time windows for comparison between conditions and activity
    sponActStackIdx = tx >= spontaneousWindow(1) & tx <= spontaneousWindow(2);
    respActStackIdx = tx >= responseWindow(1) & tx <= responseWindow(2);
    % The spontaneous activity of all the clusters, which are allocated from
    % the second until one before the last row, during the defined spontaneous
    % time window, and the whisker control condition.
    
    timeFlags = [sponActStackIdx; respActStackIdx];
    % Time window
    delta_t = diff(responseWindow);
    % Spontaneous vs evoked comparison
    indCondSubs = cumsum(Nccond:-1:1);
    isWithinResponsiveWindow =...
        @(x) x > responseWindow(1) & x < responseWindow(2);
    
    % Constructing the stack out of the user's choice
    % discStack - dicrete stack has a logical nature
    % cst - continuous stack has a numerical nature
    % Both of these stacks have the same number of time samples and trigger
    % points. They differ only in the number of considered events.
    [auxDStack, auxCStack] = getStacks(spkLog, Conditions(chCond).Triggers,...
        onOffStr, timeLapse, fs, fs, spkSubs, continuousSignals);
    % Number of clusters + the piezo as the first event + the laser as the last
    % event, number of time samples in between the time window, and number of
    % total triggers.
    [Ne, Nt, NTa] = size(auxDStack);
    
    % Computing which alignment points belong to which condition.
    auxDelayFlags = false(NTa,Nccond);
    counter2 = 1;
    for ccond = consideredConditions
        auxDelayFlags(:,counter2) = ismember(Conditions(chCond).Triggers(:,1),...
            Conditions(ccond).Triggers(:,1));
        counter2 = counter2 + 1;
    end
    NaNew = sum(auxDelayFlags,1);
    
    % All spikes in a cell format
    spkSubs = cat(1, {round(sortedData{goods(1),2}*fs)}, spkSubs);
    
    %     % Autocorrelation for all active units
    %
    %     corrFileName = fullfile(dataDir, '*_ccorr.mat');
    %     corrFiles = dir(corrFileName); corrCorr =...
    %         arrayfun(@(x) contains(x.name, sprintf('%.2f', corrWin*1e3)),...
    %         corrFiles);
    %     if ~isempty(corrFiles) && any(corrCorr)
    %         load(fullfile(corrFiles(corrCorr).folder,corrFiles(corrCorr).name),...
    %             'corrs')
    %         eaCorr = cellfun(@(x) x(1,:), corrs, 'UniformOutput', 0);
    %     else
    %         eaCorr = arrayfun(autoCorr, spkSubs, 'UniformOutput', 0);
    %         eaCorr = cat(1, eaCorr{:});
    %     end
    %     eaCorr = cat(1, eaCorr{:});
    %     eaCorr = sparse(eaCorr);
    % %     % Computing the lag axis for the auto-correlograms
    % %     b = -ceil(Ncrs/2)/fs; corrTx = (1:Ncrs)'/fs + b;
    
    % Computing the firing rate during the different conditions
    NaCount = 1;
    % Experiment firing rate and ISI per considered condition
    efr = zeros(Ncl, size(consideredConditions,2), 'single');
    eisi = cellfun(@(x) diff(x), spkSubs, 'UniformOutput', 0);
    econdIsi = cell(Ncl, size(consideredConditions,2));
    econdSpks = econdIsi;
    trainDuration = 1;
    for ccond = consideredConditions
        itiSub = mean(diff(Conditions(ccond).Triggers(:,1)));
        consTime = [Conditions(ccond).Triggers(1,1) - round(itiSub/2),...
            Conditions(ccond).Triggers(NaNew(NaCount),2) + round(itiSub/2)]...
            ./fs;
        [efr(:,NaCount),~, econdSpks(:,NaCount), econdIsi(:,NaCount)] =...
            getSpontFireFreq(spkSubs, Conditions(ccond).Triggers,...
            consTime, fs, trainDuration + delta_t + responseWindow(1));
        NaCount = NaCount + 1;
    end
    
    %     % Getting the clusters' waveforms
    %     sewf = getClusterWaveform(gclID, dataDir);
    %     sewf(:,1) = cellfun(@(x) [sprintf('%d_',cexp), x], sewf(:,1),...
    %         'UniformOutput', 0);
    %     mswf = cellfun(@(x) mean(x,2), sewf(:,2),'UniformOutput', 0);
    %     mswf = cat(2, mswf{:});
    %     cwID = sewf(:,1);
    %% Building the population stack
    % Removing not considered conditions
    if sum(NaNew) ~= NTa
        emptyRow = find(~sum(auxDelayFlags,2));
        auxDelayFlags(emptyRow,:) = [];
        auxDStack(:,:,emptyRow) = [];
        auxCStack(:,:,emptyRow) = [];
    end
    %     clInfo.id = cellfun(@(x) [sprintf('%d_',cexp), x], clInfo.id,...
    %         'UniformOutput', 0);
    %     clInfo.Properties.RowNames = clInfo.id;
    if cExp == 1
        % First assignment
        delayFlags = auxDelayFlags;
        discStack = auxDStack;
        cStack = auxCStack;
        %         clInfoTotal = clInfo;
        NaStack = NaNew;
        %         popClWf = mswf;
        % %         pcwID = cwID;
        pfr = efr;
        pisi = eisi;
        %         paCorr = eaCorr;
        pcondIsi = econdIsi;
        pcondSpks = econdSpks;
        pSpkSubs = spkSubs;
    else
        pfr = cat(1, pfr, efr);
        pisi = cat(1, pisi, eisi);
        %         paCorr = cat(1, paCorr, eaCorr);
        pcondIsi = cat(1, pcondIsi, econdIsi);
        pcondSpks = cat(1, pcondSpks, econdSpks);
        %         popClWf = cat(2, popClWf, mswf);
        %         pcwID = cat(1, pcwID, cwID);
        pSpkSubs = cat(1, pSpkSubs, spkSubs);
        % Homogenizing trial numbers
        if any(NaNew ~= NaStack)
            NaMin = min(NaStack, NaNew);
            NaMax = max(NaStack, NaNew);
            trigSubset = cell(numel(NaStack),1);
            for cc = 1:numel(NaStack)
                trigSubset{cc} = sort(randsample(NaMax(cc),NaMin(cc)));
                if NaStack(cc) == NaMin(cc)
                    tLoc = find(auxDelayFlags(:,cc));
                    try
                        tSubs = tLoc(trigSubset{cc});
                    catch
                        trigSubset{cc} = sort(randsample(numel(tLoc),NaMin(cc)));
                        tSubs = tLoc(trigSubset{cc});
                    end
                    auxDelayFlags(setdiff(tLoc,tSubs),:) = [];
                    auxDStack(:,:,setdiff(tLoc,tSubs)) = [];
                    auxCStack(:,:,setdiff(tLoc,tSubs)) = [];
                else
                    tLoc = find(delayFlags(:,cc));
                    tSubs = tLoc(trigSubset{cc});
                    delayFlags(setdiff(tLoc,tSubs),:) = [];
                    discStack(:,:,setdiff(tLoc,tSubs)) = [];
                    cStack(:,:,setdiff(tLoc,tSubs)) = [];
                    NaStack(cc) = NaNew(cc);
                end
            end
        end
        
        % When the stacks have different order for different conditions
        if nnz(size(auxDelayFlags) - size(delayFlags))
            [ntrials, nconds] = size(delayFlags);
            [nctrials, ncconds] = size(auxDelayFlags);
            fprintf(1,'There are more trials in ')
            if ntrials > nctrials
                fprintf(1, 'DelayFlags\n')
                
            else
                fprintf(1, 'AuxDelayFlags\n')
                emptyADFFlag = ~any(auxDelayFlags,2);
                if (nctrials - sum(emptyADFFlag)) ~= ntrials
                    fprintf(1, 'The populated trials are different in ')
                    fprintf(1, 'each delayFlag matrix!!\n')
                end
                auxDelayFlags(emptyADFFlag,:) = [];
                auxDStack(:,:,emptyADFFlag) = [];
                auxCStack(:,:,emptyADFFlag) = [];
            end
        end
        if nnz(auxDelayFlags - delayFlags)
            [stOrd, ~] = find(delayFlags);
            [astOrd , ~] = find(auxDelayFlags);
            auxDStack(:,:,stOrd) = auxDStack(:,:,astOrd);
            cStack(:,:,stOrd) = cStack(:,:,astOrd);
            auxDelayFlags(stOrd,:) = auxDelayFlags(astOrd,:);
        end
        auxDStack(1,:,:) = [];
        discStack = cat(1, discStack, auxDStack);
        cStack = cat(1, cStack, auxCStack);
    end
end
%%
if ~any(ismember(All_Units.Properties.VariableNames,'ActiveUnit'))
    try
        All_Units = addvars(All_Units,activeUnits==1,'After','id',...
            'NewVariableNames','ActiveUnit');
    catch
        All_Units = addvars(All_Units,false(size(All_Units,1),1),'After','id',...
            'NewVariableNames','ActiveUnit');
        All_Units{sortedData(activeUnits,1),'ActiveUnit'} = true;
        fprintf(1,'Not all clusters are curated!\n')
        fprintf(1,'%s\n',dataDir)
    end
    try
        writeClusterInfo(All_Units,fullfile(dataDir,'cluster_info.tsv'),true);
    catch
        fprintf(1,'Unable to write cluster info for %s\n',pooledDataDir)
    end
end

gclID = All_Units{All_Units.ActiveUnit == 1,'id'};
Ncl = numel(gclID);
Ne = size(discStack, 1);


%% Population analysis

chExps = ['_', mouseID{1}];
if length(mouseID) > 1
    
    for expNo = 2:length(mouseID)
        chExps = [chExps, mouseID{expNo}, '_'];
    end
end

[~,expName] = fileparts(pooledDataDir);
dataDir = pooledDataDir;
% Statistical tests
[Results, Counts] = statTests(discStack, delayFlags, timeFlags);

% Plotting statistical tests
[figs, Results] = scatterSignificance(Results, Counts,...
    consCondNames, delta_t, gclID);
arrayfun(@configureFigureToPDF, figs);
% % Firing rate for all clusters, for all trials
% % meanfr = cellfun(@(x) mean(x,2)/delta_t,Counts,'UniformOutput',false);
stFigBasename = fullfile(figureDir,[expName,' ',chExps]);
stFigSubfix = sprintf(' Stat RW%.1f-%.1fms SW%.1f-%.1fms',...
    responseWindow(1)*1e3, responseWindow(2)*1e3, spontaneousWindow(1)*1e3,...
    spontaneousWindow(2)*1e3);
ccn = 1;
%for cc = indCondSubs
for cc = 1:numel(figs)
    if ~ismember(cc, indCondSubs)
        altCondNames = strsplit(figs(cc).Children(2).Title.String,': ');
        altCondNames = altCondNames{2};
    else
        altCondNames = consCondNames{ccn};
        ccn = ccn + 1;
    end
    stFigName = [stFigBasename, altCondNames, stFigSubfix];
    if ~exist([stFigName,'.pdf'],'file') ||...
            ~exist([stFigName,'.emf'],'file')
        print(figs(cc),[stFigName,'.pdf'],printOpts{1}{:})
        print(figs(cc),[stFigName,'.emf'],printOpts{2})
    end
end

% Filtering for the whisker responding clusters
H = cell2mat(cellfun(@(x) x.Pvalues,...
    arrayfun(@(x) x.Activity, Results(indCondSubs), 'UniformOutput', 0),...
    'UniformOutput', 0)) < 0.05;
Htc = sum(H,2);
% Those clusters responding more than 80% of all whisker stimulating
% conditions
CtrlCond = contains(consCondNames,'control','IgnoreCase',true);
if ~nnz(CtrlCond)
    CtrlCond = true(size(H,2),1);
end
wruIdx = any(H(:,CtrlCond),2);
Nwru = nnz(wruIdx);

fprintf('%d whisker responding clusters:\n', Nwru);
fprintf('- %s\n',gclID{wruIdx})
%% Filter responsive?
filterIdx = true(Ne,1);
if strcmpi(filtStr, 'filtered') && nnz(wruIdx)
    filterIdx = [true; wruIdx];
end
%% Spontaneous firing rate with a bigger window
mltpl = 10;
sfrMdl = fit_poly(pfr(:,1), pfr(:,2), 1);
xyLims = ceil(max(pfr,[],1)./mltpl)*mltpl;
yeqxOpts = {'LineStyle','--','Color',[0.7,0.7,0.7],'DisplayName','y = x'};
ptOpts = {'LineStyle',':','Color','k',...
    'DisplayName',sprintf('Population trend (%.1fx%+.2f)',sfrMdl)};
scatOpts = {'MarkerEdgeColor', 'k', 'Marker', '.'};
sfrFig = figure('Name','Spontaneous firing rate','Color',[1,1,1]);
sfrAx = axes('Parent',sfrFig,'NextPlot','add');
yeqxLine = line(sfrAx, [0;min(xyLims)], [0;min(xyLims)], yeqxOpts{:});
scPts = scatter(sfrAx, pfr(:,1), pfr(:,2), scatOpts{:});
text(sfrAx, double(pfr(:,1)), double(pfr(:,2)), gclID, 'FontSize', 9)
axis(sfrAx,[0,xyLims(1),0,xyLims(2)],'square'); grid(sfrAx,'on'); 
grid(sfrAx, 'minor'); ptLine = line(sfrAx,[0;xyLims(1)],...
    [0;xyLims(1)]*sfrMdl(1) + sfrMdl(2), ptOpts{:});
legend(sfrAx, [yeqxLine, ptLine]);
xlabel(sprintf('%s_{fr} [Hz]',Conditions(cchCond(1)).name));
ylabel(sprintf('%s_{fr} [Hz]',Conditions(cchCond(2)).name));
ttlString = sprintf('Spontaneous firing rate %s vs. %s', ...
        Conditions(cchCond).name); ttlFile = cat(2, ttlString, ...
        chExps);
structAns = inputdlg('What structure are you looking at?','Structure');
if ~isempty(structAns)
    ttlString = cat(2,ttlString, sprintf(' (%s)', structAns{:}));
    ttlFile = cat(2, ttlFile, sprintf(' (%s)', structAns{:}));
    structString = structAns{:}; 
end
title(sfrAx, ttlString); 
savefig(sfrFig, fullfile(figureDir, [ttlFile, '.fig'])); clearvars sfr*;
%% Spontaneous modulation distribution
% Proportion or ratio between conditions and number of bins (Nlb)
psr = double(pfr(:,2)./pfr(:,1)); Nlb = 64;
% Color map for the areas under the quartiles
qCMap = [224, 231, 250; 123, 152, 234; 21, 50, 132];
qCMap = cat(1, qCMap, flip(qCMap(1:2,:),1))./255;
% Computing logarithmic histogram
[binCents, binEdges, logData, ts] = prepareLogBinEdges(psr, Nlb);
binCounts = histcounts(logData, binEdges, 'Normalization', 'probability');
sdFig = figure('Name','Spontaneous fr proportion','Color',[1,1,1]);
sdAx = axes('Parent', sdFig, 'NextPlot', 'add');
sdOpts = {"LineStyle","--","Color",qCMap(2,:),"LineWidth",0.5};
sdDist = semilogx(sdAx,10.^binCents, binCounts, sdOpts{:});
sdAx.XAxis.Scale = "log"; xticklabels(sdAx, xticks(sdAx))
% Computing the quartiles
grid(sdAx, 'on'); [~, ~, qVals, ~] =...
    exponentialSpread(binCounts, binCents, binCents([1,end]));
% Depicting the area under first, second & third, and fourth quartile
qVals10 = double(10.^[binCents(1), qVals([1,2,5,6]), binCents(Nlb)]); 
binCents10 = double(10.^binCents); binCtsQV = interp1(binCents10,...
    binCounts, qVals10);
sdaOpts = {"FaceAlpha", 0.6, "EdgeColor", "none", "FaceColor"};
for cq = 1:length(qVals10)-1
    qIdx = binCents10 >= qVals10(cq) & binCents10 <= qVals10(cq+1);
    area(sdAx, [qVals10(cq), binCents10(qIdx), qVals10(cq+1)],...
        [binCtsQV(cq), binCounts(qIdx), binCtsQV(cq+1)], sdaOpts{:},...
        qCMap(cq,:));
end
% Median , mean, and mode markers
[~, mxQSub] = max(binCounts); mLabels = ["Median","Mean","Mode"];
triM = 10.^[qVals(3), nanmean(logData), binCents(mxQSub)]; 
triBCts = interp1(binCents10, binCounts, triM); mCMap = flip(hsv(3),1);
for cm = 1:length(triM)
    line(sdAx, repmat(triM(cm),2,1), [0; triBCts(cm)],...
        "Color", mCMap(cm,:), "DisplayName", mLabels(cm)+" "+triM(cm))
end
triMLines = get(sdAx, 'Children');
ttlString = sprintf('Proportional change distribution %s & %s',...
    Conditions(flip(cchCond)).name);
ttlFile = cat(2, ttlString, sprintf(' %d', chExps));
if exist('structString','var')
    ttlString = cat(2, ttlString, sprintf(' (%s)', structString));
    ttlFile = cat(2, ttlFile, sprintf(' (%s)', structString));
end
lgnd = legend(sdAx, triMLines(1:length(triM))); title(sdAx, ttlString)
lgnd.Box = 'off'; lgnd.Location = 'best';
xlabel(sdAx, sprintf('%s multiplier to get %s fr', Conditions(cchCond).name))
ylabel(sdAx, "Population proportion"); saveFigure(sdFig,...
    fullfile(figureDir, ttlFile),1)
%% Modulation index
frNbin = 32; 

evFr = cellfun(@(x) mean(x,2)./diff(responseWindow), Counts(:,2),...
    'UniformOutput', 0); evFr = cat(2, evFr{:}); SNr = evFr./pfr;
if ~exist('structString','var')
    structStruct = [];
    structAns = inputdlg('What structure are you looking at?','Structure');
    if ~isempty(structAns)
        structString = structAns{:};
    end
end
mdOpts = {figureDir, chExps, structString};

[MIh(:,1), ~, ~, MIspon] = modulationDist(pfr, frNbin,...
    'Spontaneous modulation index', mdOpts{:}); 
[MIh(:,2), ~, ~, MIevok] = modulationDist(evFr, frNbin,...
    'Evoked modulation index', mdOpts{:});
ttls = "SNR modulation"; ttls(2) = ttls(1) + " responsive";
ttls(3) = ttls(1) + " non-responsive"; ci = 1; SNR = zeros(frNbin, 3);
ttls = ttls.cellstr;
for cr = [true(size(H,1),1), any(H,2), ~any(H,2)]
    [SNR(:,ci),~,~,MIsnr] = modulationDist(SNr(cr,:), frNbin,...
        ttls{ci}, mdOpts{:}); 
    ci = ci + 1;
end
% sfrBPAx = axes('Parent', sfrFig, 'Position', [0.13, 0.8, 0.775, 0.2],...
%     'Box','off', 'Color', 'none');
% boxplot(sfrBPAx, MI, 'Orientation', 'horizontal', 'Symbol', '.',...
%     'Notch', 'on'); sfrBPAx.Visible = 'off'; 
% linkaxes([sfrAx, sfrBPAx], 'x');
%% Add the response to the table
try
    All_Units = addvars(All_Units, false(size(All_Units,1),1),...
        'NewVariableNames', 'Control');
    All_Units{logical(All_Units.ActiveUnit), 'Control'} = wruIdx;
catch
    fprintf('Reran, perhaps?\n')
end
%% Response dynamics
trigTms = cell2mat(arrayfun(@(x) x.Triggers(:,1), Conditions(chCond),...
    'UniformOutput', 0)')/fs;
timesum = @(x) squeeze(sum(x,2));
clsum = @(x) squeeze(sum(x,1));
matsum = @(x) timesum(clsum(x));
stackTx = (0:Nt-1)/fs + timeLapse(1) + 2.5e-3;

[~,cnd] = find(delayFlags);
[~, tmOrdSubs] = sort(trigTms, 'ascend');
cnd = cnd(tmOrdSubs(1:length(cnd))); 
trialAx = minutes(seconds(trigTms(tmOrdSubs)));
% Modulation: distance from the y=x line.
try
    modFlags = sign(All_Units{All_Units.ActiveUnit &...
        All_Units.Control, 'Modulation'});
catch
    All_Units = addvars(All_Units, zeros(size(All_Units,1),1),...
        'NewVariableNames', 'Modulation');
    All_Units{All_Units.ActiveUnit==1,'Modulation'} =... Thalamus
       Results(1).Activity(2).Direction;
    %clInfoTotal{clInfoTotal.ActiveUnit==1,'Modulation'} =... Cortex with laser
    %    Results.Activity(1).Direction;
    modFlags = sign(All_Units{All_Units.ActiveUnit &...
        All_Units.Control, 'Modulation'});
end
% Group indeces
modVal = All_Units{All_Units.ActiveUnit == 1, 'Modulation'};
pruIdx = wruIdx & modVal > 0; % Potentiated responding
druIdx = wruIdx & modVal <= 0; % Depressed responding
nruIdx = ~any(H,2); % Non-responding what-so-ever
nmuIdx = false(size(nruIdx)); % Non-responding nor modulating
nmuIdx(nruIdx) = abs(zscore(modVal(nruIdx))) < 0.33; % With this criteria
% Thalamus
aruIdx = and(xor(H(:,1),H(:,2)),H(:,2)); % Response only A.-I.
sruIdx = and(xor(H(:,1),H(:,2)),H(:,1)); % Stopped responding after A.-I.

modFlags = modFlags > 0;
modFlags(:,2) = ~modFlags;
cmap = lines(Nccond);
cmap(CtrlCond,:) = ones(1,3)*1/3; cmap(:,:,2) = ones(Nccond,3)*0.7;

signMod = Results(1).Activity(2).Pvalues < 0.05; signMod(~wruIdx) = [];
potFlag = MIevok > 0; potFlag(~wruIdx) = [];

% modFlags = false(size(modFlags));
% modVals_rt = clInfoTotal(clInfoTotal.ActiveUnit == 1 & clInfoTotal.Control, 'Modulation');
% trnFlag = string(clInfoTotal{clInfoTotal.ActiveUnit == 1 & clInfoTotal.Control,'Region'}) == 'TRN';
% modFlags(trnFlag,:) = [modVals_rt(trnFlag),-modVals_rt(trnFlag)] > 0;

plotOpts = {'LineStyle', 'none', 'Marker', '.', 'Color', 'DisplayName'};
modLabel = {'Potentiation', 'Depression'};
clrSat = 0.5;
ax = gobjects(size(modFlags,2), 1);
condLey = consCondNames;
respLey = {'Responsive', 'Non-responsive'};
% Time steps for the 3D PSTH in ms
focusStep = 2.5;
focusPeriods = (-3:focusStep:25)';
focusPeriods(:,2) = focusPeriods + focusStep; focusPeriods = focusPeriods * 1e-3;
Nfs = size(focusPeriods,1);
fws = 1:Nfs;
auxOr = [false, true];
trialBin = 1;
Nas = [0;cumsum(NaStack./trialBin)'];
spkDomain = 0:15;
spkBins = spkDomain(1) - 0.5:spkDomain(end) + 0.5;


resTotalTrial = mod(sum(NaStack),trialBin);
resTrialPerCond = mod(NaStack, trialBin);

trialsPerCond = floor(NaStack./trialBin);
NaCs = [0;cumsum(trialsPerCond(:))];
% popMeanResp = nan(Nfs, floor(Nas(end)), 4);
popMeanResp = nan(Nfs, sum(trialsPerCond), 4);
auxResp = [H(:,1), ~any(H,2)];

for pfp = fws
    tdFig = figure('Name', 'Temporal dynamics', 'Color', [1,1,1]);
    for cmod = 1:size(modFlags,2) % Up- and down-modulation
        tcount = 1;
        ax(cmod) = subplot(size(modFlags,2),1,cmod,'Parent',tdFig);
        ax(cmod).NextPlot = 'add';
        title(ax(cmod), sprintf('%s',modLabel{cmod}));
        trSubsTotal = zeros(sum(trialsPerCond),1);
        for ccond = 1:Nccond % Cycling through the conditions (control and after-induction)
            % muTrSubs = Nas(ccond:ccond+1)+[1;0];
            % muTrSubs = [ceil(Nas(ccond)+1);floor(Nas(ccond+1))];
            muTrSubs = NaCs(ccond:ccond+1)+[1;0];
            % trSubs = tcount:trialBin:sum(NaStack(1:ccond));
            trSubs = tcount:trialBin:muTrSubs(2)*trialBin;
            % clMod = modFlags(:,cmod);
            clMod = signMod & xor(potFlag,cmod-1);
            for cr = 1:2 % responsive and non-responsive
                rsSel = [cr,cmod-1]*[1;2];
                respIdx = auxResp(:,cr);
                %respIdx = xor(H(:,1), auxOr(cr)); % Negation of H(:,2)
                %respIdx = xor(any(H,2), auxOr(cr)); % Negation of H(:,2)
                popErr = nan(Nfs, trialsPerCond(ccond));
                for cp = 1:Nfs % 'Micro' time windows
                    % Mean count for selected conditions
                    focusIdx = stackTx >= focusPeriods(cp,1) &...
                        stackTx <= focusPeriods(cp,2);
                    clCounts = timesum( discStack( [false; respIdx],...
                        focusIdx, delayFlags(:,ccond)));
                    clCounts_resh = reshape(clCounts(clMod, ...
                        1:NaStack(ccond)-resTrialPerCond(ccond)),...
                        sum(clMod), trialBin, trialsPerCond(ccond));
                    clMean = squeeze(mean(mean(clCounts_resh,2,'omitnan')));
                    popMeanResp(cp,  muTrSubs(1):muTrSubs(2),...
                        rsSel) = clMean;
                    
                    % Error per mean
                    if trialBin > 1
                        sem = squeeze(std(std(clCounts_resh,0,2,'omitnan')))./...
                            sqrt(sum(respIdx));
                    else
                        sem = std(clCounts(clMod,:))./sqrt(sum(respIdx));
                    end
                    popErr(cp, muTrSubs(1):muTrSubs(2),rsSel) = sem;
                end
                dispName = [condLey{ccond}, ' ', respLey{cr}];
                errorbar(ax(cmod), trialAx(trSubs),...
                    popMeanResp(pfp, muTrSubs(1):muTrSubs(2),rsSel)./...
                    (focusStep * 1e-3), popErr(pfp, muTrSubs(1):...
                    muTrSubs(2),rsSel)./(focusStep * 1e-3),...
                    'Color', cmap(ccond,:,cr), 'DisplayName', dispName,...
                    'LineWidth',0.1, 'LineStyle', ':', 'Marker', '.')
                clMod = true(sum(auxResp(:,2)),1);
            end
            trSubsTotal(muTrSubs(1):muTrSubs(2)) = trSubs;
            tcount = 1 + sum(NaStack(1:ccond));% + resTrialPerCond(ccond);
        end
        ctMu = mean(popMeanResp(pfp, (NaCs(1)+1):NaCs(2), [cmod,1]*[2;-1]));
        if ~ctMu
            ctMu = 1;
        end
        aiMu = mean(popMeanResp(pfp, (NaCs(2)+1):NaCs(3), [cmod,1]*[2;-1]));
        if ~aiMu 
            aiMu = 1;
        end
        yyaxis(ax(cmod), 'right')
        % plot(trialAx(1:trialBin:sum(NaStack)),...
        plot(trialAx(trSubsTotal), popMeanResp(pfp,:,[cmod,1]*[2;-1]),...
            'LineStyle', 'none', 'Color',[0.7,0.7,0.7]);
        ax(cmod).YAxis(2).Limits = ax(cmod).YAxis(1).Limits*focusStep*1e-3;
        tpMlt = floor(ax(cmod).YAxis(2).Limits(2)/ctMu);
        yticks(ax(cmod),ctMu*(1:tpMlt)'); yticklabels(num2str((1:tpMlt)'))
        set(get(ax(cmod),'YAxis'),'Color',[0.4,0.4,0.45]);
        if cmod == 1
            ylabel(ax(cmod),'Proportional change');
        end
        yyaxis(ax(cmod),'left')
        
        cmap(ccond,:,1) = brighten(cmap(ccond, :, 1), clrSat);
        clrSat = -clrSat;
    end
    ylabel(ax(cmod), 'Spikes / Time window [Hz]'); xlabel(ax(cmod),...
        sprintf('(%.1f - %.1f [ms]) Trial_{%d trials} [min]',...
        focusPeriods(pfp,:)*1e3, trialBin))
%     linkaxes(ax,'xy')
    tdFigName = string(...
        sprintf('Temporal dynamics exps %sFW%.1f-%.1f ms TB %d trials (f, prop, lines & bars)',...
        sprintf('%d ', chExps), focusPeriods(pfp,:)*1e3, trialBin));
%     if ~isempty(dirNames) && exist('subFoldSel','var')
%         tdFigName = tdFigName + " sf-" + dirNames{subFoldSel};
%     end
    tempFigName = fullfile(figureDir, tdFigName);
    saveFigure(tdFig, tempFigName);
end

%% 3D Visualization of the spiking dynamics
redundantFlag = false(size(popMeanResp,3),1);
lvls = 128;
redundantFlag(2) = length(redundantFlag)==4;
popMeanResp(:,:,redundantFlag) = [];
popMeanFreq = popMeanResp./(focusStep * 1e-3);
srfOp = {'FaceColor','interp','EdgeColor','none'};
tpVal = max(popMeanFreq(:));
NaCum = [0;cumsum(NaStack(:))];
% Colormap for all modulated neurons
clrMap = jet(lvls); [m, b] = lineariz([0;tpVal], lvls, 1);
[Ntw, Nbt, Nmn] = size(popMeanFreq);
clrSheet = clrMap(round(popMeanFreq*m + b),1:3);
clrSheet = reshape(clrSheet, Ntw, Nbt, Nmn, 3);
modLey = ["potentiated";"depressed";"non-responding"];
for cmod = 1:size(popMeanFreq,3)
    summFig = figure('Color', [1,1,1], 'Colormap', clrMap);
    ax = axes('Parent', summFig, 'NextPlot', 'add','Clipping','off',...
        'View',[-37.5, 30]);
    caxis([0, tpVal]);
    tcount = 1;
    for ccond = 1:Nccond
        muTrEdges = NaCs(ccond:ccond+1)+[1;0];
        muTrSubs = muTrEdges(1):muTrEdges(2);
        trEdges = NaCum(ccond:ccond+1)+[1;0]+[resTrialPerCond(ccond);0];
        trSubs = trEdges(1):trialBin:trEdges(2);
        clrSheetSq = squeeze(clrSheet(:,muTrSubs,cmod,:));
        surf(trialAx(trSubs), 1e3*focusPeriods(:,1), popMeanFreq(:,...
            muTrSubs, cmod), clrSheetSq, srfOp{:}, 'Parent', ax); 
    end
    cbOut = colorbar('Parent', summFig); cbOut.Label.String = ...
        'Response [Hz]';box(ax,'off'); grid(ax,'on'); 
    xlim(ax, trialAx([NaCum(1)+1, NaCum(Nccond+1)])); ylim(ax,...
        focusPeriods([1,end],1)*1e3); xlabel(ax, 'Trial time [min]'); 
    ylabel(ax, 'Within-trial time [ms]'); zlabel(ax,...
        'Spike / within-trial window [Hz]'); title(ax, sprintf(...
        '%s clusters', capitalizeFirst(modLey(cmod))))
    sumFigName = fullfile(figureDir,...
        sprintf('Spike-dynamics 3D %s exp%s FP%.2f - %.2f ms FW%.2f ms TB %d trial(s)',...
        modLey(cmod), sprintf(' %d', chExps), focusPeriods([1,end])*1e3,...
        focusStep, trialBin));
    if numel(chExps) == 1 && ~isempty(dirNames) && exist('subFoldSel','var')
        sumFigName = cat(2, sumFigName,...
            sprintf(' sf-%s', dirNames{subFoldSel}));
    end
    summFig.PaperType = 'A4';
    saveFigure(summFig, sumFigName, false);
end

%% Spontaneous ISIs for different cluster groups
% Logarithmic spacing for the histogram counts
lDt = 0.01;
logSpkHD = [-log10(2e3); 1] + [-1;1]*(lDt/2);
logSpkEdges = logSpkHD(1):lDt:logSpkHD(2);logSpkDom = logSpkHD +...
    [1;-1]*(lDt/2); logSpkDom = logSpkDom(1):lDt:logSpkDom(2);
lgStTmAx = 10.^logSpkDom';
% Potentiated (2), non-modulated (1), depressed (0) clusters'
% classification
modCat = categorical(...
    sign(All_Units{All_Units.ActiveUnit == 1,'Modulation'}) + 1);
modLey = ["depressed";"non-modulated";"potentiated"];
% Conditions for the plot
condLey = string(consCondNames)';
respLey = ["responsive";"non-responsive"];
% Responsive clusters in any condition (control AND after induction)
respIdx = any(H,2);
% respIdx = H(:,1); % Control only
% respIdx = H(:,2); % After-induction only
% % Responsive and TRN 
% respIdx = any(H,2) &...
%     string(clInfoTotal{clInfoTotal.ActiveUnit == 1, 'Region'}) == 'TRN';

% Auxiliary variables for the loop
isiFigs = gobjects(6,1);
% Combinatorial loop
for cr = 1:2 % Responsive and non-responsive
    riveFlag = xor(respIdx, cr-1); % 0 passes, 1 negates    
    for cmod = 0:2 % depressed - non-modulalted - potentiated
        lc = [cr-1,cmod+1] * [3;1];
        modFlag = modCat == num2str(cmod);
        isiFigs(lc) = figure('Color',[1,1,1]);
        htotal = zeros(length(logSpkDom),Nccond);
        totalErr = htotal;
        for ccond = 1:Nccond % Condition numbers
            hcond = cellfun(@(x) histcounts(log10(x/fs), logSpkEdges),...
                pcondIsi(riveFlag & modFlag, ccond), 'UniformOutput', 0);
            hcond = cellfun(@(x) x./sum(x), hcond, 'UniformOutput', 0);
            hcond = cat(1,hcond{:}); totalErr(:,ccond) =...
                std(hcond,'omitnan');%./sqrt(sum(~emptFlag));
            hcond = mean(hcond,1,'omitnan');
            if isempty(hcond)
                fprintf(1, 'No spikes!\n')
                continue
            end
            hcond = hcond./sum(hcond); htotal(:,ccond) = hcond;
        end
        ax = axes('Parent', isiFigs(lc));
        semilogx(ax, lgStTmAx, cumsum(htotal)); ylim(ax,[0,1]);
        ax.NextPlot = 'add'; ax.ColorOrderIndex = 1; 
        semilogx(ax, lgStTmAx, cumsum(htotal) + totalErr,'LineStyle',':')
        ax.ColorOrderIndex = 1; semilogx(ax, lgStTmAx, cumsum(htotal) -...
            totalErr,'LineStyle',':')
        xlim(ax,10.^logSpkHD); box(ax,'off'); grid('on'); 
        xticklabels(ax, xticks(ax)*1e3); 
        xlabel(ax,'Inter-spike interval [ms]'); 
        ylabel('Cumulative probability');
        title(ax, "Cumulative ISI: "+respLey(cr)+" & "+modLey(cmod+1))
        lgnd = legend(ax, condLey); set(lgnd, 'Location','best', 'Box', 'off');
        ciName = "Cumulative ISI, "+respLey(cr)+" & "+modLey(cmod+1) + ...
            ", exp"+string(sprintf(' %d', chExps))+ " LB 10^"+string(lDt);
        ciFilePath = fullfile(figureDir, ciName);
        if numel(chExps) == 1 && ~isempty(dirNames)
            ciFilePath = ciFilePath + ' sf-' + dirNames{subFoldSel};
        end
        saveFigure(isiFigs(lc),ciFilePath);
    end
end
%% Getting the relative spike times for the whisker responsive units (wru)
% For each condition, the first spike of each wru will be used to compute
% the standard deviation of it.
configStructure = struct('Experiment', fullfile(dataDir,expName),...
    'Viewing_window_s', timeLapse, 'Response_window_s', responseWindow,...
    'BinSize_s', binSz, 'Trigger', struct('Name', condNames{chCond},...
    'Edge',onOffStr), 'ConsideredConditions',{consCondNames});
cellLogicalIndexing = @(x,idx) x(idx);
isWithinResponsiveWindow =...
    @(x) x > responseWindow(1) & x < responseWindow(2);

firstSpike = zeros(Nwru,Nccond);
M = 16;
binAx = responseWindow(1):binSz:responseWindow(2);
condHist = zeros(size(binAx,2)-1, Nccond);
firstOrdStats = zeros(2,Nccond);
condParams = zeros(M,3,Nccond);
txpdf = responseWindow(1):1/fs:responseWindow(2);
condPDF = zeros(numel(txpdf),Nccond);
csvSubfx = sprintf(' SW%.1f-%.1f ms RW%.1f-%.1f ms VW%.1f-%.1f ms (%s).csv',...
    spontaneousWindow*1e3, responseWindow*1e3, timeLapse*1e3, filtStr);
existFlag = false;
condRelativeSpkTms = cell(Nccond,1);
relativeSpkTmsStruct = struct('name',{},'SpikeTimes',{});
csvDir = fullfile(dataDir, 'SpikeTimes');
if ~exist(csvDir,'dir')
    iOk = mkdir(csvDir);
    if ~iOk
        fprintf(1, 'The ''Figure'' folder was not created!\n')
        fprintf(1, 'Please verify your writing permissions!\n')
    end
end
for ccond = 1:size(delayFlags,2)
    csvFileName = fullfile(csvDir,[expName,' ', sprintf('%d ',chExps),...
        consCondNames{ccond}, csvSubfx]);
    relativeSpikeTimes = getRasterFromStack(discStack,~delayFlags(:,ccond),...
        filterIdx(3:end), timeLapse, fs, true, false);
    relativeSpikeTimes(:,~delayFlags(:,ccond)) = [];
    relativeSpikeTimes(~filterIdx(2),:) = [];
    condRelativeSpkTms{ccond} = relativeSpikeTimes;
    %     respIdx = cellfun(isWithinResponsiveWindow, relativeSpikeTimes,...
    %         'UniformOutput',false);
    clSpkTms = cell(size(relativeSpikeTimes,1),1);
    if exist(csvFileName, 'file') && ccond == 1
        existFlag = true;
        ansOW = questdlg(['The exported .csv files exist! ',...
            'Would you like to overwrite them?'],'Overwrite?','Yes','No','No');
        if strcmp(ansOW,'Yes')
            existFlag = false;
            fprintf(1,'Overwriting... ');
        end
    end
    fID = 1;
    if ~existFlag
        fID = fopen(csvFileName,'w');
        fprintf(fID,'%s, %s\n','Cluster ID','Relative spike times [ms]');
    end
    rsclSub = find(filterIdx(2:end))-1;
    % If a subcript is zero, don't substract.
    if any(~rsclSub)
        rsclSub = rsclSub + 1;
    end
    for cr = 1:size(relativeSpikeTimes, 1)
        clSpkTms(cr) = {sort(cell2mat(relativeSpikeTimes(cr,:)))};
        if fID > 2
            fprintf(fID,'%s,',gclID{rsclSub(cr)});
            fprintf(fID,'%f,',clSpkTms{cr});fprintf(fID,'\n');
        end
    end
    if fID > 2
        fclose(fID);
    end
    relativeSpkTmsStruct(ccond).name = consCondNames{ccond};
    relativeSpkTmsStruct(ccond).SpikeTimes = condRelativeSpkTms{ccond};
end
spkFileName =...
    sprintf('%s exps%s RW%.2f - %.2f ms SW%.2f - %.2f ms VW%.2f - %.2f ms %s (%s) exportSpkTms.mat',...
    expName, sprintf(' %d',chExps), responseWindow*1e3, spontaneousWindow*1e3,...
    timeLapse*1e3, Conditions(chCond).name, filtStr);
if ~exist(spkFileName,'file')
    save(fullfile(csvDir, spkFileName), 'relativeSpkTmsStruct',...
        'configStructure')
end

%% ISI PDF & CDF
areaFig = figure('Visible','on', 'Color', [1,1,1],'Name','ISI probability');
areaAx = gobjects(2,1);
lDt = 0.01;
logSpkHD = [-log10(1e3); log10(0.05)] + [-1;1]*(lDt/2); % 2000 = 1/0.0005
logSpkEdges = logSpkHD(1):lDt:logSpkHD(2);logSpkDom = logSpkHD +...
    [1;-1]*(lDt/2); logSpkDom = logSpkDom(1):lDt:logSpkDom(2);
lgStTmAx = 10.^logSpkDom';
% cmap = [0,0,102;... azul marino
%     153, 204, 255]/255; % azul cielo
cmap = lines(Nccond);
%areaOpts = {'EdgeColor', 'none', 'FaceAlpha', 0.3, 'FaceColor'};
areaOpts = {'Color','LineStyle','--','LineWidth',1.5};
ley = ["Potentiated", "Depressed"];
isiPdf = zeros(length(logSpkDom),2*Nccond);
for cmod = 1:2 % Potentiated and depressed clusters
    areaAx(cmod) = subplot(1,2,cmod,'Parent',areaFig);
    Nccl = sum(modFlags(:,cmod));
    for ccond = 1:Nccond
        cnt = [cmod-1,ccond] * [2,1]';
        ISI = cellfun(@(x) diff(x(x >= 0 & x <= 0.05)), ...
            relativeSpkTmsStruct(ccond).SpikeTimes(modFlags(:,cmod),:),...
            'UniformOutput', 0);
        ISIpc = arrayfun(@(x) cat(2, ISI{x,:}), (1:size(ISI,1))',...
            'UniformOutput', 0);
        hisi = cellfun(@(x) histcounts(log10(x), logSpkEdges), ISIpc,...
            'UniformOutput', 0); 
        hisi = cellfun(@(x) x/sum(x), hisi, 'UniformOutput', 0);
        hisi = cat(1,hisi{:});
        hisi = mean(hisi,1,'omitnan'); hisi = hisi./sum(hisi);
        if ~isempty(hisi)
            isiPdf(:,cnt) = hisi;
        end
        %ISI_merge = [ISI{:}];
        %lISI = log10(ISI_merge);
        %hisi = histcounts(lISI, logSpkEdges);
        %spkPerT_C = hisi./(NaStack(ccond)*Nccl);
        %isiPdf(:,cnt) = spkPerT_C/sum(spkPerT_C);
        semilogx(areaAx(cmod), lgStTmAx, isiPdf(:,cnt),...
            areaOpts{1}, cmap(ccond,:), areaOpts{4:5});
        if ccond == 1
            hold(areaAx(cmod), 'on');
            areaAx(cmod).XAxis.Scale = 'log';
            areaAx(cmod).XLabel.String = "ISI [ms]";
            areaAx(cmod).YLabel.String = "ISI probability";
        end
        yyaxis(areaAx(cmod) ,'right')
        
        semilogx(areaAx(cmod), lgStTmAx, cumsum(isiPdf(:,cnt)),...
            areaOpts{1}, cmap(ccond,:), areaOpts{2:3})
        ylim(areaAx(cmod), [0,1]); areaAx(cmod).YAxis(2).Color = [0,0,0];
        ylabel(areaAx(cmod), 'Cumulative probability');
        yyaxis(areaAx(cmod) ,'left'); set(areaAx(cmod),'Box','off')
        xticklabels(xticks*1e3)
    end
    title(areaAx(cmod), sprintf('ISI PDF for %s clusters',ley(cmod)));
    grid(areaAx(cmod),'on')
end
legend(areaAx(cmod),consCondNames,'Location','best')
linkaxes(areaAx,'xy')
evokIsiFigPath = fullfile(figureDir, "Evoked ISI, potentiated & depressed" +...
    " clusters, exp"+string(sprintf(' %d',chExps))+" LB 10^"+string(lDt));
saveFigure(areaFig, evokIsiFigPath)

%% Ordering PSTH
orderedStr = 'ID ordered';
dans = questdlg('Do you want to order the PSTH other than by IDs?',...
    'Order', 'Yes', 'No', 'No');
ordSubs = 1:nnz(filterIdx(2:Ncl+1));
pclID = gclID(filterIdx(2:Ncl+1));
if strcmp(dans, 'Yes')
    if ~exist('clInfoTotal','var')
        All_Units = getClusterInfo(fullfile(dataDir,'cluster_info.tsv'));
    end
    % varClass = varfun(@class,clInfo,'OutputFormat','cell');
    [ordSel, iOk] = listdlg('ListString', All_Units.Properties.VariableNames,...
        'SelectionMode', 'multiple');
    orderedStr = [];
    ordVar = All_Units.Properties.VariableNames(ordSel);
    for cvar = 1:numel(ordVar)
        orderedStr = [orderedStr, sprintf('%s ',ordVar{cvar})]; %#ok<AGROW>
    end
    orderedStr = [orderedStr, 'ordered'];
    
    if ~strcmp(ordVar,'id')
        [~,ordSubs] = sortrows(All_Units(pclID,:),ordVar);
    end
end
%% Plot PSTH
goodsIdx = logical(All_Units.ActiveUnit);
csNames = fieldnames(Triggers);
Nbn = diff(timeLapse)/binSz;
if (Nbn - round(Nbn)) ~= 0
    Nbn = ceil(Nbn);
end
PSTH = zeros(nnz(filterIdx) - 1, Nbn, Nccond);
for ccond = 1:Nccond
    figFileName = sprintf('%s %s %sVW%.1f-%.1f ms B%.1f ms RW%.1f-%.1f ms SW%.1f-%.1f ms %sset %s (%s)',...
        expName, Conditions(consideredConditions(ccond)).name,...
        sprintf('%d ', chExps), timeLapse*1e3,...
        binSz*1e3, responseWindow*1e3, spontaneousWindow*1e3, onOffStr,...
        orderedStr, filtStr);
    [PSTH(:,:,ccond), trig, sweeps] = getPSTH(discStack(filterIdx,:,:),...
        timeLapse, ~delayFlags(:,ccond), binSz, fs);
    stims = mean(discStack(:,:,delayFlags(:,ccond)),3);
    stims = stims - median(stims,2);
    for cs = 1:size(stims,1)
        if abs(log10(var(stims(cs,:),[],2))) < 13
            [m,b] = lineariz(stims(cs,:),1,0);
            stims(cs,:) = m*stims(cs,:) + b;
        else
            stims(cs,:) = zeros(1,Nt);
        end
    end
    figs = plotClusterReactivity(PSTH(ordSubs,:,ccond), trig, sweeps,...
        timeLapse, binSz, [{Conditions(consideredConditions(ccond)).name};...
        pclID(ordSubs)], strrep(expName,'_','\_'));
    configureFigureToPDF(figs);
    figs.Children(end).YLabel.String = [figs.Children(end).YLabel.String,...
        sprintf('^{%s}',orderedStr)];
    if ~exist([figFileName,'.pdf'], 'file') || ~exist([figFileName,'.emf'], 'file')
        print(figs, fullfile(figureDir,[figFileName, '.pdf']),'-dpdf','-fillpage')
        print(figs, fullfile(figureDir,[figFileName, '.emf']),'-dmeta')
    end
end

%% Comparing the PSTHs for all conditions

txpsth = (0:Nbn-1)*binSz + timeLapse(1) + 2.5e-3;
focusWindow = [-5, 30]*1e-3;
focusIdx = txpsth >= focusWindow(1) & txpsth <= focusWindow(2);
txfocus = txpsth(focusIdx);
modLabels = {'potentiated', 'depressed'};
%modLabels = {'non-responding','non-modulated'};
lnClr = lines(Nccond);
for cmod = 1:2
    psthFig = figure('Color', [1,1,1], 'Name', 'Condition PSTH comparison',...
        'Visible', 'off');
    PSTH_raw = squeeze(sum(PSTH(modFlags(:,cmod),:,:),1));
    PSTH_trial = PSTH_raw./(NaStack.*sum(modFlags(:,cmod)));
    PSTH_prob = PSTH_raw./sum(PSTH_raw,1);
    PSTH_all = cat(3, PSTH_raw, PSTH_trial, PSTH_prob);
    axp = gobjects(4,1);
    subpltsTitles = {sprintf('PSTH per condition, %s clusters',modLabels{cmod}),...
        'Cumulative density function', 'Cumulative sum for normalized spikes'};
    yaxsLbls = {'Spikes / (Trials * Cluster)', 'Spike probability',...
        'Spike number'};
    for cax = 1:3
        axp(cax) = subplot(2, 2, cax, 'Parent', psthFig, 'NextPlot', 'add');
        for ccond = 1:Nccond
            plotOpts = {'DisplayName', consCondNames{ccond},'Color',...
                lnClr(ccond,:), 'LineStyle','-.'};
            switch cax
                case 1 % Plot the trial-normalized PSTH; page #2
                    plot(axp(cax), txfocus, PSTH_all(focusIdx,ccond,2),...
                        plotOpts{1:4})
                case 2 % Plot the cumulative probability function; page 3
                    PSTH_aux = PSTH_all(focusIdx, ccond, 3);
                    PSTH_aux = PSTH_aux./sum(PSTH_aux);
                    plot(axp(cax), txfocus, PSTH_aux, plotOpts{1:4})
                    yyaxis(axp(cax), 'right'); plot(axp(cax), txfocus,...
                        cumsum(PSTH_aux), plotOpts{:}) 
                    ylim(axp(cax), [0,1]); ylabel(axp(cax),...
                        'Cumulative probability'); set(axp(cax).YAxis(2),...
                        'Color',0.2*ones(3,1))
                    yyaxis(axp(cax), 'left'); 
                case 3 % Plot the cumulative sum for the mean spikes; page 2
                    plot(axp(cax), txfocus, ...
                        cumsum(PSTH_all(focusIdx, ccond, 2)), plotOpts{1:4})
            end
        end
        title(axp(cax), subpltsTitles{cax})
        ylabel(axp(cax), yaxsLbls{cax})
        if cax == 3
            xlabel(axp(cax), sprintf('Time_{%.2f ms} [s]', binSz*1e3))
            lgnd = legend(axp(cax), 'show'); 
            set(lgnd, 'Location', 'best', 'Box', 'off')
        end
    end
    axp(4) = subplot(2,2,4, 'Parent', psthFig);
    PSTH_diff = 100 * ((PSTH_prob(:,2)./PSTH_prob(:,1)) - 1);
    bar(axp(4), txfocus(PSTH_diff(focusIdx) > 0), PSTH_diff(PSTH_diff > 0 & focusIdx'),...
        'FaceColor', [51, 204, 51]/255, 'DisplayName', 'Potentiation'); hold on
    bar(axp(4), txfocus(PSTH_diff(focusIdx) <= 0), PSTH_diff(PSTH_diff <= 0 & focusIdx'),...
        'FaceColor', [204, 51, 0]/255, 'DisplayName', 'Depression');
    axp(4).Box = 'off'; ylabel(axp(4), '%'); title(axp(4), 'Percentage of change')
    xticks(axp(4),''); linkaxes(axp, 'x'); lgnd = legend(axp(4),'show'); 
    lgnd.Box = 'off'; lgnd.Location = 'best';  psthFig.Visible = 'on';
    %psthFig = configureFigureToPDF(psthFig);
    psthFigFileName = sprintf('%s %sPSTH %sRW%.2f-%.2f ms FW%.2f-%.2f ms %s clusters',...
        expName, sprintf('%d ',chExps), sprintf('%s ',string(consCondNames)),...
        responseWindow*1e3, focusWindow*1e3, modLabels{cmod});
    psthFigFileName = fullfile(figureDir,psthFigFileName);
    arrayfun(@(x) set(x, 'Color', 'none'), axp)
    if numel(chExps) == 1 && ~isempty(dirNames)
       psthFigFileName = string(psthFigFileName) + " sf-" + dirNames{subFoldSel};
    end
    saveFigure(psthFig, string(psthFigFileName))
end


%% Waveform analysis
% pltDot = {'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 5};
% fprintf(1, 'This is the waveform analysis section\n');
% mg2db = @(x) 20*log10(abs(x)); [Nws, Ncw] = size(popClWf);
% Np = 2^(nextpow2(Nws)-1) - Nws/2; tx = (0:Nws-1)/fs;
% pwf_m = popClWf - mean(popClWf); pwf_w = pwf_m .* chebwin(Nws, 150);
% pwf_p = padarray(padarray(pwf_w, [floor(Np),0], 'pre'),...
%     [ceil(Np),0], 'post'); pwf_n = pwf_p./max(abs(pwf_p));
% ltx = ((0:size(pwf_p,1)-1)' - size(pwf_n,1)/2)/fs;
% ft = fftshift(fft(pwf_n,[],1),1); dw = fs/size(ft,1); mg = mg2db(ft);
% ph = angle(ft); wx = (0:size(ft,1)-1)'*dw - fs/2;
% mg = mg(wx>=0,:); ph = ph(wx>=0,:); wx = wx(wx>=0); [~, mxWxSub] = max(mg);
% wcp = getWaveformCriticalPoints(mg, size(ft,1)/fs);
% pwc = cellfun(@(x) x(1), wcp(:,1)); mxW = wx(mxWxSub);
% 
% tcp = getWaveformCriticalPoints(pwf_n, fs);
% featWf = getWaveformFeatures(pwf_n, fs);
% params = emforgmm(log(featWf(:,1)), 3, 1e-7, 0);
% logDomain = (round(min(log(featWf(:,1)))*1.05,1):0.01:...
%     round(max(log(featWf(:,1)))*0.95,1))';
% p_x = genP_x(params, logDomain);
% probCriticPts = getWaveformCriticalPoints(p_x', 100);
% probCriticPts = cellfun(@(x) x + logDomain(1), probCriticPts,...
%     'UniformOutput', 0); logThresh = probCriticPts{1,1}(2);
% time_wf = log(featWf(:,1)) > logThresh;
% 
% [m, b] = lineariz(pwc, 1, -1); pwc_n = pwc*m + b;
% params_freq = emforgmm(pwc_n, 3, 1e-7, 0); wDomain = (-1.05:0.01:1.05)';
% p_wx = genP_x(params_freq, wDomain);
% probCriticPts_w = getWaveformCriticalPoints(p_wx', 100);
% probCriticPts_w = cellfun(@(x) x + wDomain(1), probCriticPts_w,...
%     'UniformOutput', 0); wThresh = probCriticPts_w{1,1}(2);
% freq_wf = pwc_n < wThresh;
% tf_groups = [...
%     ~time_wf & ~freq_wf,...
%     ~freq_wf & time_wf,...
%     freq_wf & ~time_wf,...
%     freq_wf & time_wf];
% % meanWf = cellfun(@(x) mean(x,2), popClWf(:,2),'UniformOutput', 0);
% % meanWf = cat(2,meanWf{:}); featWf = getWaveformFeatures(meanWf, fs);
% % wFeat = whitenPoints(featWf);
%% Adaptation
if diff(timeLapse) > 0.5
dt = 1/8;
onst = (0:7)'*dt;
ofst = (0:7)'*dt + 0.05;
onrpWins = [onst+5e-3, onst+3e-2];
ofrpWins = [ofst+5e-3, ofst+3e-2];
onrpIdx = txpsth >= onrpWins(:,1) & txpsth <= onrpWins(:,2);
ofrpIdx = txpsth >= ofrpWins(:,1) & txpsth <= ofrpWins(:,2);
ptsOn = zeros(size(onrpIdx,1),size(PSTH_prob,2),2); % time, magnitude
ptsOf = ptsOn;
for ccond = 1:size(PSTH_prob,2)
    for crw = 1:size(onst,1)
        [mg, tmSub] = max(PSTH_prob(onrpIdx(crw,:),ccond));
        tmWinSub = find(onrpIdx(crw,:));
        ptsOn(crw, ccond, 1) = txpsth(tmWinSub(tmSub));
        ptsOn(crw, ccond, 2) = mg;
        [mg, tmSub] = max(PSTH_prob(ofrpIdx(crw,:),ccond));
        tmWinSub = find(ofrpIdx(crw,:));
        ptsOf(crw, ccond, 1) = txpsth(tmWinSub(tmSub));
        ptsOf(crw, ccond, 2) = mg;
    end
end

else
    
end





