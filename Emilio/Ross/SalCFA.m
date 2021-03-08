% First, un PainAnalysis  to adda data to clInfo tables, and then add this
% table to VPL table



%% Determining nShanks

tShanks = sum(VPL.shank == [1:100]);
nShanks = sum(tShanks ~= false);

%% Spontaneous Rates

figure('Name', 'Spontaneous Rates', 'Color', 'white'); 

d = 0;

for a = 1: length(consCondNames)
            
        sInd = find(VPL.ActiveUnit & VPL.Saline_0_or_CFA_1 == false);
        cInd = find(VPL.ActiveUnit & VPL.Saline_0_or_CFA_1 == true);
        Spont = [consCondNames{1,a}, '_Counts_Spont'];
        SalSpBox{a} = VPL.(Spont)(sInd)/rW;
        CfaSpBox{a} = VPL.(Spont)(cInd)/rW;
        SalSpMed(1,(d+a)) = median(SalSpBox{a});
        CfalSpMed(1,(d+a)) = median(CfaSpBox{a});
        SLabels{a,1} = consCondNames{1,a};
        
        subplot(1, 2*length(consCondNames), a);
        boxplot(SalSpBox{a});
        title(['Saline ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rates (Hz)');
        end
        xticklabels({});
        ylim([0 8]);
        ax = gca; 
        ax.FontSize = 20;
        
        subplot(1, 2*length(consCondNames), 2*a);
        boxplot(CfaSpBox{a});
        title(['CFA ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rates (Hz)');
        end
        xticklabels({});
        ylim([0 8]);
        ax = gca; 
        ax.FontSize = 20;
        
        Sp_Rs(a).name  = ['Saline vs CFA', consCondNames{1,a}];
        Sp_Rs(a).results = ranksum(SalRrBox{a}, CfaRrBox{a});
        if Sp_Rs(a).RankSum <= 0.05
                        Sp_Rs(a).Signifcant = true;
        end
        d = d + length(consCondNames);
end

%% Unfiltered MRs

d = 0;

figure('Name', ['Unfiltered_Mechanical_Responses'], 'Color', 'white');   

for a = 1: length(consCondNames)
        sIndex = find(VPL.ActiveUnit & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == false);
        cIndex = find(VPL.ActiveUnit & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == true);
        Spont = [consCondNames{1,a}, '_Counts_Spont'];
        Evoked = [consCondNames{1,a}, '_Counts_Evoked'];
        SalSpBox{a} = VPL.(Spont)(sIndex)/rW; 
        SalEvBox{a} = VPL.(Evoked)(sIndex)/rW;
        CfaSpBox{a} = VPL.(Spont)(cIndex)/rW; 
        CfaEvBox{a} = VPL.(Evoked)(cIndex)/rW;
        SalSpMed(1,(d+a)) = median(SalSpBox{a});
        SalEvMed(1,(d+a)) = median(SalEvBox{a});
        CfaSpMed(1,(d+a)) = median(CfaSpBox{a});
        CfaEvMed(1,(d+a)) = median(CfaEvBox{a});
        
        MLabels{a,1} = consCondNames{1,a};
        
        subplot(1,2*length(consCondNames),a);
        boxplot([SalSpBox{a}, SalEvBox{a}]);
         title(['Saline ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rate (Hz)');
        end
        xticklabels({'Spont', 'Evoked'});
        ylim([0 15]);
        ax = gca; 
        ax.FontSize = 20;
        
        subplot(1, 2*length(consCondNames), 2*a);
        boxplot([CfaSpBox{a}, CfaEvBox{a}]);
         title(['CFA ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rate (Hz)');
        end
        xticklabels({'Spont', 'Evoked'});
        ylim([0 15]);
        ax = gca; 
        ax.FontSize = 20;
end
        
%% Population MRs Filtered for Significance

c = 0;
d = 0;

figure('Name', ['Filtered_Mechanical_Responses'], 'Color', 'white');   


 for a = 1: length(consCondNames)
        Sig = [consCondNames{1,a}, '_MR'];
        sIndex = find(VPL.(Sig) & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == false);
        cIndex = find(VPL.(Sig) & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == true);
        Spont = [consCondNames{1,a}, '_Counts_Spont'];
        Evoked = [consCondNames{1,a}, '_Counts_Evoked'];
        SalSpBox{a} = VPL.(Spont)(sIndex)/rW; 
        SalEvBox{a} = VPL.(Evoked)(sIndex)/rW;
        CfaSpBox{a} = VPL.(Spont)(cIndex)/rW; 
        CfaEvBox{a} = VPL.(Evoked)(cIndex)/rW;
        SalSpMed(1,(d+a)) = median(SalSpBox{a});
        SalEvMed(1,(d+a)) = median(SalEvBox{a});
        CfaSpMed(1,(d+a)) = median(CfaSpBox{a});
        CfaEvMed(1,(d+a)) = median(CfaEvBox{a});
        MLabels{a,1} = consCondNames{1,a};
        subplot(2,2*length(consCondNames), a);
        boxplot([SalSpBox{a}, SalEvBox{a}]);
        title(['Saline ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rate (Hz)');
        end
        xticklabels({'Spont', 'Evoked'});
        ylim([0 15]);
        ax = gca; 
        ax.FontSize = 15;

        subplot(2, 2*length(consCondNames), 2*a);
        boxplot([CfaSpBox{a}, CfaEvBox{a}]);
        title(['CFA ', consCondNames{a}]);
        if a == 1
            ylabel('Firing Rate (Hz)');
        end
        xticklabels({'Spont', 'Evoked'});
        ylim([0 15]);
        ax = gca; 
        ax.FontSize = 15;

        subplot(2 ,2*length(consCondNames), a + 2* length(consCondNames));
        pie([(sum(VPL.ActiveUnit & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == false) - length(sIndex)), length(sIndex)]);
        labels = {'Unesponsive','Responsive'};
        legend(labels,'Location','southoutside','Orientation','vertical')
        ax = gca;
        ax.FontSize = 15;

        subplot(2, 2*length(consCondNames), 2*a + 2* length(consCondNames));
        pie([(sum(VPL.ActiveUnit & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == true) - length(cIndex)), length(cIndex)]);
        labels = {'Unesponsive','Responsive'};
        legend(labels,'Location','southoutside','Orientation','vertical')
        ax = gca;
        ax.FontSize = 15;

    if sum(SalSpBox{a}) ~= false && sum(SalEvBox{a} ~= false)
            c = c + 1;
            MechRS(c).name = ['Saline_', consCondNames{1,a}, '_Spont_vs_Evoked_Shank_', num2str(shankNo)];
            MechRS(c).RankSum = ranksum(VPL.(Spont)(sIndex)/rW, VPL.(Evoked)(sIndex)/rW);
            if MechRS(c).RankSum <= 0.05
                    MechRS(c).Signifcant = true;
            end
        if sum(CfaSpBox{a}) ~= false && sum(CfaEvBox{a} ~= false)
            c = c + 1;
            MechRS(c).name = ['CFA_' ,consCondNames{1,a}, '_Spont_vs_Evoked_Shank_', num2str(shankNo)];
            MechRS(c).RankSum = ranksum(VPL.(Spont)(cIndex)/rW, VPL.(Evoked)(cIndex)/rW);
            if MechRS(c).RankSum <= 0.05
                    MechRS(c).Signifcant = true;
            end

        end

    end
    d = d + length(consCondNames);
 end

%% Relative Responses
d = 0;

figure('Name', 'Filtered_Relative_Responses', 'Color', 'white');   

for a = 1: length(consCondNames)
        Sig = [consCondNames{1,a}, '_MR'];
        sIndex = find(VPL.(Sig) & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == false);
        cIndex = find(VPL.(Sig) & VPL.shank == shankNo & VPL.Saline_0_or_CFA_1 == true);
        Spont = [consCondNames{1,a}, '_Counts_Spont'];
        Evoked = [consCondNames{1,a}, '_Counts_Evoked'];
        SalRrBox{a} = VPL.(Evoked)(sIndex)/rW - VPL.(Spont)(sIndex)/rW;
        CfaRrBox{a} = VPL.(Evoked)(cIndex)/rW - VPL.(Spont)(cIndex)/rW;
        SalRrMed(1,(d+a)) = median(SalRrBox{a});
        CfaRrMed(1,(d+a)) = median(CfaRrBox{a});
        MLabels{a,1} = consCondNames{1,a};
        
        subplot(1, 2*length(consCondNames), a);
        boxplot(SalRrBox{a});
        title(['Saline ', consCondNames{a}]);
        if a == 1
            ylabel('Relative Responses (Hz)');
        end
        xticklabels({});
        ylim([0 14]);
        ax = gca; 
        ax.FontSize = 20;
        
        subplot(1, 2*length(consCondNames), 2*a);
        boxplot(CfaRrBox{a});
        title(['CFA ', consCondNames{a}]);
        if a == 1
            ylabel('Relative Responses (Hz)');
        end
        xticklabels({});
        ylim([0 14]);
        ax = gca; 
        ax.FontSize = 20;
        
        Rr_Rs(a).name  = ['Saline vs CFA', consCondNames{1,a}];
        Rr_Rs(a).results = ranksum(SalRrBox{a}, CfaRrBox{a});
        if Rr_Rs(a).RankSum <= 0.05
                        Rr_Rs(a).Signifcant = true;
        end
        d = d + length(consCondNames);
end