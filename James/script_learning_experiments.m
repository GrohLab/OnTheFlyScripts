%% Call function
dt= datetime(2024,11,25);

dt.Format = 'dd-MM-yy';

daytime = ["AM","PM"];

mice_number= ["m1",
    "m2",
    "m3",
    "m4",
    "m5",
    "m6"];

data_path = "Z:\James\Learning Experiments";
ss_means = NaN(24,6,8);
ss_max = NaN(6,8);

expandName = @(x) fullfile( x.folder, x.name );

for h = 0:11
    for x = 1:2
        for m = 1:6
            ss_Data = fullfile(data_path, sprintf("%s_%s\\%s\\%s",string(dt+h),daytime(x),mice_number(m),"Simple summary.mat"));
            ss_Path = fullfile(data_path, sprintf("%s_%s\\%s",string(dt+h),daytime(x),mice_number(m)));
            try
                load(ss_Data)
            catch
                try
                    ss_Data = dir( fullfile(ss_Path, 'BehaviourResults*.mat') );
                    load( expandName( ss_Data ), 'behRes' )
                    summStruct = behRes;
                catch
                    rec_file = dir(fullfile(ss_Path, 'Recording*.bin'));
                    fID = fopen( expandName( rec_file ) , 'w' );
                    fwrite( fID, [], 'int16' );
                    fclose(fID);

                    prepare64ChanBin4KS( ss_Path, 'BinFileName', sprintf("%s_%s_%s",mice_number(m),string(dt+h),daytime(x)), 'AllBinFiles', true );

                    pgObj = ProtocolGetter(ss_Path);
                    pgObj.getConditionSignals;
                    pgObj.getSignalEdges;
                    pgObj.getFrequencyEdges(0.8);
                    pgObj.pairStimulus(0.2);
                    pgObj.saveConditions;

                    [summStruct, behFig_path, behData, aInfo] = analyseBehaviour( ss_Path, ...
                        "ConditionsNames", "Puff", ...
                        "ResponseWindow", [25, 350] * 1e-3, ...
                        "ViewingWindow", [-450, 500] * 1e-3, ...
                        "figOverWrite", false );

                    close all;
                end
            end
            r = ((x-1)*12)+(h+1);
            N_att = numel(summStruct.Results);
            ss_means(r,m,1:N_att) = mean(cat(1,summStruct.Results.MaxValuePerTrial),2);
            if h == 0 && x==1
                ss_max(m,1:N_att) = max(cat(1,summStruct.Results.MaxValuePerTrial),[],2);
            end
        end
    end
end
