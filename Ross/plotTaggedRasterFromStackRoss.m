function plotTaggedRasterFromStack(discreteStack, timeLapse, fs, figTitle, ax, rasclr)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

% Ne is the number of 'events', namely signals that are considered in the
% stack
% Nt is the time axis for the chosen window
% Na is the number of alignment points in this stack
[Ne, Nt, Na] = size(discreteStack);
% Time axis
tx = 0:1/fs:(Nt-1)/fs;
tx = tx + timeLapse(1);
AX_FLAG = true;
if ~exist('ax','var') || isempty(ax)
    figure('Name',['Raster Plot ', figTitle],'Color',[1,1,1]);
    AX_FLAG = false;
end
cmap = brighten(copper(Ne-1),-0.8);
FIRST_FLAG = true;
for cse = 2:Ne
    % For each spike train
    for cap = Na:-1:1
        % For each alignment point
        upEdge = diff(discreteStack(cse,:,cap)) > 0;
        if sum(upEdge) ~= 0
            % If there are events in this alignment point
            downEdge = diff(discreteStack(cse,:,cap)) < 0;
            isSpike = upEdge(1:end-1) - downEdge(2:end);
            if sum(isSpike) == 0
                % If the event contains spikes
                if FIRST_FLAG
                    hold on
                    FIRST_FLAG = false;
                end
                xspks = tx(squeeze(discreteStack(cse,:,cap)));
                lvl = (cse - 2)*Na + cap;
                if AX_FLAG
                    plot(ax,xspks,lvl*ones(1,numel(xspks)),...
                        'LineStyle','none','Marker','.',...
                        'MarkerFaceColor',rasclr,'MarkerSize',5,...
                        'Color',rasclr)
                else
                    plot(xspks,lvl*ones(1,numel(xspks)),...
                        'LineStyle','none','Marker','.',...
                        'MarkerFaceColor',rasclr,'MarkerSize',5,...
                        'Color',rasclr)
                end
            end
        end
    end
end
axis([timeLapse(1),timeLapse(2),1,Na*(Ne-1)])

end

