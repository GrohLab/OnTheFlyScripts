% function ISIbox = TriggeredISIs(clInfo,sortedData,Conditions,responseWindow,fs,ISIspar,onOffStr)
% spontaneousWindow = -flip(responseWindow);
ConsConds = Conditions(3:11);
nCond = length(ConsConds);
% sortedData = sortedData(:,1);
for ChCond = 1:nCond
    ISIhist(ChCond).name = ConsConds(ChCond).name;
    ISIhist(ChCond).Vals(1).name = 'Spontaneous';
    ISIhist(ChCond).Vals(2).name = 'Evoked';
end

for ChCond = 1:nCond
    name = [ConsConds(ChCond).name, '_MR'];
    
    if contains(ConsConds(ChCond).name, 'Laser_Con', 'IgnoreCase', true)
        name = [ConsConds(ChCond-2).name, '_MR'];
    elseif contains(ConsConds(ChCond).name, ['ch_Laser'], 'IgnoreCase', true)
       name = [ConsConds(ChCond-1).name, '_MR']; % make this more robust to match laser intensity
    end
    
    Ind = find(clInfo.(name));
    ID = clInfo.id(Ind);
    id = find(ismember(gclID, ID) == false)'; % contains will give multiple units when looking for e.g. cl45
%     spkLog = StepWaveform.subs2idx(round(sortedData{goods(1),2}*fs),Ns);
    % spkSubs replaces round(sortedData{goods(1),2}*fs) for the rest of the
    % clusters
    % Subscript column vectors for the rest good clusters
    for wIndex = 1:2
        if wIndex == 1
            Window = spontaneousWindow;
        else
            Window = responseWindow;
        end
        [~, isiStack] = getStacks(false,ConsConds(ChCond).Triggers, onOffStr,...
            Window,fs,fs,[],ISIspar(id,:));
        lInda = isiStack > 0; 
        % timelapse becomes spontaneousWindow for pre-trigger, and responseWindow
        % for post
        for histInd = 1: length(id)
            
            figure('Visible','off');
            hisi = histogram(log10(isiStack(histInd,:,:)), 'BinEdges', log10(0.001):0.01:log10(10));
            ISIhist(ChCond).Vals(wIndex).cts{histInd} = hisi.BinCounts;
            ISIhist(ChCond).Vals(wIndex).bns{histInd} = (hisi.BinEdges(1:end-1) + hisi.BinEdges(2:end))/2;
            ISIhist(ChCond).Vals(wIndex).TriggeredIsI = isiStack;
            close gcf;
        end
    end
end
%% ISIs and CumISIs
for ChCond = 1:nCond
    for a = 1:length(ISIhist(ChCond).Vals(wIndex).cts)
        ISIhist(ChCond).Vals(1).ISI{a} = ISIhist(ChCond).Vals(1).cts{a}./sum(ISIhist(ChCond).Vals(1).cts{a});
        ISIhist(ChCond).Vals(2).ISI{a} = ISIhist(ChCond).Vals(2).cts{a}./sum(ISIhist(ChCond).Vals(2).cts{a});
        ISIhist(ChCond).Vals(1).CumISI{a} = cumsum(ISIhist(ChCond).Vals(1).ISI{a});
        ISIhist(ChCond).Vals(2).CumISI{a} = cumsum(ISIhist(ChCond).Vals(2).ISI{a});
    end
end
%% Saving ISIhist
save(fullfile(dataDir,[expName,'nonMR_ISIhistBase10.mat']), 'ISIhist', 'ConsConds', '-v7.3');