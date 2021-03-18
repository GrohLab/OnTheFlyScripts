
% This script gives spike rate bar graphs for user-specified bin width for
% all units in a recording.

% We need the bin size.
promptStrings = {'Bin size [s]:'};
defaultInputs = {'0.05',};
answ = inputdlg(promptStrings,'Inputs', [1, 30],defaultInputs);
binSz = str2double(answ(1));

   

% We also need the sampling frequency, which can change from recording
% to recording.
promptStrings = {'Sampling Frequency (fs)'};
defaultInputs = {'3.003003003003003e+04',};
answ = inputdlg(promptStrings,'Inputs', [1, 30],defaultInputs);
fs = str2double(answ(1));

% This spiketrain variable is just dummy data.
%RAM: this doesn't run for me because fs is not necessarily an integer
%could also use randi command to produce integer spike times
spiketrain = randi(fs*3600, 3);
spiketrainlogical = spiketrain > 0.5;

    
% binSamples is the number of elements in spiketrain per bin.
binSamples = fs*binSz;
    
% Now we need the no. of bins for the split up the histogram,
% which is the length of the spiketrain vector divided by the binSamples. 

nBins = round(size(spiketrainlogical, 1)/binSamples);

% The reason we round is that nBins may not be an integer, which it
% needs to be for the for-loop.
% This will mean that the last bin for each recording may be a bit
% off....(I can live with that...)


% We now need to create a matrix of row size nBins, where each column represents a different cluster,
% and we need to sum our samples bin by bin.


counts = zeros(nBins,size(spiketrainlogical, 2));
szT = size(spiketrainlogical, 2);
% We're going to replace each element 1 by 1 for the sum of the elements of spike train for the given bin size. 
% We're going to go cluster by cluster, each cluster being a new column.

for b = 1:szT
    
    for a = 1:nBins
        counts(a,b) = sum(spiketrainlogical(1 + binSamples*(a-1): a*binSamples, b));
    end
    rate = counts/binSz;
    figure; bar(rate(:,b));
end
% Rate will be given in Counts per Second.
% If you had 20 counts in a half-second bin size, the rate would be 40
% counts = 20/ bin size.
% So you're dividing counts by the bin size.

% We've churned out the firing rate per cluster fo a given bin width.
% Lets plot them next to eachother to get population activity.
% Experiment time in msecs for the RateMap x-axis.
exptT = [0:nBins]'*(binSz/0.001);
 
figure; imagesc(exptT, [1:szT], rate');
% x-axis = exptT, y-axis = [1:szT], plot = rate'.




